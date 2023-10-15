<#
.SYNOPSIS
    Module with Environmental variables.

.DESCRIPTION
    Module consists of Environmental variables required in Monitoring Solution

.NOTES

    Version:            1.0
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      16-Oct-2023
    ChangeLog:

    Date            Who                     What
    
#>
###########################
## Env Variables Section ##
###########################
$env:DEVICE_MONITORING_ROOT_DIRECTORY = $((Get-Location).Path)