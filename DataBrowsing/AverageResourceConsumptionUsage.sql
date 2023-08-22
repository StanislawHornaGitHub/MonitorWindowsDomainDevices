SELECT
    SUBSTRING(PerformanceCounters.DNSHostName,1,(CHARINDEX('.',PerformanceCounters.DNSHostName) - 1)) AS 'Name',
    ROUND(AVG(CPU_time_Percentage),1,1)AS 'CPU usage %',
    ROUND(AVG(RAM_usage_Percentage),1,1) AS 'RAM usage %',
    ROUND(AVG(Disk_time_Percentage),1,1) AS 'Disk usage %',
    ROUND(AVG(Network_Total_Mbps),3,1) AS 'Network Traffic Mbps',
    Hardware.CPUmodel
FROM PerformanceCounters
LEFT JOIN Hardware On PerformanceCounters.DNSHostName = Hardware.DNSHostName
GROUP BY PerformanceCounters.DNSHostName, Hardware.DNSHostName
