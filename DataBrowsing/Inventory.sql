/*
    .DESCRIPTION
        Query to retrieve all data stored in Inventory table,
        sorted by last seen from the newest to the oldest

    .INPUTS
        None

    .OUTPUTS
        All Inventory table columns

    .NOTES

        Version:            1.0
        Author:             Stanisław Horna
        Mail:               stanislawhorna@outlook.com
        GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
        Creation Date:      19-Aug-2023
        ChangeLog:

        Date            Who                     What

*/
SELECT *
FROM Inventory
ORDER BY LastSeen DESC