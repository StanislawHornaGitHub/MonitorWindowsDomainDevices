<#
.SYNOPSIS
    Script to get Application Error events

.DESCRIPTION
    Script is connecting to each device marked as active in SQL Inventory Table and retrieving information.
    For each device script is creating separate Powershell Background job responsible for collecting data.
    Results are captured and pushed to SQL Application Error events table

.INPUTS
    DEBUG - switch - If it is set than no data will be pushed to the SQL server,
                    everything will be displayed in the console.
                    Remember that even if this param is used the connection to the SQL Server is still required,
                    to get the list of currently active devices

.OUTPUTS
    Based on input DEBUG setting data is displayed in the console or pushed to the SQL Server

        TimeCreated - Event creation time 
        DNSHostName - Device DNSHostName 
        ID - Event ID
        Level:
            - 0 - Critical
            - 1 - Error
        ProviderName - Service / Application affected by the error
        Message - Error details

.NOTES

    Version:            1.0
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      28-Sep-2023
    ChangeLog:

    Date            Who                     What
    29-09-2023      Stanisław Horna         Support for RunOutOfSchedule mechanizm added
    30-09-2023      Stanisław Horna         More accurate number of processed devices in Joblog
#>
param(
    [bool]$RunOutOfSchedule = $false,
    [switch]$DEBUG
)
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "SCRIPT_NAME" -Value "Get-AppErrors" -Force -Scope Global -Option ReadOnly
New-Variable -Name "QUERY_TO_RUN_WITH_SCHEDULE" -Value "ActiveDevicesWithLogonsMonitoring.sql" -Force -Scope Global -Option ReadOnly
New-Variable -Name "QUERY_TO_RUN_OUTOF_SCHEDULE" -Value "RecentlyStarted_WithLogonsMonitoring.sql" -Force -Scope Global -Option ReadOnly
New-Variable -Name "TIMER" -Value $([System.Diagnostics.Stopwatch]::StartNew()) -Force -Scope Global

New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script
New-Variable -Name "SQL_TABLE_TO_UPDATE" -Value "Event_AppErrors" -Force -Scope Script -Option ReadOnly

New-Variable -Name "REMOTE_CONNECTION_TIMEOUT_SECONDS" -Value 90 -Force -Scope Script -Option ReadOnly
New-Variable -Name "FILTER_X_PATH" -Value "*[System[(Level=1  or Level=2)]]" -Force -Scope Script -Option ReadOnly

function Invoke-Main {
    Write-Joblog
    try {
        Start-CollectingAppErrorEventsAsJob
        Get-AppErrorEventsFromJob
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
function Start-CollectingAppErrorEventsAsJob {
    $Computer = Get-DevicesList -RunOutOfSchedule $RunOutOfSchedule `
        -QueryWithSchedule $QUERY_TO_RUN_WITH_SCHEDULE `
        -QueryOutOfSchedule $QUERY_TO_RUN_OUTOF_SCHEDULE
    foreach ($C in $Computer) {
        Start-Job -Name "$($C.DNSHostName)" -ScriptBlock {
            param(
                $ComputerName,
                $FILTER_X_PATH
            )
            $Output = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                param(
                    $ComputerName,
                    $FILTER_X_PATH
                )
                try {
                    $Events = Get-WinEvent -LogName Application `
                        -FilterXPath $FILTER_X_PATH `
                        -ErrorAction Stop | `
                        Select-Object TimeCreated, ID, Level, ProviderName, Message
                }
                catch {
                    throw $_.Exception.Message
                }
                $Events | Add-Member -MemberType NoteProperty -Name "DNSHostName" -Value $ComputerName
                $Events | Add-Member -MemberType NoteProperty -Name "Row_ID" -Value ""
                return $Events
            } -ArgumentList $ComputerName, $FILTER_X_PATH
            return $Output
        } -ArgumentList $($C.DNSHostName), $FILTER_X_PATH | Out-Null
    }
}
function Get-AppErrorEventsFromJob {
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
                Write-Joblog -Message "$jobname - $($_.Exception.Message)"
            }
            $Output | ForEach-Object {
                try {
                    $_.TimeCreated = $_.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss\.fff")
                    $_.Row_ID = "$($_.TimeCreated)_$($_.id)_$($_.DNSHostName.Split(".")[0])"
                    $_.Row_ID = $_.Row_ID.Replace(".", "_")
                    $_.Row_ID = $_.Row_ID.Replace(" ", "")
                    $_.Row_ID = $_.Row_ID.Replace(":", "")
                    $_.Message = $_.Message.Replace("'", "''")
                }
                catch {}
            }
            $Output = $Output | Select-Object -Property * -ExcludeProperty PSComputerName, RunspaceId, PSShowComputerName
            
            if ($DEBUG) {
                $Output | Format-List
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