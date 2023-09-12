DECLARE @HardwareMonitorIsNotDeployed AS BIT = 0

Update Inventory
Set IsHardwareMonitorDeployed = @HardwareMonitorIsNotDeployed
WHERE DNSHostName IN (
    SELECT DNSHostName
    From Object_Hardware
    WHERE DeviceModel = 'Virtual Machine'
    )