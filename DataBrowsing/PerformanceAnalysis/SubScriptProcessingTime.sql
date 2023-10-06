/*
    .DESCRIPTION
        Query to retrieve statistics related to triggered script in a given time frame.
        Output is presented as 3 tables:
            1. Average processing time based on the script type
            2. Average processing time for each script
            3. Average processing time for each script with the dispersion to number of processed devices

    .INPUTS
        @StartDate
        @EndDate

        To have an average for particular day, set:
            StartDate for the date from which you would like to get the average
            EndDate - StartDate + 1
        E.g. @StartDate = '2023-09-12', @EndDate = '2023-09-13',
        in such case all logs collected on 2023-09-12 will be included in average.

    .OUTPUTS
        Script_Name - Name of the script
        Type - Script type [Objects/Events/SyncData]
        Average Processing time - average script execution duration
        Number of executions - number of script executions within configured time frame.
        Remaining_Seconds_To_Next_Run - seconds to the next script run
        Average Number of processed devices - Average devices processed during selected time frame.
            (For first and second table ONLY)
        Processed_devices - Exact number of processed devices
            (For third table ONLY)

    .NOTES

        Version:            1.0
        Author:             Stanisław Horna
        Mail:               stanislawhorna@outlook.com
        GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
        Creation Date:      21-Aug-2023
        ChangeLog:

        Date            Who                     What

*/
DECLARE @StartDate AS Date = '2023-09-12'
DECLARE @EndDate AS Date = '2023-09-13'

-- First table section
SELECT
    LastExecution.[Type],
    CAST(CAST(AVG(CAST(CAST(Duration as datetime) as float)) as datetime) as time) AS 'Average Processing time',
    COUNT(Script_Name) AS 'Number of executions',
    AVG(Processed_devices) AS 'Average Number of processed devices'
FROM Log_Job
LEFT JOIN LastExecution ON CONCAT(Log_Job.Script_name, '.ps1') = LastExecution.Name
Where [Start_time] > @StartDate AND [End_time] < @EndDate
GROUP BY LastExecution.[Type]
ORDER BY LastExecution.[Type]

-- Second table section
SELECT
    Script_Name,
    LastExecution.[Type],
    CAST(CAST(AVG(CAST(CAST(Duration as datetime) as float)) as datetime) as time) AS 'Average Processing time',
    COUNT(Script_Name) AS 'Number of executions',
    AVG(Processed_devices) AS 'Average Number of processed devices'
FROM Log_Job
LEFT JOIN LastExecution ON CONCAT(Log_Job.Script_name, '.ps1') = LastExecution.Name
Where [Start_time] > @StartDate AND [End_time] < @EndDate
GROUP BY Script_name, LastExecution.[Type]
ORDER BY LastExecution.[Type]

-- Third table section
SELECT
    Script_Name,
    LastExecution.[Type],
    CAST(CAST(AVG(CAST(CAST(Duration as datetime) as float)) as datetime) as time) AS 'Average Processing time',
    COUNT(Script_Name) AS 'Number of executions',
    Processed_devices
FROM Log_Job
LEFT JOIN LastExecution ON CONCAT(Log_Job.Script_name, '.ps1') = LastExecution.Name
Where [Start_time] > @StartDate AND [End_time] < @EndDate
GROUP BY Script_name, Processed_devices, LastExecution.[Type]
ORDER BY Script_name, Processed_devices
