/*
    .DESCRIPTION
        Query to get details about last script execution.
        Commonly use in process coordinator main loop.

    .INPUTS
        None

    .OUTPUTS
        All columns from LastExecution Table, which are required for ProcessCoordinator operations

    .NOTES

        Version:            1.2
        Author:             Stanisław Horna
        Mail:               stanislawhorna@outlook.com
        GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
        Creation Date:      28-Aug-2023
        ChangeLog:

        Date            Who                     What
        20-10-2023      Stanisław Horna         Next_Run Column added to the output
        23-10-2023      Stanisław Horna         AVG_Processing_Duration_ms Column added

*/
SELECT 
    Name,
    [Type],
    Refresh_Interval_in_seconds,
    Last_Start_Time,
    AVG_Processing_Duration_ms,
    DATEADD(ss,Refresh_Interval_in_seconds,Last_Start_Time) AS 'Next_Run'
FROM LastExecution