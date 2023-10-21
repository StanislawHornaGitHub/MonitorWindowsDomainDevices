/*
    .DESCRIPTION
        Query to get details about last script execution.
        Commonly use in process coordinator main loop.

    .INPUTS
        None

    .OUTPUTS
        All columns of LastExecution Table.

    .NOTES

        Version:            1.1
        Author:             Stanisław Horna
        Mail:               stanislawhorna@outlook.com
        GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
        Creation Date:      28-Aug-2023
        ChangeLog:

        Date            Who                     What
        20-10-2023      Stanisław Horna         Next_Run Column added to the output

*/
SELECT 
    Name,
    [Type],
    Refresh_Interval_in_seconds,
    Last_Start_Time,
    DATEADD(ss,Refresh_Interval_in_seconds,Last_Start_Time) AS 'Next_Run'
FROM LastExecution