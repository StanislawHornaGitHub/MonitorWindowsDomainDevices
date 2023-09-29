DECLARE @HardwareMonitorIstDeployed AS BIT = 1
DECLARE @DeviceIsActive AS BIT = 1
DECLARE @RecentlyStarted AS BIT = 1

SELECT DNSHostName, IPaddress
FROM Inventory
WHERE IsHardwareMonitorDeployed = @HardwareMonitorIstDeployed AND 
      isActive = @DeviceIsActive AND
      RecentlyStarted = @RecentlyStarted