DECLARE @DeviceIsActive AS BIT = 1
DECLARE @RecentlyStarted AS BIT = 1

SELECT
    DNSHostName,
    isActive,
    IsHardwareMonitorDeployed
FROM Inventory
WHERE isActive=@DeviceIsActive AND 
      RecentlyStarted = @RecentlyStarted AND
      IsHardwareMonitorDeployed IS NULL
    