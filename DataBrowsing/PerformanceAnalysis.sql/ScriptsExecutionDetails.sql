SELECT 
    Name,
    [Type],
    Refresh_Interval_in_seconds,
    Last_Start_Time,
    DATEADD(SECOND, Refresh_Interval_in_seconds, Last_Start_Time) AS 'Next_Run_Time',
    Datediff(SECOND, getdate(),  DATEADD(SECOND, Refresh_Interval_in_seconds, Last_Start_Time)) AS 'Remaining_Seconds_To_Next_Run',
    Last_Exit_Code,
    Errors
FROM LastExecution