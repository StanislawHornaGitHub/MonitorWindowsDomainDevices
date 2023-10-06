/*
    .DESCRIPTION
        Query to retrieve basic computer properties.

    .INPUTS
        None

    .OUTPUTS
        Name - DNS Hostname
        IP - IPv4 address
        Active - Active [True/False]
        Last Seen - Last seen datetime
        OS - Operating System type and version (e.g. Windows Server 2022, Windows 11 Pro)
        Version - Operating System patch version (e.g. 21H2, 22H2)
        Boot type - Last boot type [Normal boot/Fast start/Wakeup from Hibernation]

    .NOTES

        Version:            1.0
        Author:             Stanisław Horna
        Mail:               stanislawhorna@outlook.com
        GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
        Creation Date:      19-Aug-2023
        ChangeLog:

        Date            Who                     What

*/
SELECT 
    Inventory.DNSHostName AS 'Name',
    Inventory.IPaddress AS 'IP',
    Inventory.isActive AS 'Active',
    Inventory.LastSeen AS 'Last Seen',
    Object_OperatingSystem.OS_Version AS 'OS',
    Object_OperatingSystem.OS_Display_Version AS 'Version',
    Object_OperatingSystem.LastBootType AS 'Boot type'
FROM Inventory
LEFT JOIN Object_OperatingSystem on Inventory.DNSHostName = Object_OperatingSystem.DNSHostName