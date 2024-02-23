<#
.SYNOPSIS
    Script to Deploy Open Hardware Monitor

.DESCRIPTION
    Script responsible for deploying Open Hardware Monitor components,
    which are required to capture CPU and GPU temperature, as well as Power Consumption.
    Script is connecting to each device which where such information can be monitor.
    Following steps are performed:
    1. Creating local folder on each device to store additional components
    2. Downloading components from Network share
    3. Update Inventory table for devices where deployment was successfull

.INPUTS
    None

.OUTPUTS
    None

.NOTES

    Version:            1.0
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      22-Aug-2023
    ChangeLog:

    Date            Who                     What

#>
param(
    [bool]$RunOutOfSchedule = $false,
    [switch]$DEBUG
)

Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script

New-Variable -Name 'DEPLOYMENT_SERVER_FOLDER_NAME_TO_COPY' -Value "OpenHardwareMonitor" -Force -Scope Script
New-Variable -Name "QUERY_TO_RUN_WITH_SCHEDULE" -Value "DevicesToDeployOpenHardwareMonitor.sql" -Force -Scope Script
New-Variable -Name "QUERY_TO_RUN_OUTOF_SCHEDULE" -Value "DevicesToDeployOpenHardwareMonitor.sql" -Force -Scope Script

function Invoke-Main {
    try {
        Test-DevicesActive
        Invoke-Deployment
    }
    catch {
        Write-Host $_
        $EXIT_CODE = 1
    }
    finally {
        exit $EXIT_CODE
    }
}
function Test-DevicesActive {
    & ".\Core\SyncData\Test-ActiveDevices.ps1"
}
function Invoke-Deployment {
    $Computers = Get-DevicesList -RunOutOfSchedule $RunOutOfSchedule `
    -QueryWithSchedule $QUERY_TO_RUN_WITH_SCHEDULE `
    -QueryOutOfSchedule $QUERY_TO_RUN_OUTOF_SCHEDULE
    [string]$UpdateIsOHMdeployed = Get-Content -Path "$SQL_VALUE_UPDATE_QUERIES\UpdateIsOpenHardwareMonitorDeployed.sql"
    foreach ($C in $Computers) {
        Write-host "$($C.DNSHostName)"
        try {
            Invoke-Command -ComputerName $($C.DNSHostName)-ScriptBlock {
                param(
                    $LOCAL_MONITORING_COMPONENTS_PATH,
                    $DEPLOYMENT_SERVER_FOLDER_NAME_TO_COPY,
                    $DEPLOYMENT_SERVER_SHARE
                )
                # Create local directory for additional components if such does not exist
                if (-not (Test-Path -Path $LOCAL_MONITORING_COMPONENTS_PATH)) {
                    New-Item -ItemType Directory -Path $LOCAL_MONITORING_COMPONENTS_PATH | Out-Null
                }
                # Map network share to download the components folder
                New-PSDrive -Name "Deployment" -Root $DEPLOYMENT_SERVER_SHARE -PSProvider FileSystem -ErrorAction Stop | Out-Null
                # Download component folder
                Copy-Item -Path "Deployment:\$DEPLOYMENT_SERVER_FOLDER_NAME_TO_COPY" `
                    -Destination $LOCAL_MONITORING_COMPONENTS_PATH `
                    -Recurse `
                    -Force `
                    -Confirm:$false `
                    -ErrorAction Stop
            } -ArgumentList $LOCAL_MONITORING_COMPONENTS_PATH, $DEPLOYMENT_SERVER_FOLDER_NAME_TO_COPY, $DEPLOYMENT_SERVER_SHARE `
                -ErrorAction Stop
            # Update Inventory table
            $QueryToInvoke = $UpdateIsOHMdeployed.Replace("COMPUTER_DNS_HOSTNAME_VARIABLE", $($C.DNSHostName))
            Invoke-SQLquery -Query $QueryToInvoke
        }
        catch {
            Write-host "$($C.DNSHostName) - Deployment was not successfull"
            Write-Host $_
        }

    }
}
function Get-ComputerListToDeployment {
    try {
        $Result = Invoke-SQLquery -FileQuery $SQL_DEVICES_TO_DEPLOYMENT
    }
    catch {
        throw $_.Exception.Message
    }
    if ($null -eq $Result) {
        throw "There are no devices to process."
    }
    return $Result
}

Invoke-Main