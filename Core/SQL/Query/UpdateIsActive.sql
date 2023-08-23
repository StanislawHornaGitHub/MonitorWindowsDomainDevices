DECLARE @DeviceIsNotActive AS BIT = 0
DECLARE @DeviceDNSHostnameToUpdate AS NVARCHAR(50) = 'COMPUTER_DNS_HOSTNAME_VARIABLE'

UPDATE Inventory
SET isActive = @DeviceIsNotActive
WHERE DNSHostName = @DeviceDNSHostnameToUpdate