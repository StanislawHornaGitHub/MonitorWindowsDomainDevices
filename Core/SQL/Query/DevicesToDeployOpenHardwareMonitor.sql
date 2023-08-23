DECLARE @DeviceIsActive AS BIT = 1

SELECT
    DNSHostName,
    isActive,
    IsHardwareMonitorDeployed
FROM Inventory
WHERE 
    isActive=@DeviceIsActive AND IsHardwareMonitorDeployed IS NULL