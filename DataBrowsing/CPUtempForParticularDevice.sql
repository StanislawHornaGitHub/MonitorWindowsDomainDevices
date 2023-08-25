DECLARE @DeviceDNSHostname AS NVARCHAR(50) = 'Lian6700'
SELECT CONCAT(@DeviceDNSHostname, '.Horna.local') AS 'Device Name'
SELECT TOP(10)
    [TimeStamp] AS 'Time',
    ROUND(CPU_Temperature_Current,1,1) AS 'CPU Temperature C',
    ROUND(GPU_Temperature_Current,1,1) AS 'GPU Temperature C',
    ROUND(PowerConsumption_Current,1,1) AS 'Power Consumption W'
FROM PowerAndTemperature
WHERE DNSHostName = CONCAT(@DeviceDNSHostname, '.Horna.local')
ORDER BY [TimeStamp] DESC