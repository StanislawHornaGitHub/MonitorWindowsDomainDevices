DECLARE @Hyper_V_monitoring AS BIT = 1

UPDATE Inventory
SET [MonitorHyper_V] = @Hyper_V_monitoring
WHERE DNSHostName in (
    SELECT DNSHostName 
    FROM Object_Hardware
    WHERE NOT (DeviceModel = 'Virtual Machine')
    )