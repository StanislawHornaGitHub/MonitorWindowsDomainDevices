DECLARE @DeviceDNSHostname AS NVARCHAR(50) = 'Server-Core'
DECLARE @DomainName AS NVARCHAR(50) = '.Horna.local'

SELECT CONCAT(@DeviceDNSHostname, @DomainName) AS 'Device Name'
SELECT TOP(10)
    [TimeStamp] AS 'Time',
    ROUND(CPU_Temperature_Current,1,1) AS 'CPU Temperature C',
    ROUND(GPU_Temperature_Current,1,1) AS 'GPU Temperature C',
    ROUND(PowerConsumption_Current,1,1) AS 'Power Consumption W'
FROM Event_PowerAndTemperature
WHERE DNSHostName = CONCAT(@DeviceDNSHostname, @DomainName)
ORDER BY [TimeStamp] DESC