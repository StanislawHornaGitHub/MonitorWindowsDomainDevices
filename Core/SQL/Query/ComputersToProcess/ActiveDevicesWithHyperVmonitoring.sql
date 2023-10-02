DECLARE @DeviceIsActive AS BIT = 1
DECLARE @HyperVmonitoring AS BIT = 1

SELECT
    DNSHostName,
    IPaddress 
FROM Inventory
WHERE isActive = @DeviceIsActive AND
      MonitorHyper_V = @HyperVmonitoring