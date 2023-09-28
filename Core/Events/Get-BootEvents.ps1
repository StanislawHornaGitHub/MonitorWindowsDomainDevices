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

    Version:            1.0
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      25-Sep-2023
    ChangeLog:

    Date            Who                     What

#>
param(
    [switch]$DEBUG
)
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "SCRIPT_NAME" -Value "Get-BootEvents" -Force -Scope Global -Option ReadOnly
New-Variable -Name "TIMER" -Value $([System.Diagnostics.Stopwatch]::StartNew()) -Force -Scope Global

New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script
New-Variable -Name "SQL_TABLE_TO_UPDATE" -Value "Event_Boots" -Force -Scope Script -Option ReadOnly

New-Variable -Name "REMOTE_CONNECTION_TIMEOUT_SECONDS" -Value 90 -Force -Scope Script -Option ReadOnly
New-Variable -Name "FILTER_X_PATH" -Value "*[System[EventID=27]]" -Force -Scope Script -Option ReadOnly

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
        Write-Joblog -Completed -EXIT_CODE $EXIT_CODE
        exit $EXIT_CODE
    }
}
function Start-CollectingBootEventsAsJob {
    $Computer = Get-ComputerListToProcess
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
                    $Events = Get-WinEvent -ProviderName Microsoft-Windows-Kernel-boot `
                        -FilterXPath $FILTER_X_PATH `
                        -ErrorAction Stop
                }
                catch {
                    throw $_.Exception.Message
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
            } -ArgumentList $ComputerName, $FILTER_X_PATH
            return $Output
        } -ArgumentList $($C.DNSHostName), $FILTER_X_PATH | Out-Null
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
                $Output | ForEach-Object {
                    $_.TimeStamp = $_.TimeStamp.ToString("yyyy-MM-dd HH:mm:ss\.fff")
                    $_.Row_ID = "$($_.TimeStamp)_$($_.DNSHostName)"
                    $_.Row_ID = $_.Row_ID.Replace(".", "_")
                    $_.Row_ID = $_.Row_ID.Replace(" ", "")
                    $_.Row_ID = $_.Row_ID.Replace(":", "")
                }
                $Output = $Output | Select-Object -Property * -ExcludeProperty PSComputerName, RunspaceId, PSShowComputerName
            }
            catch {
                Write-Joblog -Message "$jobname - $($_.Exception.Message)"
            }
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