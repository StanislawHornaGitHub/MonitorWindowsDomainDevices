/*
    .DESCRIPTION
        Query to change IsHardwareMonitorDeployed column value to 0.
        Mostly used in "Deploy-OpenHardwareMonitor.ps1"

    .INPUTS
        COMPUTER_DNS_HOSTNAME_VARIABLE - Row identifier value.

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

*/
DECLARE @HardwareMonitorIsNotDeployed AS BIT = 0
DECLARE @DeviceDNSHostnameToUpdate AS NVARCHAR(50) = 'COMPUTER_DNS_HOSTNAME_VARIABLE'

UPDATE Inventory
SET IsHardwareMonitorDeployed = @HardwareMonitorIsNotDeployed
WHERE DNSHostName = @DeviceDNSHostnameToUpdate