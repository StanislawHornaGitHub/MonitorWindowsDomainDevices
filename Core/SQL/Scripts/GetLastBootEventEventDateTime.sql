/*
    .DESCRIPTION
        Query to calculate to get last Boot Event datetime and updated dedicated column in Inventory table.
        This field is used for filtering purposes during collecting next Boot events. 

    .INPUTS
        None

    .OUTPUTS
        None

    .NOTES

        Version:            1.0
        Author:             Stanisław Horna
        Mail:               stanislawhorna@outlook.com
        GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
        Creation Date:      16-Nov-2023
        ChangeLog:

        Date            Who                     What

*/

USE Device_Monitoring

UPDATE Inventory
SET LastEventTimeBootEvents = LastTimeCreated
FROM (
SELECT 
    MAX([TimeStamp]) AS 'LastTimeCreated',
    DNSHostName
FROM Event_Boots
GROUP BY DNSHostName
) LastBootEvent
WHERE LastBootEvent.DNSHostName = Inventory.DNSHostName