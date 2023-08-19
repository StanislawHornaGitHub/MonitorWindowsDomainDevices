SELECT
    SUBSTRING(DNSHostName,1,(CHARINDEX('.',DNSHostName) - 1)) AS 'Name',
    AVG(CPU_time_Percentage) AS 'CPU usage',
    AVG(RAM_usage_Percentage) AS 'RAM usage',
    AVG(Disk_time_Percentage) AS 'Disk usage',
    AVG(Network_Total_Mbps) AS 'Network Traffic per s'
FROM PerformanceCounters
GROUP BY DNSHostName