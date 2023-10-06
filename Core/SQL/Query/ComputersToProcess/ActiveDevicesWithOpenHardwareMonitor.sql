/*
    .DESCRIPTION
        Query to get list of active devices which have Open Hardware Monitor package deployed.

    .INPUTS
        None

    .OUTPUTS
        DNSHostName,
        IPaddress

    .NOTES

        Version:            1.0
        Author:             Stanisław Horna
        Mail:               stanislawhorna@outlook.com
        GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
        Creation Date:      22-Aug-2023
        ChangeLog:

        Date            Who                     What

*/
DECLARE @DeviceIsActive AS BIT = 1
DECLARE @HardwareMonitorIsDeployed AS BIT = 1

SELECT 
    DNSHostName, 
    IPaddress
FROM Inventory
WHERE isActive = @DeviceIsActive AND 
      IsHardwareMonitorDeployed = @HardwareMonitorIsDeployed