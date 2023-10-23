/*
    .DESCRIPTION
        Query to retrieve the time in miliseconds in which no scripts requires execution.

    .INPUTS
        None

    .OUTPUTS
        SleepTime - Number of miliseconds in which Process Coordinator can sleep

    .NOTES

        Version:            1.0
        Author:             Stanisław Horna
        Mail:               stanislawhorna@outlook.com
        GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
        Creation Date:      20-Oct-2023
        ChangeLog:

        Date            Who                     What

*/
SELECT 
    DATEDIFF(MS,GETDATE(),Next_Run) AS 'SleepTime'
FROM(
    SELECT TOP(1) 
        Name,
        [Type],
        Refresh_Interval_in_seconds,
        Last_Start_Time,
        DATEADD(ss,Refresh_Interval_in_seconds,Last_Start_Time) AS 'Next_Run'
    FROM LastExecution 
    ORDER BY Next_Run ASC
    ) Executions
