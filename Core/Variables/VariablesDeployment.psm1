<#
.SYNOPSIS
    Module with variables related to the deploying additional components.

.DESCRIPTION
    Module consists of Global variables related any aditional components.
    Both deploying of those components and usage.

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
## DEPLOYMENT SECTION ##
########################
New-Variable -Name "DEPLOYMENT_SERVER_SHARE" -Value "\\Server-Automation\DeploymentFiles" -Force -Scope Global -Option ReadOnly
New-Variable -Name "LOCAL_MONITORING_COMPONENTS_PATH" -Value "C:\Program Files\Monitoring_Windows_Domain_Devices" -Force -Scope Global -Option ReadOnly
New-Variable -Name "OPEN_HARDWARE_MONITOR_PATH" -Value "$LOCAL_MONITORING_COMPONENTS_PATH\OpenHardwareMonitorReport" -Force -Scope Global -Option ReadOnly
New-Variable -Name "OPEN_HARDWARE_MONITOR_EXE" -Value "$LOCAL_MONITORING_COMPONENTS_PATH\OpenHardwareMonitor\OpenHardwareMonitor.exe" -Force -Scope Global -Option ReadOnly
New-Variable -Name "OOKLA_SPEEDTEST_EXE" -Value "$LOCAL_MONITORING_COMPONENTS_PATH\OOKLA_Speedtest\speedtest.exe" -Force -Scope Global -Option ReadOnly