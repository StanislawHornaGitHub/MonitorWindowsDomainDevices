/*
    .DESCRIPTION
        Query to get list of devices meeting following requirements:
            - Currently active
            - RecentlyStarted flag set to true
            - Logons monitoring set to true

    .INPUTS
        None

    .OUTPUTS
        DNSHostName,
        IPaddress

    .NOTES

        Version:            1.2
        Author:             Stanisław Horna
        Mail:               stanislawhorna@outlook.com
        GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
        Creation Date:      29-Sep-2023
        ChangeLog:

        Date            Who                     What
        05-11-2023      Stanisław Horna         LastEventTimeAppErrors column added
        23-12-2023      Stanisław Horna         LastEventTimeLogon column added
*/
DECLARE @DeviceIsActive AS BIT = 1
DECLARE @RecentlyStarted AS BIT = 1
DECLARE @LogonsMonitoring AS BIT = 1

SELECT
    DNSHostName, 
    IPaddress,
    LastEventTimeAppErrors,
    LastEventTimeLogon
FROM Inventory
WHERE isActive=@DeviceIsActive AND 
      RecentlyStarted = @RecentlyStarted AND
      MonitorLogons = @LogonsMonitoring
    