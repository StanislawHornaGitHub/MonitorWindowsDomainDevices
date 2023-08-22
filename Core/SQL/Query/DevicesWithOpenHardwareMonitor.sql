SELECT DNSHostName, IPaddress
FROM Inventory
WHERE IsHardwareMonitorDeployed = 1 AND isActive = 1