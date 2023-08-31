DECLARE @StartDate AS Date = '2023-08-30'
DECLARE @EndDate AS Date = '2023-08-31'

SELECT

Inventory.DNSHostName,
ROUND((Convert( [float], COUNT(ActiveHour)) / 60) , 0) AS 'Uptime Hrs'

FROM Inventory
LEFT JOIN(
SELECT 
    DNSHostName,
    [TimeStamp],
    DATEPART([HOUR], [TimeStamp]) AS 'ActiveHour'
FROM ResourceConsumption
WHERE 
    [TimeStamp] < @EndDate AND 
    [TimeStamp] > @StartDate 
) Timings
On Inventory.DNSHostName = Timings.DNSHostName
GROUP By Inventory.DNSHostName 