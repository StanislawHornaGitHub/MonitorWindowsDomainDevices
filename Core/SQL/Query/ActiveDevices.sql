DECLARE @DeviceIsActive AS BIT = 1

SELECT
    DNSHostName,
    IPaddress 
FROM Inventory
WHERE isActive = @DeviceIsActive