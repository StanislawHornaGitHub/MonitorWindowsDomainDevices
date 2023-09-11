<#
.SYNOPSIS
    Script to get list of packages on each device.

.DESCRIPTION
    Script is connecting to each device marked as active in SQL Inventory Table and retrieving information.
    For each device script is creating separate Powershell Background job responsible for collecting data.
    Results are captured and pushed to SQL OperatingSystem Table

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
    [switch]$DEBUG
)
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "SCRIPT_NAME" -Value "Get-InstalledPackages" -Force -Scope Global -Option ReadOnly
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
        Get-DevicePackagesAsJob
        Get-DevicePackagesFromJob
    }
    catch {
        Write-Joblog -Message $_.Exception.Message
        $EXIT_CODE = 1
    }
    finally {
        Write-Joblog -Completed
        exit $EXIT_CODE
    }
}
function Get-DevicePackagesAsJob {
    $Computer = Get-ComputerListToProcess
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
                $Output = Get-ItemProperty -Path $INPUT_HASH.REGISTRY_KEYS | Select-Object  $INPUT_HASH.PROPERTY_FIELDS
                $Output = $Output | Where-Object { $null -ne $_.DisplayName }
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
            $Output | Add-Member -MemberType NoteProperty -Name "DNSHostName" -Value $ComputerName
            $Output | Add-Member -MemberType NoteProperty -Name "EstimatedSize_GB" -Value 0
            $Output | ForEach-Object { $_.EstimatedSize_GB = $_.EstimatedSize / (1024 * 1024) }
            return $Output
        } -ArgumentList $($C.DNSHostName), $INPUT_HASH | Out-Null
    }
}
function Get-DevicePackagesFromJob {
    $Time = [System.Diagnostics.Stopwatch]::StartNew()
    $LastUpdate = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    while ($null -ne (Get-Job) -and ($Time.ElapsedMilliseconds -le ($REMOTE_CONNECTION_TIMEOUT_SECONDS * 1000))) {
        $jobName = $null
        $jobName = (Get-Job | Where-Object { ($_.State -ne "Running") } | Select-Object -First 1).Name
        if ($null -ne $jobName) {
            $Entry = $null
            Write-Host "Operations during timeout - $jobname"
            $success = $false
            try {
                $Output = Receive-Job -Name $jobName -ErrorAction Stop
                $success = $true
            }
            catch {
                Write-Joblog -Message "$jobname - $($_.Exception.Message)"
                Write-Error $_
                $Script:EXIT_CODE = 1 
            }
            finally {
                if ($success) {
                    $Entry = $Output
                    $Entry | Add-Member -MemberType NoteProperty -Name "Row_ID" -Value ""
                    $Entry | Add-Member -MemberType NoteProperty -Name "LastUpdate" -Value $LastUpdate
                    $Entry | ForEach-Object { $_.Row_ID = "$($_.DisplayName)_$($_.DNSHostName)" }
                    $Entry | ForEach-Object { $_.Row_ID = $_.Row_ID.Replace(" ", "_") }
                }
            }
            if ($DEBUG) {
                #$Entry | Format-List
                Write-Host "$jobname - $($entry.count) Packages"
            }
            else {
                foreach ($package in $Entry) {
                    $Row = $package | Select-Object -Property * -ExcludeProperty RunspaceId, PSComputerName, EstimatedSize, PSShowComputerName
                    $updateQuery = Get-SQLdataUpdateQuery -Entry $Row  -TableName $SQL_TABLE_TO_UPDATE -sqlPrimaryKey "Row_ID"
                    try {
                        Invoke-SQLquery -Query $updateQuery 
                    }
                    catch {
                        Write-Error $_
                        $updateQuery
                    }
                }
            }

            Remove-Job -Name $jobName
        }
    }
    $remainingJobs = Get-Job
    if ($null -ne $remainingJobs) {
        $remainingJobs | Remove-Job -Force
        Write-Joblog -Message "Background jobs were running longer than REMOTE_CONNECTION_TIMEOUT_SECONDS ($REMOTE_CONNECTION_TIMEOUT_SECONDS)"
    }
    
}

Invoke-Main