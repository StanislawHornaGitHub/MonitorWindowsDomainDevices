/*
    .DESCRIPTION
        Query to get list of active devices which have GreenCell UPS Connected.

    .INPUTS
        None

    .OUTPUTS
        DNSHostName,
        IPaddress,
        PassPhrase

    .NOTES

        Version:            1.0
        Author:             Stanisław Horna
        Mail:               stanislawhorna@outlook.com
        GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
        Creation Date:      24-Feb-2024
        ChangeLog:

        Date            Who                     What

*/
DECLARE @DeviceIsActive AS BIT = 1
DECLARE @ServiceName AS VARCHAR(200) = 'GC_UPS'

SELECT
    i.DNSHostName,
    i.IPaddress,
    s.PassPhrase
FROM Inventory i
RIGHT JOIN Device_Monitoring_Maintenance.dbo.Secrets s ON s.DNSHostName = i.DNSHostName
WHERE isActive = @DeviceIsActive AND ServiceName = @ServiceName
