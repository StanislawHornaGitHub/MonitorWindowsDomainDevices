/*
    .DESCRIPTION
        Query to retrieve average values for columns specified in OUTPUTS.
        Average is calculated based on events collected within time frame,
        which is configured in INPUTS variables.

    .INPUTS
        @StartDate
        @EndDate

        To have an average for particular day, set:
            StartDate for the date from which you would like to get the average
            EndDate - StartDate + 1
        E.g. @StartDate = '2023-09-12', @EndDate = '2023-09-13',
        in such case all events collected on 2023-09-12 will be included in average.

    .OUTPUTS
        Name - Device's Hostname without domain part
        DeviceModel - Model of the device
        CPU Temp C - CPU Temperature in Celsius
        Power Consumption - Power Consumption in Wats
        CPU usage % - Percentage of busy CPU time
        RAM usage % - Percentage of used RAM memory
        Disk usage % - Percentage of Disk activeness time
        Disk Read MB per s - Disk read speed
        Disk Write MB per s - Disk write speed
        Network Received Mbps - Network incoming traffic speed
        Network Sent Mbps - Network outgoing traffic speed

    .NOTES

        Version:            1.0
        Author:             Stanisław Horna
        Mail:               stanislawhorna@outlook.com
        GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
        Creation Date:      19-Aug-2023
        ChangeLog:

        Date            Who                     What

*/
DECLARE @StartDate AS Date = '2023-09-12'
DECLARE @EndDate AS Date = '2023-09-13'

-- Select final set of columns
SELECT
    SUBSTRING(Object_Hardware.DNSHostName,1,(CHARINDEX('.',Object_Hardware.DNSHostName) - 1)) AS 'Name',
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
FROM Object_Hardware
    LEFT JOIN
            -- Sub query to calculate average CPU temp and Power Consumption within time frame
            (SELECT 
                DNSHostName,
                ROUND(AVG(CPU_Temperature_Current),1 ,1) AS 'CPU Temp C',
                ROUND(AVG(PowerConsumption_Current),1 ,1) AS 'Power Consumption W'
            FROM Event_PowerAndTemperature
            WHERE [TimeStamp] > @StartDate AND [TimeStamp] < @EndDate
            GROUP BY DNSHostName) PowerAndTemp 
                ON Object_Hardware.DNSHostName = PowerAndTemp.DNSHostName
    LEFT JOIN
            -- Sub query to calculate average Device usage parameters within time frame
            (SELECT
                DNSHostname,
                ROUND(AVG(CPU_Load_Percentage),1,1) AS 'CPU usage %',
                ROUND(AVG(RAM_usage_Percentage),1,1) AS 'RAM usage %',
                ROUND(AVG(Disk_time_Percentage),1,1) AS 'Disk usage %',
                ROUND(AVG(Disk_Read_MBps), 1,1) AS 'Disk Read MB per s',
                ROUND(AVG(Disk_Write_MBps), 1,1) AS 'Disk Write MB per s',
                ROUND(AVG(NIC_Received_MBps),3,1) AS 'Network Received Mbps',
                ROUND(AVG(NIC_Sent_Mbps),3,1) AS 'Network Sent Mbps'
            FROM Event_ResourceConsumption
            WHERE [TimeStamp] > @StartDate AND [TimeStamp] < @EndDate
            GROUP BY DNSHostName) Load 
                ON Load.DNSHostName = Object_Hardware.DNSHostName
-- Section required to display all information for particular device in one row
GROUP BY 
    Object_Hardware.DNSHostName,
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