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
    15-10-2023      Stanisław Horna         All variables definitions moved to dedicated files.

#>
#############################
## Import Function Modules ##
#############################
Import-Module .\Core\Functions\RetrievingData.psm1
Import-Module .\Core\Functions\Logging.psm1
Import-Module .\Core\SQL\Module\SQL.psm1
Import-Module .\Core\Functions\Utility.psm1

#############################
## Import Variable Modules ##
#############################
Import-Module .\Core\Variables\VariablesSQL.psm1
Import-Module .\Core\Variables\VariablesDeployment.psm1
Import-Module .\Core\Variables\VariableEnvironment.psm1
Import-Module .\Core\Variables\VariableLog.psm1
Import-Module .\Core\Variables\VariableInventory.psm1
