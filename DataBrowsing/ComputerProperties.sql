SELECT 
    Inventory.DNSHostName AS 'Name',
    Inventory.IPaddress AS 'IP',
    Inventory.isActive AS 'Active',
    Inventory.LastSeen AS 'Last Seen',
    OperatingSystem.OS_Version AS 'OS',
    OperatingSystem.OS_Display_Version AS 'Version',
    OperatingSystem.LastBootType AS 'Boot type'
FROM Inventory
LEFT JOIN OperatingSystem on Inventory.DNSHostName = OperatingSystem.DNSHostName