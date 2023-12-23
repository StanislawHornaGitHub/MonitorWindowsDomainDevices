/*
    .DESCRIPTION
        Query to calculate to get last App Error datetime and updated dedicated column in Inventory table.
        This field is used for filtering purposes during collecting next App errors. 

    .INPUTS
        None

    .OUTPUTS
        None

    .NOTES

        Version:            1.1
        Author:             Stanisław Horna
        Mail:               stanislawhorna@outlook.com
        GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
        Creation Date:      05-Nov-2023
        ChangeLog:

        Date            Who                     What
        23-12-2023      Stanisław Horna         Last Logon Event DateTime update added
*/

USE Device_Monitoring

-- Last App Error DateTime update
UPDATE Inventory
SET LastEventTimeAppErrors = LastTimeErrorEventCreated
FROM (
SELECT 
    MAX(TimeCreated) AS 'LastTimeErrorEventCreated',
    DNSHostName
FROM Event_AppErrors
GROUP BY DNSHostName
) LastAppError
WHERE LastAppError.DNSHostName = Inventory.DNSHostName

-- Last Logon DateTime update
UPDATE Inventory
SET LastEventTimeLogon = LastTimeLogonEventCreated
FROM (
SELECT 
    MAX([TimeStamp]) AS 'LastTimeLogonEventCreated',
    DNSHostName
FROM Event_Logons
GROUP BY DNSHostName
) LastLogon
WHERE LastLogon.DNSHostName = Inventory.DNSHostName