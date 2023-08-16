Import-Module .\Core\JenkinsDependencies\Jenkins.psm1
Import-Module .\Core\Functions\OverallDataTransformation.psm1
Import-Module .\Core\SQL\Module\SQL.psm1
###########################
## FILE DATABASE SECTION ##
###########################
New-Variable -Name "ROOT_DIRECTORY" -Value "./DataBase" -Force -Scope Global -Option ReadOnly
New-Variable -Name "OBJECT_DIRECTORY" -Value "$ROOT_DIRECTORY/Object" -Force -Scope Global -Option ReadOnly
New-Variable -Name "EVENT_DIRECTORY" -Value "$ROOT_DIRECTORY/Event" -Force -Scope Global -Option ReadOnly
New-Variable -Name "TEMP_DIRECTORY" -Value "$ROOT_DIRECTORY/Temp" -Force -Scope Global -Option ReadOnly
New-Variable -Name "INVENTORY_TABLE" -Value "$ROOT_DIRECTORY/Object/Inventory.csv" -Force -Scope Global -Option ReadOnly
New-Variable -Name "AVAILABLE_DEVICES_TABLE" -Value "$ROOT_DIRECTORY/Temp/AvailableDevices.csv" -Force -Scope Global -Option ReadOnly
##########################
## SQL DATABASE SECTION ##
##########################
New-Variable -Name "SQL_QUERIES_DIRECTORY" -Value "./Core/SQL/Query" -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_SERVER" -Value "Server-Automation" -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_DATABASE" -Value "Device_Monitoring" -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_PRIMARY_KEY" -Value "DNSHostName" -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_WRITE_TABLE_DATA_TEMPLATE" -Value "$SQL_QUERIES_DIRECTORY/UpdateDataTableTemplate.sql" -Force -Scope Global -Option ReadOnly
New-Variable -Name "SQL_ACTIVE_DEVICES_QUERY" -Value "$SQL_QUERIES_DIRECTORY/ActiveDevices.sql" -Force -Scope Global -Option ReadOnly

New-Variable `
    -Name "DEVICES_RUNNING_OTHER_OS_THAN_WIN" `
    -Value @("mac-mini.horna.local") `
    -Force -Scope Global -Option ReadOnly