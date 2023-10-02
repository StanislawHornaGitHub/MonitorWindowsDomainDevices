<#
.SYNOPSIS
    Script to get virtual machines running under Hyper-V 

.DESCRIPTION
    Script is connecting to each device marked as active in SQL Inventory Table and retrieving information.
    For each device script is creating separate Powershell Background job responsible for collecting data.
    Results are captured and pushed corresponding to SQL Tables:
        -Object_Hyper_V_VMs
        -Object_Hyper_V_HardDrives
        -Object_Hyper_V_NetAdapters

.INPUTS
    DEBUG - switch - If it is set than no data will be pushed to the SQL server,
                    everything will be displayed in the console.
                    Remember that even if this param is used the connection to the SQL Server is still required,
                    to get the list of currently active devices

.OUTPUTS
    Based on input DEBUG setting data is displayed in the console or pushed to the SQL Server
        Object_Hyper_V_VMs: 
            - Name
            - Generation
            - Version
            - OperationalStatus
            - ProcessorCount
            - MemoryAssigned_GB
            - AutomaticStartAction
            - AutomaticStopAction
            - State
            - DNSHostName
            - LastUpdate

        Object_Hyper_V_HardDrives: 
            - VMName
            - ControllerType
            - VhdFormat
            - VhdType
            - Size_GB
            - Path
            - DNSHostName
            - LastUpdate

        Object_Hyper_V_NetAdapters:
            - VMName
            - SwitchName
            - IsManagementOs
            - MacAddress
            - Status
            - IPAddresses
            - DNSHostName
            - LastUpdate

.NOTES

    Version:            1.0
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      2-Oct-2023
    ChangeLog:

    Date            Who                     What
#>
param(
    [bool]$RunOutOfSchedule = $false,
    [switch]$DEBUG
)
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "SCRIPT_NAME" -Value "Get-Hyper-Vmachines" -Force -Scope Global -Option ReadOnly
New-Variable -Name "QUERY_TO_RUN_WITH_SCHEDULE" -Value "ActiveDevicesWithHyperVmonitoring.sql" -Force -Scope Global -Option ReadOnly
New-Variable -Name "QUERY_TO_RUN_OUTOF_SCHEDULE" -Value "RecentlyStarted_WithHyperVmonitoring.sql" -Force -Scope Global -Option ReadOnly
New-Variable -Name "TIMER" -Value $([System.Diagnostics.Stopwatch]::StartNew()) -Force -Scope Global

New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script
New-Variable -Name "SQL_TABLE_TO_UPDATE" -Value @(
    "Object_Hyper_V_VMs",
    "Object_Hyper_V_HardDrives",
    "Object_Hyper_V_NetAdapters"
) -Force -Scope Script -Option ReadOnly

New-Variable -Name "REMOTE_CONNECTION_TIMEOUT_SECONDS" -Value 60 -Force -Scope Script -Option ReadOnly

function Invoke-Main {
    Write-Joblog
    try {
        Start-CollectingVMpropertiesAsJob
        Get-VMpropertiesFromJob
    }
    catch {
        Write-Joblog -Message $_.Exception.Message
        $EXIT_CODE = 1
    }
    finally {
        Write-Joblog -Completed -ProcessedDevices $PROCESSED_DEVICES -EXIT_CODE $EXIT_CODE
        exit $EXIT_CODE
    }
}
function Start-CollectingVMpropertiesAsJob {
    $Computer = Get-DevicesList -RunOutOfSchedule $RunOutOfSchedule `
        -QueryWithSchedule $QUERY_TO_RUN_WITH_SCHEDULE `
        -QueryOutOfSchedule $QUERY_TO_RUN_OUTOF_SCHEDULE
    foreach ($C in $Computer) {
        Start-Job -Name "$($C.DNSHostName)" -ScriptBlock {
            param(
                $ComputerName,
                $SQL_TABLE_TO_UPDATE
            )
            $Output = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                param(
                    $ComputerName,
                    $SQL_TABLE_TO_UPDATE
                )
                # Create hashtable with keys corresponding to SQL table names
                $Output = @{}
                foreach ($T in $SQL_TABLE_TO_UPDATE) {
                    $Output.Add($T, $(New-Object System.Collections.ArrayList))
                }
                # Get list of VMs with some properties
                try {
                    $Output.Object_Hyper_V_VMs = Get-VM | `
                        Select-Object Name, Generation, Version, OperationalStatus, ProcessorCount, MemoryAssigned, AutomaticStartAction, AutomaticStopAction, State, HardDrives, NetworkAdapters, VMId
                }
                catch [System.Management.Automation.RuntimeException] {
                    throw "Hyper-V is not installed"
                }
                catch {
                    throw "Start-CollectingVMpropertiesAsJob: $($_.Exception.Message)"
                }
                ############################
                ## Virtual Drives Section ##
                ############################
                # Get Drives' connected to the VMs (physical and virtual)
                $Output.Object_Hyper_V_VMs.HardDrives | ForEach-Object {
                    $Drive = [PSCustomObject]@{
                        'VMName'         = $_.VMName
                        'ControllerType' = $_.ControllerType.ToString()
                        'VhdFormat'      = $null
                        'VhdType'        = $null
                        'Size_GB'        = $null
                        'Path'           = $_.Path
                        'DNSHostName'    = $ComputerName
                        'Row_ID'         = "$($_.ID.Split(":")[1])_$($ComputerName.Split(".")[0])"
                    }
                    # if the drive is virtual than the condition is true
                    if ($_.Path -like "?:\*") {
                        # Get maximum capacity, format and type for virtual drives
                        try {
                            $VHDdetails = Get-VHD -Path $_.Path
                            $Drive.VhdFormat = $_.Path.Split(".")[1].ToUpper()
                            # Convert the ID type to string name
                            $Drive.VhdType = "$($VHDdetails.VhdType.ToString())"
                        }
                        catch {}
                        $Drive.Size_GB = $VHDdetails.Size
                    }
                    else {
                        # Get disk size for physical drive
                        try {
                            $DiskDetails = Get-Disk -Number $_.DiskNumber
                            $Drive.Size_GB = $DiskDetails.Size
                        }
                        catch {}
                    }
                    # convert size to GB
                    $Drive.Size_GB = $Drive.Size_GB / 1GB
                    $Output.Object_Hyper_V_HardDrives.Add($Drive) | Out-Null
                }
                ##############################
                ## Virtual Adapters Section ##
                ##############################
                # Get properties of Network adapters connected to VMs
                $Output.Object_Hyper_V_NetAdapters = $Output.Object_Hyper_V_VMs.NetworkAdapters | `
                    Select-Object VMName, SwitchName, IsManagementOs, MacAddress, Status, IPAddresses, ID
                $Output.Object_Hyper_V_NetAdapters | Add-Member -MemberType NoteProperty -Name DNSHostName -Value $ComputerName
                $Output.Object_Hyper_V_NetAdapters | Add-Member -MemberType NoteProperty -Name "Row_ID" -Value ""
                $Output.Object_Hyper_V_NetAdapters | ForEach-Object {
                    # Convert status id number to string
                    try {
                        $_.Status = $_.Status.GetValue(0).ToString()
                    }
                    catch {}
                    # Generate row ID for NIC
                    $_.Row_ID = "$($_.ID.Split(":")[1])_$($ComputerName.Split(".")[0])"
                    # Select IPv4 only
                    $_.IPAddresses = $_.IPAddresses | Where-Object { $_ -like "*.*.*.*" }
                    # If there is more than 1 IP address than display all of them separated by comma
                    If ($null -ne $_.IPAddresses.count) {
                        $_.IPAddresses = $_.IPAddresses -join ", "
                    }
                }
                # Select appropriate columns for SQL DB
                $Output.Object_Hyper_V_NetAdapters = $Output.Object_Hyper_V_NetAdapters | `
                    Select-Object VMName, SwitchName, IsManagementOs, MacAddress, Status, IPAddresses, DNSHostName, Row_ID
                ##############################
                ## Virtual Machines Section ##
                ##############################
                # Convert assigned memory to GBs and generate row ID
                $Output.Object_Hyper_V_VMs | Add-Member -MemberType NoteProperty -Name MemoryAssigned_GB -Value 0
                $Output.Object_Hyper_V_VMs | Add-Member -MemberType NoteProperty -Name Row_ID -Value ""
                $Output.Object_Hyper_V_VMs | Add-Member -MemberType NoteProperty -Name DNSHostName -Value $ComputerName
                $Output.Object_Hyper_V_VMs | ForEach-Object {
                    # Convert Operational status ID number to string
                    $_.OperationalStatus = $_.OperationalStatus.GetValue(0)
                    $_.MemoryAssigned_GB = $_.MemoryAssigned / 1GB
                    $_.AutomaticStartAction = $_.AutomaticStartAction.ToString()
                    $_.AutomaticStopAction = $_.AutomaticStopAction.ToString()
                    $_.State = $_.State.ToString()
                    $_.Row_ID = "$($_.VMId.Guid)_$($ComputerName.Split(".")[0])"
                }
                # Select appropriate columns for SQL DB
                $Output.Object_Hyper_V_VMs = $Output.Object_Hyper_V_VMs | `
                    Select-Object Name, Generation, Version, OperationalStatus, ProcessorCount, MemoryAssigned_GB, AutomaticStartAction, AutomaticStopAction, State, DNSHostName, Row_ID
                return $Output
            } -ArgumentList $ComputerName, $SQL_TABLE_TO_UPDATE
            return $Output
        }-ArgumentList $($C.DNSHostName), $SQL_TABLE_TO_UPDATE | Out-Null
    }    
}
function Get-VMpropertiesFromJob {
    $Time = [System.Diagnostics.Stopwatch]::StartNew()
    $LastUpdate = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    while ($null -ne (Get-Job) -and ($Time.ElapsedMilliseconds -le ($REMOTE_CONNECTION_TIMEOUT_SECONDS * 1000))) {
        $jobName = Get-CompletedJobName
        if ($null -ne $jobName) {
            Write-Host "Operations during timeout - $jobname"
            $Output = $null
            $success = $false
            try {
                $Output = Receive-Job -Name $jobName -ErrorAction Stop
                $success = $true
            }
            catch {
                Write-Joblog -Message "$jobname - $($_.Exception.Message)"
            }
            if ($success -eq $true) {
                foreach ($T in $Output.Keys) {
                    # Add LastUpdate date
                    $Output.$T | Add-Member -MemberType NoteProperty -Name 'LastUpdate' -Value $LastUpdate
                    # Replace forbidden chars from Row_ID
                    $Output.$T | ForEach-Object {
                        try {
                            $_.Row_ID = $_.Row_ID.Replace("-", "_")
                            $_.Row_ID = $_.Row_ID.Replace("\", "_")
                        }
                        catch {}
                    }
                    if ($DEBUG) {
                        $Output.$T
                    }
                    else {
                        # Create a SQL query for each row and run it on Server
                        foreach ($Row in $Output.$T) {
                            $updateQuery = Get-SQLdataUpdateQuery -Entry $Row  -TableName $T -sqlPrimaryKey "Row_ID"
                            try {
                                Invoke-SQLquery -Query $updateQuery 
                            }
                            catch {
                                Write-Joblog -Message "$jobname - $($_.Exception.Message)"
                                $updateQuery
                                $item
                            }
                        }
                    }
                }
            }
            Remove-Job -Name $jobName
        }
    }
    Remove-RemainingJobs
}
Invoke-Main