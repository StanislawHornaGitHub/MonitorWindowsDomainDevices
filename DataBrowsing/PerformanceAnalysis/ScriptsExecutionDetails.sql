/*
    .DESCRIPTION
        Query to retrieve all data related to the script executions.
        Additionally query is calculating datetime when next execution will be triggered
        and the number of remaining seconds to the next execution.

    .INPUTS
        None

    .OUTPUTS
        Name - Script name
        Type - Script type [Objects/Events/SyncData]
        Refresh_Interval_in_seconds - script refresh interval configured in config.json
        Next_Run_Time - datetime of the next script trigger
        Remaining_Seconds_To_Next_Run - seconds to the next script run
        Last_Exit_Code - last exit code of the script
        Errors - errors occurred during script execution

    .NOTES

        Version:            1.0
        Author:             Stanisław Horna
        Mail:               stanislawhorna@outlook.com
        GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
        Creation Date:      21-Aug-2023
        ChangeLog:

        Date            Who                     What

*/
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