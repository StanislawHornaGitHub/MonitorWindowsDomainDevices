<#
.SYNOPSIS
    Script to run selected sub scripts on devices which was powered on recently

.DESCRIPTION
    The goal is to collect data from recently enabled devices as soon as the system identified them as available.


.INPUTS
    Content of Config.json file

.OUTPUTS
    None

.NOTES

    Version:            1.0
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      29-Sep-2023
    ChangeLog:

    Date            Who                     What
#>
param(
    $ConfigData,
    $NumberOfRecentlyStartedDevices
)
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "SCRIPT_NAME" -Value "Get-RecentlyStartedDeviceDetails" -Force -Scope Global -Option ReadOnly
New-Variable -Name "TIMER" -Value $([System.Diagnostics.Stopwatch]::StartNew()) -Force -Scope Global

New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script
New-Variable -Name "SQL_QUERY_SCRIPTS_TO_RUN" -Value "$SQL_RECENTLY_STARTED_QUERIES\ScriptsToRunOnRecentlyStartedDevices.sql" -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_QUERY_UPDATE_RECENTLY_STARTED_FLAG" -Value "$SQL_RECENTLY_STARTED_QUERIES\UpdateRecentlyStartedFlag.sql" -Force -Scope Global -Option ReadOnly

New-Variable -Name "TIMEOUT_SECONDS" -Value 60 -Force -Scope Script -Option ReadOnly
function Invoke-Main {
    Write-Joblog
    try {
        Start-OutOfScheduleJobs
        Wait-ForStartedJobs
        Set-RecentlyStartedFlag
    }
    catch {
        Write-Joblog -Message $_.Exception.Message
        $EXIT_CODE = 1
    }
    finally {
        Write-Joblog -Completed -ProcessedDevices $NumberOfRecentlyStartedDevices -EXIT_CODE $EXIT_CODE
        exit $EXIT_CODE
    }
}
function Start-OutOfScheduleJobs {
    $scriptsToRun = Get-ScriptsToRun
    foreach($S in $scriptsToRun){
        $type = $($S.Type)
        $scriptName = $($S.Name)
        if($ConfigData.$type.$scriptName.RunOnceDeviceBecomeActive -eq 0){
            continue
        }
        Start-Job -Name "RecentlyStarted - $scriptName" `
        -InitializationScript { Set-Location $env:DEVICE_MONITORING_ROOT_DIRECTORY } `
        -ScriptBlock {
            param(
                $type,
                $scriptName
            )
            & ".\Core\$type\$scriptName" -RunOutOfSchedule $true
        } -ArgumentList $type, $scriptName | Out-Null
    }
}
function Wait-ForStartedJobs {
    $Time = [System.Diagnostics.Stopwatch]::StartNew()
    while ($null -ne (Get-Job) -and ($Time.ElapsedMilliseconds -le ($TIMEOUT_SECONDS * 1000))) {
        $jobName = Get-CompletedJobName
        if ($null -ne $jobName) {
            try {
                $Output = Receive-Job -Name $jobName -ErrorAction Stop
            }
            catch {
                Write-Joblog -Message "$jobname - $($_.Exception.Message)"
                $Script:EXIT_CODE = 1 
            }
            Write-Host $jobName
            $Output
            Write-Host "`n"
            Remove-Job -Name $jobName
        }
    }
    Remove-RemainingJobs
}
function Set-RecentlyStartedFlag {
    Invoke-SQLquery -FileQuery $SQL_QUERY_UPDATE_RECENTLY_STARTED_FLAG
}
function Get-ScriptsToRun {
    return $(Invoke-SQLquery -FileQuery $SQL_QUERY_SCRIPTS_TO_RUN -SQLDBName $SQL_LOG_DATABASE)
}

Invoke-Main
