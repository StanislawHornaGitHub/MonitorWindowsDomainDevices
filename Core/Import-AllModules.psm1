Import-Module .\Core\JenkinsDependencies\Jenkins.psm1
Import-Module .\Core\Functions\OverallDataTransformation.psm1


New-Variable -Name "ROOT_DIRECTORY" -Value "./DataBase" -Force -Scope Script -Option ReadOnly
New-Variable -Name "OBJECT_DIRECTORY" -Value "$ROOT_DIRECTORY/Object" -Force -Scope Script -Option ReadOnly
New-Variable -Name "EVENT_DIRECTORY" -Value "$ROOT_DIRECTORY/Event" -Force -Scope Script -Option ReadOnly
New-Variable -Name "TEMP_DIRECTORY" -Value "$ROOT_DIRECTORY/Temp" -Force -Scope Script -Option ReadOnly