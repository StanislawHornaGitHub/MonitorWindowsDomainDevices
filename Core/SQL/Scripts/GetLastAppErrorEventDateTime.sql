/*
    .DESCRIPTION
        Query to calculate to get last App Error datetime and updated dedicated column in Inventory table.
        This field is used for filtering purposes during collecting next App errors. 

    .INPUTS
        None

    .OUTPUTS
        None

    .NOTES

        Version:            1.0
        Author:             Stanisław Horna
        Mail:               stanislawhorna@outlook.com
        GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
        Creation Date:      05-Nov-2023
        ChangeLog:

        Date            Who                     What

*/

USE Device_Monitoring

UPDATE Inventory
SET LastEventTimeAppErrors = LastTimeCreated
FROM (
SELECT 
    MAX(TimeCreated) AS 'LastTimeCreated',
    DNSHostName
FROM Event_AppErrors
GROUP BY DNSHostName
) LastAppError
WHERE LastAppError.DNSHostName = Inventory.DNSHostName
