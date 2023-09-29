<#
.SYNOPSIS
    Script to get list of packages on each device.

.DESCRIPTION
    Script is connecting to each device marked as active in SQL Inventory Table and retrieving information.
    For each device script is creating separate Powershell Background job responsible for collecting data.
    Results are captured and pushed to SQL Packages Table

.INPUTS
    DEBUG - switch - If it is set than no data will be pushed to the SQL server,
                    everything will be displayed in the console.
                    Remember that even if this param is used the connection to the SQL Server is still required,
                    to get the list of currently active devices

.OUTPUTS
    Based on input DEBUG setting data is displayed in the console or pushed to the SQL Server

        DisplayName - Package Name
        Publisher - Package vendor
        DisplayVersion - package version
        InstallDate - date when it was installed
        InstallLocation - instalation directory
        QuietUninstallString - quiet uninstaller
        DNSHostName - Device DNSHostName 
        EstimatedSize_GB - Estimated Package size

.NOTES

    Version:            1.0
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      05-Sep-2023
    ChangeLog:

    Date            Who                     What

#>
param(
    [bool]$RunOutOfSchedule = $false,
    [switch]$DEBUG
)
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "SCRIPT_NAME" -Value "Get-InstalledPackages" -Force -Scope Global -Option ReadOnly
New-Variable -Name "QUERY_TO_RUN_OUTOF_SCHEDULE" -Value "RecentlyStarted_ActiveDevices.sql" -Force -Scope Global -Option ReadOnly
New-Variable -Name "TIMER" -Value $([System.Diagnostics.Stopwatch]::StartNew()) -Force -Scope Global

New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script
New-Variable -Name "SQL_TABLE_TO_UPDATE" -Value "Object_Packages" -Force -Scope Script -Option ReadOnly
New-Variable -Name "REMOTE_CONNECTION_TIMEOUT_SECONDS" -Value 60 -Force -Scope Script -Option ReadOnly
New-Variable -Name 'INPUT_HASH' -Value @{
    "REGISTRY_KEYS"   = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    "PROPERTY_FIELDS" = @(
        "DisplayName",
        "Publisher",
        "DisplayVersion",
        "EstimatedSize",
        "InstallDate",
        "InstallLocation",
        "QuietUninstallString"
    )
} -Force -Scope Script -Option ReadOnly

function Invoke-Main {
    Write-Joblog
    try {
        Start-CollectingDevicePackagesAsJob
        Get-DevicePackagesFromJob
    }
    catch {
        $Script:EXIT_CODE = 1
        Write-Joblog -Message $_.Exception.Message
    }
    finally {
        Write-Joblog -Completed -EXIT_CODE $EXIT_CODE
        exit $EXIT_CODE
    }
}
function Start-CollectingDevicePackagesAsJob {
    if($RunOutOfSchedule -eq $true){
        $Computer = Get-ComputerListToProcess -PredefinedQuery $QUERY_TO_RUN_OUTOF_SCHEDULE
    }else{
        $Computer = Get-ComputerListToProcess
    }
    foreach ($C in $Computer) {
        Start-Job -Name "$($C.DNSHostName)" `
            -InitializationScript {
            Import-Module "./Core/Import-AllModules.psm1"
        } -ScriptBlock {
            param(
                $ComputerName,
                $INPUT_HASH 
            )
            $Output = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                param(
                    $INPUT_HASH 
                )
                # Get information from registry
                $Output = Get-ItemProperty -Path $INPUT_HASH.REGISTRY_KEYS | Select-Object  $INPUT_HASH.PROPERTY_FIELDS
                # Remove entries without DisplayName
                $Output = $Output | Where-Object { $null -ne $_.DisplayName }
                # Merge entries refering to the same package
                $temphash = @{}
                $Output | ForEach-Object {
                    $thisLine = $_
                    $key = $_.'DisplayName'
                    try {
                        $temphash.Add($key, $thisLine)
                    }
                    catch {
                        foreach ($property in $thisLine.PSObject.Properties.Name) {
                            if ($null -eq $($temphash.$key.$property)) {
                                $temphash.$key.$property = $thisLine.$property
                            }
                        }
                        $temphash.$key.EstimatedSize += [int]$thisLine.EstimatedSize
                    }
                }
                return $($temphash.Values)
            } -ArgumentList $INPUT_HASH 
            # Add DNSHostName to output
            $Output | Add-Member -MemberType NoteProperty -Name "DNSHostName" -Value $ComputerName
            # Convert EstimatedSize to GBs
            $Output | Add-Member -MemberType NoteProperty -Name "EstimatedSize_GB" -Value 0
            $Output | ForEach-Object { $_.EstimatedSize_GB = $_.EstimatedSize / (1024 * 1024) }
            # Create RowID
            $Output | Add-Member -MemberType NoteProperty -Name "Row_ID" -Value ""
            # Remove SQL forbidden signs in variable name
            $Output | ForEach-Object { 
                $_.Row_ID = "$($_.DisplayName)_$($_.DNSHostName)" 
                $_.Row_ID = $_.Row_ID.Replace(" ", "_")
                $_.Row_ID = $_.Row_ID.Replace("+", "p")
                $_.Row_ID = $_.Row_ID.Replace("(", "")
                $_.Row_ID = $_.Row_ID.Replace(")", "")
                $_.Row_ID = $_.Row_ID.Replace(":", "") 
                $_.Row_ID = $_.Row_ID.Replace(",", "") 
                $_.Row_ID = $_.Row_ID.Replace("\", "-")
                $_.Row_ID = $_.Row_ID.Replace("/", "-")
            }
            return $Output
        } -ArgumentList $($C.DNSHostName), $INPUT_HASH | Out-Null
    }
}
function Get-DevicePackagesFromJob {
    $Time = [System.Diagnostics.Stopwatch]::StartNew()
    $LastUpdate = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    while ($null -ne (Get-Job) -and ($Time.ElapsedMilliseconds -le ($REMOTE_CONNECTION_TIMEOUT_SECONDS * 1000))) {
        $jobName = Get-CompletedJobName
        if ($null -ne $jobName) {
            $Output = $null
            Write-Host "Operations during timeout - $jobname"
            try {
                $Output = Receive-Job -Name $jobName -ErrorAction Stop
            }
            catch {
                Write-Joblog -Message "$jobname - $($_.Exception.Message)"
                $Script:EXIT_CODE = 1 
            }
                            # Add LastUpdate date
                            $Output | Add-Member -MemberType NoteProperty -Name "LastUpdate" -Value $LastUpdate
            if ($DEBUG) {
                #$Entry | Format-List
                Write-Host "$jobname - $($Output.count) Packages"
            }
            else {
                foreach ($package in $Output) {
                    $Row = $package | Select-Object -Property * -ExcludeProperty RunspaceId, PSComputerName, EstimatedSize, PSShowComputerName
                    $updateQuery = Get-SQLdataUpdateQuery -Entry $Row  -TableName $SQL_TABLE_TO_UPDATE -sqlPrimaryKey "Row_ID"
                    try {
                        Invoke-SQLquery -Query $updateQuery 
                    }
                    catch {
                        Write-Joblog -Message "$jobname - $($_.Exception.Message)"
                        $updateQuery
                    }
                }
            }
            Remove-Job -Name $jobName
        }
    }
    Remove-RemainingJobs   
}

Invoke-Main