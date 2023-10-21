/*
    .DESCRIPTION
        Query to calculate average of values from Output per day for period selected in INPUTS

    .INPUTS
        @StartDate
        @EndDate

        To have an average for particular day, set:
            StartDate for the date from which you would like to get the average
            EndDate - StartDate + 1
        E.g. @StartDate = '2023-09-12', @EndDate = '2023-09-13',
        in such case all events collected on 2023-09-12 will be included in average.

    .OUTPUTS
        Date
        Avg Ping
        Avg jitter
        Avg Download speed Mbps
        Avg High latency Download
        Avg Upload speed Mbps
        Avg High latency Upload

    .NOTES

        Version:            1.0
        Author:             Stanisław Horna
        Mail:               stanislawhorna@outlook.com
        GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
        Creation Date:      13-Oct-2023
        ChangeLog:

        Date            Who                     What

*/
DECLARE @StartDate AS Date = '1900-01-01'
DECLARE @EndDate AS Date = '2099-01-01'

SELECT
        Extracted_date AS 'Date',
        AVG(Ping_Latency_ms) AS 'Avg Ping',
        AVG(Ping_jitter_ms) AS 'Avg jitter',
        AVG(Download_Speed_Mbps) AS 'Avg Download speed Mbps',
        AVG(Download_Latency_High_ms) AS 'Avg High latency Download',
        AVG(Upload_Speed_Mbps) AS 'Avg Upload speed Mbps',
        AVG(Upload_Latency_High_ms) AS 'Avg High latency Upload'
FROM (
SELECT
        DATEADD(dd, 0, DATEDIFF(dd, 0, [TimeStamp])) AS 'Extracted_date',
        Ping_Latency_ms,
        Ping_jitter_ms,
        Download_Speed_Mbps,
        Download_Latency_High_ms,
        Upload_Speed_Mbps,
        Upload_Latency_High_ms
    FROM Event_SpeedTest
    WHERE [TimeStamp] > @StartDate AND
          [TimeStamp] < @EndDate
) SpeedTests
GROUP BY Extracted_date
ORDER BY Extracted_date DESC