/*
    .DESCRIPTION
        Query to exclude devices from Temperature and Power consumption monitoring.
        Exclusion is done by setting IsHardwareMonitorDeployed flag in Inventory table
        By default all Virtual Machines can be excluded, as they have no sensor available.

    .INPUTS
        None

    .OUTPUTS
        None

    .NOTES

        Version:            1.0
        Author:             Stanisław Horna
        Mail:               stanislawhorna@outlook.com
        GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
        Creation Date:      22-Aug-2023
        ChangeLog:

        Date            Who                     What

*/
DECLARE @HardwareMonitorIsNotDeployed AS BIT = 0

UPDATE Inventory
SET IsHardwareMonitorDeployed = @HardwareMonitorIsNotDeployed
WHERE DNSHostName IN (
    SELECT DNSHostName
    FROM Object_Hardware
    WHERE DeviceModel = 'Virtual Machine'
    )