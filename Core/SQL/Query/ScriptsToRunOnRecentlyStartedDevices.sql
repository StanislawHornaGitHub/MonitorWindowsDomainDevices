DECLARE @SelectionThreshold AS INT 

SELECT TOP(1) 
    @SelectionThreshold = Refresh_Interval_in_seconds
FROM LastExecution 
WHERE NOT ([Type] = 'SyncData')
ORDER BY Refresh_Interval_in_seconds

SELECT
    Name,
    [Type],
    Remaining_Seconds_To_Next_Run
FROM
    (SELECT 
        Name,
        [Type],
        Refresh_Interval_in_seconds,
        Last_Start_Time,
        DATEADD(SECOND, Refresh_Interval_in_seconds, Last_Start_Time) AS 'Next_Run_Time',
        Datediff(SECOND, getdate(),  DATEADD(SECOND, Refresh_Interval_in_seconds, Last_Start_Time)) AS 'Remaining_Seconds_To_Next_Run',
        Last_Exit_Code,
        Errors
    FROM LastExecution
    WHERE NOT (Name = 'Get-DeviceInventoryToMonitor.ps1')
    ) Scripts
WHERE Remaining_Seconds_To_Next_Run > (@SelectionThreshold * 2)