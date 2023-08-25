DECLARE @DeviceDNSHostname AS NVARCHAR(50) = 'Lian6700.Horna.local'

SELECT TOP(10)
    [TimeStamp] AS 'Time',
    ROUND(CPU_Temperature_Current,1,1) AS 'CPU Temperature C',
    ROUND(PowerConsumption_Current,1,1) AS 'Power Consumption W'
FROM PowerAndTemperature
WHERE DNSHostName = @DeviceDNSHostname
ORDER BY [TimeStamp] DESC