<#
.SYNOPSIS
    Module with functions to retrieve information from monitored devices.

.DESCRIPTION
    Module consists of functions used get necessary data required to start collecting info from devices
    and those which are starting separate background job for each device to collect data.

    It contain following functions:
        Get-CompletedJobName - used to get the job name of completed job
        Remove-RemainingJobs - remove jobs which did not ended
        Get-DevicesList - Get devices list to process

.NOTES

    Version:            1.0
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      28-Aug-2023
    ChangeLog:

    Date            Who                     What

#>
function Get-CompletedJobName {
    $jobName = $null
    $jobName = (Get-Job | Where-Object { $_.State -ne "Running" } | Select-Object -First 1).Name
    return $jobName
}
function Remove-RemainingJobs {
    $remainingJobs = Get-Job
    if ($null -ne $remainingJobs) {
        $remainingJobs | Remove-Job -Force
        Write-Joblog -Message "Background jobs were running longer than REMOTE_CONNECTION_TIMEOUT_SECONDS ($REMOTE_CONNECTION_TIMEOUT_SECONDS). JobNames: $($remainingJobs.Name -join ", ")"
    }
}
function Get-DevicesList {
    param (
        [bool]$RunOutOfSchedule,
        $QueryWithSchedule,
        $QueryOutOfSchedule
    )
    if($RunOutOfSchedule -eq $true){
        $Computer = Get-ComputerListToProcess -PredefinedQuery $QueryOutOfSchedule
    }else{
        $Computer = Get-ComputerListToProcess -PredefinedQuery $QueryWithSchedule
    }
    if($null -eq $Computer){
        return $null
    }
    if($null -eq $Computer.count){
        New-Variable -Name "PROCESSED_DEVICES" -Value 1 -Force -Scope Global -Option ReadOnly
    }else{
        New-Variable -Name "PROCESSED_DEVICES" -Value $($Computer.count) -Force -Scope Global -Option ReadOnly
    }
    return $Computer
}