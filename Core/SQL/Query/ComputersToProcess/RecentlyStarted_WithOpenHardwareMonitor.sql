/*
    .DESCRIPTION
        Query to get list of devices meeting following requirements:
            - Currently active
            - RecentlyStarted flag set to true
            - Open Hardware Monitor flag set to true

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
        Creation Date:      29-Sep-2023
        ChangeLog:

        Date            Who                     What

*/
DECLARE @DeviceIsActive AS BIT = 1
DECLARE @RecentlyStarted AS BIT = 1
DECLARE @HardwareMonitorIsDeployed AS BIT = 1

SELECT 
    DNSHostName, 
    IPaddress
FROM Inventory
WHERE isActive = @DeviceIsActive AND 
      RecentlyStarted = @RecentlyStarted AND
      IsHardwareMonitorDeployed = @HardwareMonitorIsDeployed