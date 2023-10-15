<#
.SYNOPSIS
    Module with variables related collecting the list of devices to process.

.DESCRIPTION
    Module consists of Global variables,
    related to the process of finding and excluding devices which should be monitored.

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
## Inventory SECTION ##
########################
New-Variable -Name "DEVICES_TO_EXCLUDE_FROM_MONITORING" -Value @(
    "mac-mini.horna.local",
    "truenas.horna.local"
) -Force -Scope Global -Option ReadOnly