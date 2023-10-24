<#
.SYNOPSIS
    Script to collect Network Adapters configuration

.DESCRIPTION
    Script is connecting to each device marked as active in SQL Inventory Table and retrieving information.
    For each device script is creating separate Powershell Background job responsible for collecting data.
    Results are captured and pushed corresponding to SQL Tables:
        - Object_NetworkAdapters
        - Object_NetworkAdaptersIPaddresses
        - Object_NetworkAdaptersDefaultGateways
        - Object_NetworkAdaptersDNSservers

.INPUTS
    DEBUG - switch - If it is set than no data will be pushed to the SQL server,
                    everything will be displayed in the console.
                    Remember that even if this param is used the connection to the SQL Server is still required,
                    to get the list of currently active devices

.OUTPUTS
    Based on input DEBUG setting data is displayed in the console or pushed to the SQL Server
        Object_NetworkAdapters:
            - Name - Interface alias
            - DNSHostName - Name of the device from which data was gathered
            - InterfaceDescription - Description of the network adapter
            - ifIndex - Interface index
            - MacAddress - Physical address of Network Interface Card
            - LinkSpeed - Speed of Network Interface Card
            - Status - is it running or not
            - MediaType - The type of network adapter (Ethernet/Wi-Fi)
            - PhysicalMediaType - The type of network adapter (Ethernet/Wi-Fi)
            - VLANID - ID of the VLAN in Access mode
        Object_NetworkAdaptersIPaddresses:
            - DNSHostName - Name of the device from which data was gathered
            - InterfaceAlias - Interface alias (Name in Object_NetworkAdapters)
            - ifIndex - Interface index
            - AddressFamily - IPv4 / IPv6
            - IPAddress - Address which is actually set to the NIC
            - PrefixLength - Subnet prefix
            - AddressState - wheter it is reserved in dhcp or not
        Object_NetworkAdaptersDefaultGateways:
            - DNSHostName - Name of the device from which data was gathered
            - InterfaceAlias - Interface alias (Name in Object_NetworkAdapters)
            - ifIndex - Interface index
            - AddressFamily - IPv4 / IPv6
            - DestinationPrefix - Destination address (for default gateway it will be 0.0.0.0/0)
            - NextHop - Adress of the default gateway
            - InterfaceMetric - the cost to sent the packet through particular interface
            - RouteMetric - the cost tot sent the packet through particular gateway
        Object_NetworkAdaptersDNSservers:
            - DNSHostName - Name of the device from which data was gathered
            - InterfaceAlias - Interface alias (Name in Object_NetworkAdapters)
            - ifIndex - Interface index
            - AddressFamily - IPv4 / IPv6
            - DNSServer - the IP address of the DNS server
            - DNSServerOrder - the order in which the device is using DNS Servers (1 stands for primary, 2 for secondary, etc.)

.NOTES

    Version:            1.0
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      12-Oct-2023
    ChangeLog:

    Date            Who                     What

#>
param(
    [bool]$RunOutOfSchedule = $false,
    [switch]$DEBUG
)
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "SCRIPT_NAME" -Value "Get-NetworkConfiguration.ps1" -Force -Scope Global -Option ReadOnly
New-Variable -Name "QUERY_TO_RUN_WITH_SCHEDULE" -Value "" -Force -Scope Global -Option ReadOnly
New-Variable -Name "QUERY_TO_RUN_OUTOF_SCHEDULE" -Value "RecentlyStarted_ActiveDevices.sql" -Force -Scope Global -Option ReadOnly
New-Variable -Name "TIMER" -Value $([System.Diagnostics.Stopwatch]::StartNew()) -Force -Scope Global

New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script
New-Variable -Name "SQL_TABLE_TO_UPDATE" -Value @(
    "Object_NetworkAdapters",
    "Object_NetworkAdaptersIPaddresses",
    "Object_NetworkAdaptersDefaultGateways",
    "Object_NetworkAdaptersDNSservers"
) -Force -Scope Script -Option ReadOnly

New-Variable -Name "REMOTE_CONNECTION_TIMEOUT_SECONDS" -Value 60 -Force -Scope Script -Option ReadOnly

function Invoke-Main {
    Write-Joblog
    try {
        Start-CollectingNetAdapterPropertiesAsJob
        Get-NetAdapterPropertiesFromJob
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
function Start-CollectingNetAdapterPropertiesAsJob {
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
                $(Get-NetAdapter) | ForEach-Object {
                    ###############################
                    ## Physical Adapters Section ##
                    ###############################
                    $adapterResult = [pscustomobject]@{
                        'Name'                 = $_.Name
                        'DNSHostName'          = $ComputerName
                        'InterfaceDescription' = $_.InterfaceDescription
                        'ifIndex'              = $_.ifIndex
                        'MacAddress'           = $_.MacAddress
                        'LinkSpeed'            = $_.LinkSpeed
                        'Status'               = $_.Status
                        'MediaType'            = $_.MediaType
                        'PhysicalMediaType'    = $_.PhysicalMediaType
                        'VlanID'               = $_.VlanID
                        'Row_ID'               = "$ComputerName$($_.ifIndex)$($_.MacAddress)"
                    }

                    $Output.Object_NetworkAdapters.Add($adapterResult) | Out-Null
                    ##########################
                    ## IP Addresses Section ##
                    ##########################                  
                    try {
                        $(Get-NetIPAddress -ifIndex $adapterResult.ifIndex -ErrorAction Stop) | ForEach-Object {
                            $ipResult = [pscustomobject]@{
                                'DNSHostName'   = $ComputerName
                                'ifIndex'       = $_.InterfaceIndex
                                'AddressFamily' = $_.AddressFamily
                                'IPAddress'     = $_.IPAddress
                                'PrefixLength'  = $_.PrefixLength
                                'AddressState'  = $_.AddressState
                                'Row_ID'        = "$ComputerName$($_.InterfaceIndex)$($_.IPAddress)"
                            }
                            # Replace address state code with human readable string
                            $ipResult.AddressState = $ipResult.AddressState.ToString()
                            $Output.Object_NetworkAdaptersIPaddresses.Add($ipResult) | Out-Null
                        }
                    }
                    catch {}
                    ##############################
                    ## Default Gateways Section ##
                    ##############################
                    try {
                        $(Get-NetRoute -InterfaceIndex $adapterResult.ifIndex -ErrorAction Stop) | `
                            Where-Object { $_.DestinationPrefix -eq "0.0.0.0/0" } | ForEach-Object {
                            $GWresult = [pscustomobject]@{
                                'DNSHostName'       = $ComputerName
                                'ifIndex'           = $_.ifIndex
                                'AddressFamily'     = $_.AddressFamily
                                'DestinationPrefix' = $_.DestinationPrefix
                                'NextHop'           = $_.NextHop
                                'InterfaceMetric'   = $_.InterfaceMetric
                                'RouteMetric'       = $_.RouteMetric
                                'Row_ID'            = "$ComputerName$($_.InterfaceIndex)$($_.NextHop)"
                            }
                            $Output.Object_NetworkAdaptersDefaultGateways.Add($GWresult) | Out-Null
                        }
                    }
                    catch {}
                    #########################
                    ## DNS Servers Section ##
                    #########################
                    try {
                        $(Get-DnsClientServerAddress -InterfaceIndex $adapterResult.ifIndex -ErrorAction Stop) | ForEach-Object {
                            for ($i = 0; $i -lt $_.ServerAddresses.Count; $i++) {
                                $DNSresult = $null
                                $DNSresult = [pscustomobject]@{
                                    'DNSHostName'    = $ComputerName
                                    'ifIndex'        = $_.InterfaceIndex
                                    'AddressFamily'  = $_.AddressFamily
                                    'DNSServer'      = $($_.ServerAddresses[$i])
                                    'DNSServerOrder' = $($i + 1)
                                    'Row_ID'         = "$ComputerName$($_.InterfaceIndex)$($_.ServerAddresses[$i])"
                                }
                                # Replace address family code with human readable string (Windows bug, the default one does not work)
                                switch (($DNSresult.AddressFamily)) {
                                    2 { $DNSresult.AddressFamily = "IPv4" }
                                    23 { $DNSresult.AddressFamily = "IPv6" }
                                }
                                $Output.Object_NetworkAdaptersDNSservers.Add($DNSresult) | Out-Null
                            }
                        }
                    }
                    catch {}
                }
                # Replace address family code with human readable string
                foreach ($table in $Output.Keys) {
                    foreach ($Row in $Output.$table) {
                        try {
                            $Row.AddressFamily = $Row.AddressFamily.ToString()
                        }
                        catch {}
                    }
                }
                return $Output
            }-ArgumentList $ComputerName, $SQL_TABLE_TO_UPDATE
            return $Output
        } -ArgumentList $($C.DNSHostName), $SQL_TABLE_TO_UPDATE | Out-Null
    }
}

function Get-NetAdapterPropertiesFromJob {
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
                foreach ($t in $Output.Keys) {
                    # Add LastUpdate date
                    $Output.$t | Add-Member -MemberType NoteProperty -Name 'LastUpdate' -Value $LastUpdate 
                    # Replace forbidden chars from Row_ID
                    $Output.$t | ForEach-Object {
                        try {
                            $_.Row_ID = $_.Row_ID.Replace(" ", "_")
                            $_.Row_ID = $_.Row_ID.Replace("(", "")
                            $_.Row_ID = $_.Row_ID.Replace(")", "")
                            $_.Row_ID = $_.Row_ID.Replace(":", "") 
                            $_.Row_ID = $_.Row_ID.Replace(",", "") 
                            $_.Row_ID = $_.Row_ID.Replace("\", "-")
                            $_.Row_ID = $_.Row_ID.Replace("/", "-")
                            $_.Row_ID = $_.Row_ID.Replace(".", "")
                            $_.Row_ID = $_.Row_ID.Replace("-", "")
                            $_.Row_ID = $_.Row_ID.Replace("%", "")
                        }
                        catch {}
                    }
                }
                if ($DEBUG) {
                    $Output
                }
                else {
                    # Create a SQL query for each row and run it on Server
                    foreach ($Table in $Output.keys) {
                        foreach ($Row in $Output.$Table) {
                            $updateQuery = Get-SQLdataUpdateQuery -Entry $Row  -TableName $Table -sqlPrimaryKey "Row_ID"
                            try {
                                Invoke-SQLquery -Query $updateQuery 
                            }
                            catch {
                                Write-Joblog -Message "$jobname - $($_.Exception.Message)"
                                $updateQuery
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