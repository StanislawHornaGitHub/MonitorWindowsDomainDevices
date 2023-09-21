<#
.SYNOPSIS
    Main module used required for every script

.DESCRIPTION
    Main module imported in every script to import other modules from the project.
    It is also responsible for creating variables common for every script.

    It contains following sections:
        Import Modules
        SQL Database
        Deployment
        Environmental variables
        Log paths

.NOTES

    Version:            1.0
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      9-Aug-2023
    ChangeLog:

    Date            Who                     What

#>
############################
## Import Modules SECTION ##
############################
Import-Module .\Core\Functions\RetrievingData.psm1
Import-Module .\Core\Functions\Logging.psm1
Import-Module .\Core\SQL\Module\SQL.psm1

##########################
## SQL DATABASE SECTION ##
##########################
New-Variable -Name "BYPASS_EMPTY_INVENTORY_TABLE" -Value $false -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_QUERIES_DIRECTORY" -Value "./Core/SQL/Query" -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_SERVER" -Value "Server-Automation" -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_DATABASE" -Value "Device_Monitoring" -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_LOG_DATABASE" -Value "Device_Monitoring_Maintenance" -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_PRIMARY_KEY" -Value "DNSHostName" -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_LOG_TABLE_PREFIX" -Value "ChangeLog_" -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_INVENTORY_TABLE_NAME" -Value "Inventory" -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_WRITE_TABLE_DATA_TEMPLATE" -Value "$SQL_QUERIES_DIRECTORY/UpdateDataTableTemplate.sql" -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_WRITE_TABLE_DATA_WITH_CHANGE_LOG_TEMPLATE" -Value "$SQL_QUERIES_DIRECTORY/UpdateDataTableTemplateWithChangeLog.sql" -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_INSERT_DATA_IF_NOT_EXIST_TEMPLATE" -Value "$SQL_QUERIES_DIRECTORY/InsertDataIfnotExist.sql" -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_ACTIVE_DEVICES_QUERY" -Value "$SQL_QUERIES_DIRECTORY/ActiveDevices.sql" -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_OBJECT_TABLES_WITHOUT_CHANGE_LOG" -Value @(
    "Inventory",
    "LastExecution",
    "Storage"
) -Force -Scope Global -Option ReadOnly
New-Variable -Name "COLUMNS_EXCLUDED_FROM_COMPARISON" -Value @(
    "LastUpdate", # Common field for all Object Tables
    "Error", # Get-DeviceInventoryToMonitor
    "LastBootTime", # Get-OSVersionInformation
    "CurrentlyLoggedOn", # Get-OSVersionInformation
    "EstimatedSize_GB", # Get-InstalledPackages
    "DriveFreeSpace_GB", # Get-VolumeSpace
    "DriveUsed_Percentage" # Get-VolumeSpace
) -Force -Scope Global -Option ReadOnly
New-Variable -Name "TABLES_WHERE_TEMP_NAME_USE_DNSHOSTNAME" -Value @(
    "Packages"
) -Force -Scope Global -Option ReadOnly
########################
## DEPLOYMENT SECTION ##
########################
New-Variable -Name "DEPLOYMENT_SERVER_SHARE" -Value "\\Server-Automation\Files" -Force -Scope Global -Option ReadOnly
New-Variable -Name "LOCAL_MONITORING_COMPONENTS_PATH" -Value "C:\Program Files\Monitoring_Windows_Domain_Devices" -Force -Scope Global -Option ReadOnly
New-Variable -Name "OPEN_HARDWARE_MONITOR_PATH" -Value "$LOCAL_MONITORING_COMPONENTS_PATH\OpenHardwareMonitorReport" -Force -Scope Global -Option ReadOnly
New-Variable -Name "OPEN_HARDWARE_MONITOR_EXE" -Value "$LOCAL_MONITORING_COMPONENTS_PATH\OpenHardwareMonitor\OpenHardwareMonitor.exe" -Force -Scope Global -Option ReadOnly

###########################
## Env Variables Section ##
###########################
$env:DEVICE_MONITORING_ROOT_DIRECTORY = $((Get-Location).Path)

########################
## Log Paths SECTION ##
########################
New-Variable -Name "DAYS_TO_KEEP_LOGS_IN_FILE_FORMAT" -Value 2 -Force -Scope Global -Option ReadOnly
New-Variable -Name "LOGS_ROOT_DIRECTORY" -Value ".\Log" -Force -Scope Global -Option ReadOnly
New-Variable -Name "LOGS_JOB_DIRECTORY" -Value ".\Log\Job" -Force -Scope Global -Option ReadOnly
New-Variable -Name "JOB_LOG_PATH" -Value "$LOGS_JOB_DIRECTORY\$((Get-Date).ToString("yyyy-MM-dd"))_Log.txt" -Force -Scope Global -Option ReadOnly
New-Variable -Name "PROCESS_COORDINATOR_LOG_PATH" -Value "$LOGS_ROOT_DIRECTORY\$((Get-Date).ToString("yyyy-MM-dd"))_Process_coordinator_Log.txt" -Force -Scope Global -Option ReadOnly
New-Variable -Name "PIPELINE_LOGS_DIRECTORY" -Value "$LOGS_ROOT_DIRECTORY\Pipelines" -Force -Scope Global -Option ReadOnly

New-Variable -Name "DEVICES_TO_EXCLUDE_FROM_MONITORING" -Value @(
    "mac-mini.horna.local",
    "truenas.horna.local"
) -Force -Scope Global -Option ReadOnly