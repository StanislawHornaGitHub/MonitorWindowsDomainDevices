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
New-Variable -Name "SQL_PRIMARY_KEY" -Value "DNSHostName" -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_LOG_TABLE_PREFIX" -Value "ChangeLog_" -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_INVENTORY_TABLE_NAME" -Value "Inventory" -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_WRITE_TABLE_DATA_TEMPLATE" -Value "$SQL_QUERIES_DIRECTORY/UpdateDataTableTemplate.sql" -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_WRITE_TABLE_DATA_WITH_CHANGE_LOG_TEMPLATE" -Value "$SQL_QUERIES_DIRECTORY/UpdateDataTableTemplateWithChangeLog.sql" -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_ACTIVE_DEVICES_QUERY" -Value "$SQL_QUERIES_DIRECTORY/ActiveDevices.sql" -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_OBJECT_TABLES_WITHOUT_CHANGE_LOG" -Value @(
    "Inventory",
    "LastExecution",
    "Storage"
) -Force -Scope Global -Option ReadOnly
New-Variable -Name "COLUMNS_EXCLUDED_FROM_COMPARISON" -Value @(
    "LastUpdate",
    "Error"
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
## Logs Paths SECTION ##
########################
New-Variable -Name "LOGS_ROOT_DIRECTORY" -Value ".\Log" -Force -Scope Global -Option ReadOnly
New-Variable -Name "JOB_LOG_PATH" -Value "$LOGS_ROOT_DIRECTORY\Job\$((Get-Date).ToString("yyyy-MM-dd"))_Log.txt" -Force -Scope Global -Option ReadOnly
New-Variable -Name "PROCESS_COORDINATOR_LOG_PATH" -Value "$LOGS_ROOT_DIRECTORY\$((Get-Date).ToString("yyyy-MM-dd"))_Process_coordinator_Log.txt" -Force -Scope Global -Option ReadOnly
New-Variable -Name "PIPELINE_LOGS_DIRECTORY" -Value "$LOGS_ROOT_DIRECTORY\Pipelines" -Force -Scope Global -Option ReadOnly

New-Variable `
    -Name "DEVICES_RUNNING_OTHER_OS_THAN_WIN" `
    -Value @("mac-mini.horna.local") `
    -Force -Scope Global -Option ReadOnly