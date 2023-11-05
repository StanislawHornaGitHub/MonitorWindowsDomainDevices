/*
    .DESCRIPTION
        Query to get list of active devices which have Logons monitoring enabled.

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
        Creation Date:      12-Sep-2023
        ChangeLog:

        Date            Who                     What
        05-11-2023      Stanisław Horna         LastEventTimeAppErrors column added
*/
DECLARE @DeviceIsActive AS BIT = 1
DECLARE @LogonsMonitoring AS BIT = 1

SELECT
    DNSHostName,
    IPaddress,
    LastEventTimeAppErrors
FROM Inventory
WHERE isActive = @DeviceIsActive AND
      MonitorLogons = @LogonsMonitoring