<#
.SYNOPSIS
    Script to collect successfull logon events from machines (Domain Controllers should be excluded from this script)

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

        TimeStamp - Event creation time     
        UserName - of the user who successfully logged in
        Domain - of the user who successfully logged in
        DNSHostName - Device DNSHostName 
        LogonType:
            - Interactive - User logged to the Computer locally
            - Network - User logged to the Computer from the Network (Shares / Printers / SSH / PSRemoting etc)
            - Unlock - User unlocked previously locked Computer
            - Remote Interactive - User logged to the Computer remotely using Terminal Services or Remote Desktop
            - Cached Interactive - User logged to the computer with network credentials that were stored locally on the computer.
                                   The domain controller was not contacted to verify the credentials.
        LogonProcess - Process which handled the logon
        LogonSourceIP - For remote logons the IP of the device from which the user logged on the device.

.NOTES

    Version:            1.0
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      12-Sep-2023
    ChangeLog:

    Date            Who                     What

#>
param(
    [switch]$DEBUG
)
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "SCRIPT_NAME" -Value "Get-UserLogons" -Force -Scope Global -Option ReadOnly
New-Variable -Name "TIMER" -Value $([System.Diagnostics.Stopwatch]::StartNew()) -Force -Scope Global

New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script
New-Variable -Name "SQL_TABLE_TO_UPDATE" -Value "Event_Logons" -Force -Scope Script -Option ReadOnly

New-Variable -Name "REMOTE_CONNECTION_TIMEOUT_SECONDS" -Value 90 -Force -Scope Script -Option ReadOnly
New-Variable -Name "FILTER_X_PATH" -Value "
*[System[EventID=4624]]  and  
*[EventData[Data[@Name='TargetUserName']!='dev_monitor']] and 
*[EventData[Data[@Name='LogonGuid']!='00000000-0000-0000-0000-000000000000']] and
*[EventData[Data[@Name='TargetUserSid']!='S-1-5-18']] and
    (
        *[EventData[Data[@Name='LogonType']= 2]]  or
        *[EventData[Data[@Name='LogonType']= 3]]  or
        *[EventData[Data[@Name='LogonType']= 7]]  or 
        *[EventData[Data[@Name='LogonType']=10]]  or
        *[EventData[Data[@Name='LogonType']=11]]        
    )" -Force -Scope Script -Option ReadOnly


function Invoke-Main {
    Write-Joblog
    try {
        Get-LogonEventsAsJob
        Get-LogonEventsFromJob
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
function Get-LogonEventsAsJob {
    $Computer = Get-ComputerListToProcess -PredefinedQuery "ActiveDevicesWithLogonsMonitoring.sql"
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
                    $Events = Get-WinEvent -ProviderName Microsoft-Windows-Security-Auditing `
                        -FilterXPath $FILTER_X_PATH `
                        -ErrorAction Stop
                    # Sort by unique Logons GUID
                    $Events = $Events  | Sort-Object { $_.properties[12].value } -Unique
                }
                catch {
                    throw $_.Exception.Message
                }
                $Output = New-Object System.Collections.ArrayList
                foreach ($E in $Events) {
                    $Entry = [PSCustomObject]@{
                        'TimeStamp'     = $E.TimeCreated
                        'UserName'      = $E.Properties[5].Value
                        'Domain'        = $E.Properties[6].Value
                        'DNSHostName'   = $ComputerName
                        'LogonType'     = $($E.Properties[8].Value)
                        'LogonProcess'  = $E.Properties[9].Value
                        'LogonSourceIP' = $E.Properties[18].Value
                        'Row_ID'        = ""
                    }

                    $Output.Add($Entry) | Out-Null
                }
                return $Output
            } -ArgumentList $ComputerName, $FILTER_X_PATH
            return $Output
        } -ArgumentList $($C.DNSHostName), $FILTER_X_PATH | Out-Null
    }
}
function Get-LogonEventsFromJob {
    $Time = [System.Diagnostics.Stopwatch]::StartNew()
    while ($null -ne (Get-Job) -and ($Time.ElapsedMilliseconds -le ($REMOTE_CONNECTION_TIMEOUT_SECONDS * 1000))) {
        $jobName = $null
        $jobName = (Get-Job | Where-Object { ($_.State -ne "Running") } | Select-Object -First 1).Name
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
            finally {
                if ($success) {
                    $Output | ForEach-Object {
                        $_.LogonType = Get-LogonType -ID $($_.LogonType)
                        $_.TimeStamp = $_.TimeStamp.ToString("yyyy-MM-dd HH:mm:ss\.fff")
                        $_.Row_ID = "$($_.TimeStamp)_$($_.DNSHostName)"
                        $_.Row_ID = $_.Row_ID.Replace(".", "_")
                        $_.Row_ID = $_.Row_ID.Replace(" ", "")
                        $_.Row_ID = $_.Row_ID.Replace(":", "")
                    }
                    $Output = $Output | Select-Object -Property * -ExcludeProperty PSComputerName, RunspaceId, PSShowComputerName
                }
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
    $remainingJobs = Get-Job
    if ($null -ne $remainingJobs) {
        $remainingJobs | Remove-Job -Force
        Write-Joblog -Message "Background jobs were running longer than REMOTE_CONNECTION_TIMEOUT_SECONDS ($REMOTE_CONNECTION_TIMEOUT_SECONDS)"
    }
}
function Get-LogonType {
    param (
        $ID
    )
    switch ($ID) {
        2 {
            return "Interactive ($ID)"
        }
        3 {
            return "Network ($ID)"
        }
        7 {
            return "Unlock ($ID)"
        }
        10 {
            return "Remote Interactive ($ID)"
        }
        11 {
            return "Cached Interactive ($ID)"
        }
    }
}

Invoke-Main