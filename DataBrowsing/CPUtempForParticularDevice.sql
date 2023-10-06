/*
    .DESCRIPTION
        Query to retrieve basic computer properties.

    .INPUTS
        @DeviceDNSHostname - Hostname of the device
        @DomainName - Active Directory domain name where device is connected
        @NumberOfEntriesToReturn - number of entries to return

    .OUTPUTS
        Returns latests events for particular device with following columns: 
            Device Name - DNS Hostname
            Time - Timestamp when particular value was collected
            CPU Temperature C - CPU Temperature in Celsius
            GPU Temperature C - GPU Temperature in Celsius
            Power Consumption W - Power Consumption in Wats
        Number of entries is specified in variable @NumberOfEntriesToReturn.

    .NOTES

        Version:            1.0
        Author:             Stanisław Horna
        Mail:               stanislawhorna@outlook.com
        GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
        Creation Date:      25-Aug-2023
        ChangeLog:

        Date            Who                     What

*/
DECLARE @DeviceDNSHostname AS NVARCHAR(50) = 'Server-Core'
DECLARE @DomainName AS NVARCHAR(50) = '.Horna.local'
DECLARE @NumberOfEntriesToReturn AS INT = 10

SELECT CONCAT(@DeviceDNSHostname, @DomainName) AS 'Device Name'
SELECT TOP(@NumberOfEntriesToReturn)
    [TimeStamp] AS 'Time',
    ROUND(CPU_Temperature_Current,1,1) AS 'CPU Temperature C',
    ROUND(GPU_Temperature_Current,1,1) AS 'GPU Temperature C',
    ROUND(PowerConsumption_Current,1,1) AS 'Power Consumption W'
FROM Event_PowerAndTemperature
WHERE DNSHostName = CONCAT(@DeviceDNSHostname, @DomainName)
ORDER BY [TimeStamp] DESC