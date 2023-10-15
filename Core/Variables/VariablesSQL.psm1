<#
.SYNOPSIS
    Module with variables related to the communication with SQL Server

.DESCRIPTION
    Module consists of Global variables related to communication with SQL Server.

.NOTES

    Version:            1.0
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      16-Oct-2023
    ChangeLog:

    Date            Who                     What
    
#>
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
New-Variable -Name "SQL_UPDATE_INVENTORY_TABLE" -Value "$SQL_QUERIES_DIRECTORY/UpdateInventoryTable.sql" -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_INSERT_DATA_IF_NOT_EXIST_TEMPLATE" -Value "$SQL_QUERIES_DIRECTORY/InsertDataIfnotExist.sql" -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_ACTIVE_DEVICES_QUERY" -Value "$SQL_QUERIES_DIRECTORY/ActiveDevices.sql" -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_OBJECT_TABLES_WITHOUT_CHANGE_LOG" -Value @(
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