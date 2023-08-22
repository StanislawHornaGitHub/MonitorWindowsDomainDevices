SELECT
    SUBSTRING(Hardware.DNSHostName,1,(CHARINDEX('.',Hardware.DNSHostName) - 1)) AS 'Name',
    DeviceModel,
    ROUND(AVG(CPU_time_Percentage),1,1)AS 'CPU usage %',
    ROUND(AVG(RAM_usage_Percentage),1,1) AS 'RAM usage %',
    ROUND(AVG(Disk_time_Percentage),1,1) AS 'Disk usage %',
    ROUND(AVG(Network_Total_Mbps),3,1) AS 'Network Traffic Mbps',
    ROUND(AVG(PowerAndTemperature.PowerConsumption_MAX),1,1) AS 'PowerConsumption W'
FROM Hardware
LEFT JOIN PowerAndTemperature 
    On Hardware.DNSHostName = PowerAndTemperature.DNSHostName
JOIN PerformanceCounters 
    On Hardware.DNSHostName = PerformanceCounters.DNSHostName
GROUP BY Hardware.DNSHostName, DeviceModel
ORDER BY 'PowerConsumption W' DESC
