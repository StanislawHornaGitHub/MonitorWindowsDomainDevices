SELECT
    SUBSTRING(Hardware.DNSHostName,1,(CHARINDEX('.',Hardware.DNSHostName) - 1)) AS 'Name',
    DeviceModel,
    PowerAndTemp.[CPU Temp C],
    PowerAndTemp.[Power Consumption W],
    Load.[CPU usage %],
    Load.[RAM usage %],
    Load.[Disk usage %],
    Load.[Disk Read MB per s],
    Load.[Disk Write MB per s],
    Load.[Network Received Mbps],
    Load.[Network Sent Mbps]
FROM Hardware
LEFT JOIN 
(SELECT 
    DNSHostName,
    ROUND(AVG(CPU_Temperature_Current),1 ,1) AS 'CPU Temp C',
    ROUND(AVG(PowerConsumption_Current),1 ,1) AS 'Power Consumption W'
FROM PowerAndTemperature
GROUP BY DNSHostName) PowerAndTemp 
    On Hardware.DNSHostName = PowerAndTemp.DNSHostName
LEFT JOIN 
(SELECT
    DNSHostname,
    ROUND(AVG(CPU_Load_Percentage),1,1) AS 'CPU usage %',
    ROUND(AVG(RAM_usage_Percentage),1,1) AS 'RAM usage %',
    ROUND(AVG(Disk_time_Percentage),1,1) AS 'Disk usage %',
    ROUND(AVG(Disk_Read_MBps), 1,1) AS 'Disk Read MB per s',
    ROUND(AVG(Disk_Write_MBps), 1,1) AS 'Disk Write MB per s',
    ROUND(AVG(NIC_Received_MBps),3,1) AS 'Network Received Mbps',
    ROUND(AVG(NIC_Sent_Mbps),3,1) AS 'Network Sent Mbps'
FROM ResourceConsumption
Group By DNSHostName) Load ON Load.DNSHostName = Hardware.DNSHostName
GROUP BY 
Hardware.DNSHostName,
DeviceModel,
PowerAndTemp.[CPU Temp C],
PowerAndTemp.[Power Consumption W],
Load.[CPU usage %],
Load.[RAM usage %],
Load.[Disk usage %],
Load.[Disk Read MB per s],
Load.[Disk Write MB per s],
Load.[Network Received Mbps],
Load.[Network Sent Mbps]
ORDER BY [Power Consumption W] DESC
