SELECT
    SUBSTRING(Hardware.DNSHostName,1,(CHARINDEX('.',Hardware.DNSHostName) - 1)) AS 'Name',
    DeviceModel,
    WMIload.CPUusage AS 'CPU usage %',
    ROUND(AVG(RAM_usage_Percentage),1,1) AS 'RAM usage %',
    ROUND(AVG(Disk_time_Percentage),1,1) AS 'Disk usage %',
    ROUND(AVG(Network_Total_Mbps),3,1) AS 'Network Traffic Mbps',
    ROUND(AVG(PowerAndTemperature.CPU_Temperature_Max),1,1) AS 'CPU Temperature C',
    ROUND(AVG(PowerAndTemperature.PowerConsumption_MAX),1,1) AS 'PowerConsumption W',
    WMIload.Measurement AS 'Number of measurements'
FROM Hardware
LEFT JOIN PowerAndTemperature 
    On Hardware.DNSHostName = PowerAndTemperature.DNSHostName
JOIN PerformanceCounters 
    On Hardware.DNSHostName = PerformanceCounters.DNSHostName
LEFT JOIN (SELECT 
    DNSHostname,
    ROUND(AVG(CPU_Load_Percentage),1,1) AS 'CPUusage',
    COUNT(CPU_Load_Percentage) AS 'Measurement'
FROM ResourceConsumption_OLD
Where ResourceConsumption_OLD.TimeStamp > '2023-08-20'
GROUP BY DNSHostName) WMIload ON WMIload.DNSHostName = Hardware.DNSHostName
GROUP BY Hardware.DNSHostName, DeviceModel, WMIload.CPUusage, WMIload.Measurement
ORDER BY 'PowerConsumption W' DESC
