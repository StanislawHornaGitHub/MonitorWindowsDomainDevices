/*
    .DESCRIPTION
        Query to UPDATE Object_OperatingSystem table (LastBootType | LastBootTime),
        using information from Event_Boots.

    .INPUTS
        None

    .OUTPUTS
        Updated Object_OperatingSystem columns:
            - LastBootType
            - LastBootTime

    .NOTES

        Version:            1.0
        Author:             Stanisław Horna
        Mail:               stanislawhorna@outlook.com
        GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
        Creation Date:      09-Oct-2023
        ChangeLog:

        Date            Who                     What

*/
UPDATE Object_OperatingSystem 
    SET 
        Object_OperatingSystem.LastBootType = LastEvents.LastBootType,
        Object_OperatingSystem.LastBootTime = LastEvents.LastBootTime
FROM    (
            SELECT 
                Object_OperatingSystem.DNSHostName,
                BootEvents.Time,
                BootEvents.BootType
            FROM Object_OperatingSystem
            INNER Join (
                SELECT 
                    DNSHostname,
                    MAX([TimeStamp]) AS 'LastBootTime',
                    BootType AS 'LastBootType'
                FROM Event_Boots
                GROUP BY DNSHostname, BootType
            ) BootEvents
            ON Object_OperatingSystem.DNSHostName = BootEvents.DNSHostName
        ) LastEvents