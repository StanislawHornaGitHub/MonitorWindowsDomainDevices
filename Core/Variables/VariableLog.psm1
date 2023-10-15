<#
.SYNOPSIS
    Module with variables related to Logging capabilities

.DESCRIPTION
    Module consists of Global variables related to generating any kind of logs,
    which are produced during Monitoring Solution operational work

.NOTES

    Version:            1.0
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      16-Oct-2023
    ChangeLog:

    Date            Who                     What
    
#>
########################
## Log Paths SECTION ##
########################
New-Variable -Name "DAYS_TO_KEEP_LOGS_IN_FILE_FORMAT" -Value 2 -Force -Scope Global -Option ReadOnly
New-Variable -Name "LOGS_ROOT_DIRECTORY" -Value ".\Log" -Force -Scope Global -Option ReadOnly
New-Variable -Name "LOGS_JOB_DIRECTORY" -Value ".\Log\Job" -Force -Scope Global -Option ReadOnly
New-Variable -Name "JOB_LOG_PATH" -Value "$LOGS_JOB_DIRECTORY\$((Get-Date).ToString("yyyy-MM-dd"))_Log.txt" -Force -Scope Global -Option ReadOnly
New-Variable -Name "PROCESS_COORDINATOR_LOG_PATH" -Value "$LOGS_ROOT_DIRECTORY\$((Get-Date).ToString("yyyy-MM-dd"))_Process_coordinator_Log.txt" -Force -Scope Global -Option ReadOnly
New-Variable -Name "PIPELINE_LOGS_DIRECTORY" -Value "$LOGS_ROOT_DIRECTORY\Pipelines" -Force -Scope Global -Option ReadOnly