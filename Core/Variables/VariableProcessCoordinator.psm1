<#
.SYNOPSIS
    Module with variables used in Process Coordinator script.

.DESCRIPTION
    Module consists of Global variables, related to the process of launching subscripts.

.NOTES

    Version:            1.0
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      19-Oct-2023
    ChangeLog:

    Date            Who                     What
    20-10-2023      Stanisław Horna         Variables scopes changed from "Script" to "Global"
    22-10-2023      Stanisław Horna         Tidying up file structure
#>
New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Global
New-Variable -Name "CONFIG_FILEPATH" -Value "./Config.json" -Force -Scope Global -Option ReadOnly
# Task Scheduler
New-Variable -Name "SCHEDULED_TASK_NAME" -Value "Process_Coordinator" -Force -Scope Global -Option ReadOnly
New-Variable -Name "SCHEDULED_TASK_PATH" "\MonitorWindowsDomainDevices" -Force -Scope Global -Option ReadOnly
# SQL Server 
New-Variable -Name "SQL_NUMBER_OF_TRIES_BEFORE_EXIT" -Value 3 -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_SLEEPTIME_BETWEEN_TRIES_MS" -Value 500 -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_LAST_EXECUTION" -Value "$SQL_QUERIES_DIRECTORY/LastExecution.sql" -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_SLEEP_TIME_FOR_PROCESS_COORDINATOR" -Value "$SQL_QUERIES_DIRECTORY/GetProcessCoordinatorSleepTime.sql" -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_TEST_SLEEP_TIME_SECONDS" -Value 60 -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_BYPASS_EMPTY_INVENTORY" -Value $false -Force -Scope Global -Option ReadOnly
# Data Retriving Scripts
New-Variable -Name "TEST_ICMP_DEVICE_ACTIVE" -Value "./Core/SyncData/Test-ActiveDevices.ps1" -Force -Scope Global -Option ReadOnly
New-Variable -Name "INVOKE_SELECTED_SCRIPTS_ON_RECENLTY_STARTED_DEVICES" -Value ".\Core\SyncData\Get-RecentlyStartedDevicesDetails.ps1" -Force -Scope Global -Option ReadOnly
New-Variable -Name "MAX_SLEEP_INTERVAL" -Value 3600000 -Force -Scope Global
New-Variable -Name "SHIFT_SCRIPT_RUN" -Value 0 -Force -Scope Global
New-Variable -Name "NUMBER_OF_TIMES_SHIFT_SCRIPT_RUN_CAN_BE_USED" -Value 0 -Force -Scope Global
New-Variable -Name "TIME_TO_WAIT_BEFORE_CANCELING_REMAING_JOBS" -Value 60 -Force -Scope Global -Option ReadOnly
New-Variable -Name "COMPONENTS_TO_LOOP_THROUGH" -Value @(
    "SyncData",
    "Events",
    "Objects"
) -Force -Scope Global -Option ReadOnly
# Config commands
New-Variable -Name "STOP_PROCESS_COORDINATOR" -Value 0 -Force -Scope Global
New-Variable -Name "STOP_PROCESS_AND_DISABLE_TASK_SCHEDULER" -Value 0 -Force -Scope Global