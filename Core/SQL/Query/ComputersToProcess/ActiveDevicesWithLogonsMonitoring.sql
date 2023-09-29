DECLARE @DeviceIsActive AS BIT = 1
DECLARE @LogonsMonitoring AS BIT = 1

SELECT
    DNSHostName,
    IPaddress 
FROM Inventory
WHERE isActive = @DeviceIsActive AND
      MonitorLogons = @LogonsMonitoring