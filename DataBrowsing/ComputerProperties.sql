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