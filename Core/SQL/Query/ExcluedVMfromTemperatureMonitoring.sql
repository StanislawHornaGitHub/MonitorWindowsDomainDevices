Update Inventory
Set IsHardwareMonitorDeployed = 0
WHERE DNSHostName IN (
    SELECT DNSHostName
    From Hardware
    WHERE DeviceModel = 'Virtual Machine'
    )