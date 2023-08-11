Import-Module .\Core\JenkinsDependencies\Jenkins.psm1
Import-Module .\Core\Functions\OverallDataTransformation.psm1


New-Variable -Name "ROOT_DIRECTORY" -Value "./DataBase" -Force -Scope Global -Option ReadOnly
New-Variable -Name "OBJECT_DIRECTORY" -Value "$ROOT_DIRECTORY/Object" -Force -Scope Global -Option ReadOnly
New-Variable -Name "EVENT_DIRECTORY" -Value "$ROOT_DIRECTORY/Event" -Force -Scope Global -Option ReadOnly
New-Variable -Name "TEMP_DIRECTORY" -Value "$ROOT_DIRECTORY/Temp" -Force -Scope Global -Option ReadOnly
New-Variable -Name "INVENTORY_TABLE" -Value "$ROOT_DIRECTORY/Object/Inventory.csv" -Force -Scope Global -Option ReadOnly
New-Variable -Name "AVAILABLE_DEVICES_TABLE" -Value "$ROOT_DIRECTORY/Temp/AvailableDevices.csv" -Force -Scope Global -Option ReadOnly