<#
.SYNOPSIS
    Script to get Boot events

.DESCRIPTION
    Script is connecting to each device marked as active in SQL Inventory Table and retrieving information.
    For each device script is creating separate Powershell Background job responsible for collecting data.
    Results are captured and pushed to SQL Boot events table

.INPUTS
    DEBUG - switch - If it is set than no data will be pushed to the SQL server,
                    everything will be displayed in the console.
                    Remember that even if this param is used the connection to the SQL Server is still required,
                    to get the list of currently active devices

.OUTPUTS
    Based on input DEBUG setting data is displayed in the console or pushed to the SQL Server

        Timestamp - Event creation time 
        DNSHostName - Device DNSHostName 
        BootType:
            - Normal boot
            - Fast start
            - Wakeup from Hibernation

.NOTES

    Version:            1.3
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      25-Sep-2023
    ChangeLog:

    Date            Who                     What
    29-09-2023      Stanisław Horna         Support for RunOutOfSchedule mechanizm added
    30-09-2023      Stanisław Horna         More accurate number of processed devices in Joblog
    16-11-2023      Stanisław Horna         FilterxPath replaced with Filterhashtable and retrieving events is limited,
                                                to those occured after last boot event stored in SQL DB.
#>
param(
    [bool]$RunOutOfSchedule = $false,
    [switch]$DEBUG
)
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "SCRIPT_NAME" -Value "Get-BootEvents.ps1" -Force -Scope Global -Option ReadOnly
New-Variable -Name "QUERY_TO_RUN_WITH_SCHEDULE" -Value "" -Force -Scope Global -Option ReadOnly
New-Variable -Name "QUERY_TO_RUN_OUTOF_SCHEDULE" -Value "RecentlyStarted_ActiveDevices.sql" -Force -Scope Global -Option ReadOnly
New-Variable -Name "TIMER" -Value $([System.Diagnostics.Stopwatch]::StartNew()) -Force -Scope Global

New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script
New-Variable -Name "SQL_TABLE_TO_UPDATE" -Value "Event_Boots" -Force -Scope Script -Option ReadOnly

New-Variable -Name "REMOTE_CONNECTION_TIMEOUT_SECONDS" -Value 90 -Force -Scope Script -Option ReadOnly
New-Variable -Name "FILETR_HASHTABLE" -Value @{
    ProviderName = 'Microsoft-Windows-Kernel-boot'
    ID = 27
} -Force -Scope Script -Option ReadOnly

function Invoke-Main {
    Write-Joblog
    try {
        Start-CollectingBootEventsAsJob
        Get-BootEventsFromJob
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
function Start-CollectingBootEventsAsJob {
    $Computer = Get-DevicesList -RunOutOfSchedule $RunOutOfSchedule `
        -QueryWithSchedule $QUERY_TO_RUN_WITH_SCHEDULE `
        -QueryOutOfSchedule $QUERY_TO_RUN_OUTOF_SCHEDULE
    foreach ($C in $Computer) {
        Start-Job -Name "$($C.DNSHostName)" -ScriptBlock {
            param(
                $ComputerName,
                $FilterHash,
                $LastEventTimeBootEvents
            )
            $FilterHash.Add("StartTime",$LastEventTimeBootEvents)
            $Output = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                param(
                    $ComputerName,
                    $FilterHash
                )
                function Get-BootTypeFromHex {
                    param(
                        $MessageString
                    )
                    if ($MessageString.Length -le 4) {
                        return $null
                    }
                    $Hex = $MessageString.Substring($($MessageString.Length - 4), 3)
                    switch ($Hex) {
                        "0x0" {
                            return "Normal boot ($Hex)"
                        }
                        "0x1" {
                            return "Fast start ($Hex)"
                        }
                        "0x2" {
                            return "Wakeup from Hibernation ($Hex)"
                        }
                    }
                }
                try {
                    $Events = Get-WinEvent -FilterHashtable $FilterHash  `
                        -ErrorAction Stop
                }
                catch {
                    throw "Start-CollectingBootEventsAsJob: $($_.Exception.Message)"
                }
                $Output = New-Object System.Collections.ArrayList
                foreach ($E in $Events) {
                    $Entry = [PSCustomObject]@{
                        'TimeStamp'   = $E.TimeCreated
                        'DNSHostName' = $ComputerName
                        'BootType'    = $(Get-BootTypeFromHex -MessageString $E.Message)
                        'Row_ID'      = ""
                    }
                    $Output.Add($Entry) | Out-Null
                }
                return $Output
            } -ArgumentList $ComputerName, $FilterHash
            return $Output
        } -ArgumentList $($C.DNSHostName), $FILETR_HASHTABLE, $($C.LastEventTimeBootEvents) | Out-Null
    }
}
function Get-BootEventsFromJob {
    $Time = [System.Diagnostics.Stopwatch]::StartNew()
    while ($null -ne (Get-Job) -and ($Time.ElapsedMilliseconds -le ($REMOTE_CONNECTION_TIMEOUT_SECONDS * 1000))) {
        $jobName = Get-CompletedJobName
        if ($null -ne $jobName) {
            Write-Host "Operations during timeout - $jobname"
            $Output = $null
            try {
                $Output = Receive-Job -Name $jobName -ErrorAction Stop
            }
            catch {
                Write-Joblog -Message "$jobname;$($_.Exception.Message)"
            }
            $Output | ForEach-Object {
                $_.TimeStamp = $_.TimeStamp.ToString("yyyy-MM-dd HH:mm:ss\.fff")
                $_.Row_ID = "$($_.TimeStamp)_$($_.DNSHostName)"
                $_.Row_ID = $_.Row_ID.Replace(".", "_")
                $_.Row_ID = $_.Row_ID.Replace(" ", "")
                $_.Row_ID = $_.Row_ID.Replace(":", "")
            }
            $Output = $Output | Select-Object -Property * -ExcludeProperty PSComputerName, RunspaceId, PSShowComputerName
            if ($DEBUG) {
                $Output | Format-Table
            }
            else {
                foreach ($Entry in $Output) {
                    $insertQuery = Get-SQLifDataNotExistInsertQuery -Entry $Entry -TableName $SQL_TABLE_TO_UPDATE -sqlPrimaryKey "Row_ID"
                    try {
                        Invoke-SQLquery -Query $insertQuery 
                    }
                    catch {
                        Write-Joblog -Message $_
                        $insertQuery
                    }
                }
            }
            Remove-Job -Name $jobName
        }
    }
    Remove-RemainingJobs
}
Invoke-Main