/*
    .DESCRIPTION
        Query to get details about last script execution.
        Commonly use in process coordinator main loop.

    .INPUTS
        None

    .OUTPUTS
        All columns of LastExecution Table.

    .NOTES

        Version:            1.0
        Author:             Stanisław Horna
        Mail:               stanislawhorna@outlook.com
        GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
        Creation Date:      28-Aug-2023
        ChangeLog:

        Date            Who                     What

*/
SELECT *
FROM LastExecution