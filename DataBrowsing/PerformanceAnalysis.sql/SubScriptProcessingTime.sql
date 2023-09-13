DECLARE @StartDate AS Date = '2023-09-12'
DECLARE @EndDate AS Date = '2023-09-13'

SELECT
    LastExecution.[Type],
    CAST(CAST(AVG(CAST(CAST(Duration as datetime) as float)) as datetime) as time) AS 'Average Proccessing time',
    COUNT(Script_Name) AS 'Number of executions',
    AVG(Processed_devices) AS 'Average Number of processed devices'
FROM Log_Job
LEFT JOIN LastExecution ON CONCAT(Log_Job.Script_name, '.ps1') = LastExecution.Name
Where [Start_time] > @StartDate AND [End_time] < @EndDate
GROUP BY LastExecution.[Type]
ORDER BY LastExecution.[Type]

SELECT
    Script_Name,
    LastExecution.[Type],
    CAST(CAST(AVG(CAST(CAST(Duration as datetime) as float)) as datetime) as time) AS 'Average Proccessing time',
    COUNT(Script_Name) AS 'Number of executions',
    AVG(Processed_devices) AS 'Average Number of processed devices'
FROM Log_Job
LEFT JOIN LastExecution ON CONCAT(Log_Job.Script_name, '.ps1') = LastExecution.Name
Where [Start_time] > @StartDate AND [End_time] < @EndDate
GROUP BY Script_name, LastExecution.[Type]
ORDER BY LastExecution.[Type]

SELECT
    Script_Name,
    LastExecution.[Type],
    CAST(CAST(AVG(CAST(CAST(Duration as datetime) as float)) as datetime) as time) AS 'Average Proccessing time',
    COUNT(Script_Name) AS 'Number of executions',
    Processed_devices
FROM Log_Job
LEFT JOIN LastExecution ON CONCAT(Log_Job.Script_name, '.ps1') = LastExecution.Name
Where [Start_time] > @StartDate AND [End_time] < @EndDate
GROUP BY Script_name, Processed_devices, LastExecution.[Type]
ORDER BY Script_name, Processed_devices
