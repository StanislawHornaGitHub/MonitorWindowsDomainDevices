SELECT
    DNSHostName,
    isActive,
    IsHardwareMonitorDeployed
FROM Inventory
WHERE 
    DNSHostName IN ('HP-Ryzen-7.Horna.local',
        'Lian6700.Horna.local',
    'Server-Core.Horna.local', 
    'Service-i7-3770.Horna.local', 
    'Server-IBM.Horna.local')