SELECT
    DNSHostName,
    isActive,
    IsHardwareMonitorDeployed
FROM Inventory
WHERE 
    isActive=1 AND 
    (IsHardwareMonitorDeployed IS NULL OR 
        IsHardwareMonitorDeployed=0)