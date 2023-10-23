/*
    .DESCRIPTION
        Query to get list of scripts which should be run on Recently started Devices.
        It is checking the lowest value of scripts refresh interval,
        in next step query is selecting all scripts,
        which will not be triggered during doubled minimum refresh interval.
        Excluding scripts which are meant to be run in the nearest future is done to reduce resource consumption.

    .INPUTS
        None

    .OUTPUTS
        Name - Name of the script
        Type - Type of the script [Object/Event]
        Remaining_Seconds_To_Next_Run - time to the next script run

    .NOTES

        Version:            1.1
        Author:             Stanisław Horna
        Mail:               stanislawhorna@outlook.com
        GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
        Creation Date:      29-Sep-2023
        ChangeLog:

        Date            Who                     What
        23-10-2023      Stanisław Horna         SQL scripts Excluded from Recently started.

*/
DECLARE @SelectionThreshold AS INT 

-- Select lowest value of Refresh_Interval_in_seconds and assign it to @SelectionThreshold variable
-- Exclude all scripts within SyncData type
    SELECT TOP(1) 
        @SelectionThreshold = Refresh_Interval_in_seconds
    FROM LastExecution 
    WHERE [Type] NOT IN (
        'SyncData',
        'SQL'
        )
    ORDER BY Refresh_Interval_in_seconds

-- Select required columns for final result
    SELECT
        Name,
        [Type],
        Remaining_Seconds_To_Next_Run
    FROM
    -- Select columns for the final result and calculate corresponding values:
    --      - datetime of the next run
    --      - remaining seconds to the next run
        (SELECT 
            Name,
            [Type],
            Refresh_Interval_in_seconds,
            Last_Start_Time,
            DATEADD(SECOND, Refresh_Interval_in_seconds, Last_Start_Time) AS 'Next_Run_Time',
            Datediff(SECOND, getdate(),  DATEADD(SECOND, Refresh_Interval_in_seconds, Last_Start_Time)) AS 'Remaining_Seconds_To_Next_Run'
        FROM LastExecution
    -- Exclude all scripts within SyncData type
        WHERE [Type] NOT IN (
        'SyncData',
        'SQL'
        )) Scripts
-- Condition to return only scripts which are not meant to be run within condition mentioned in DESCRIPTION
    WHERE Remaining_Seconds_To_Next_Run > (@SelectionThreshold * 2)