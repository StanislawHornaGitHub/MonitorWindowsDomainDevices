/*
    .DESCRIPTION
        Query to exclude devices from Hyper-V monitoring.
        Exclusion is done by setting MonitorHyper_V flag in Inventory table
        By default all Virtual Machines can be excluded.

    .INPUTS
        None

    .OUTPUTS
        None

    .NOTES

        Version:            1.1
        Author:             Stanisław Horna
        Mail:               stanislawhorna@outlook.com
        GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
        Creation Date:      2-Oct-2023
        ChangeLog:

        Date            Who                     What
        23-10-2023      Stanisław Horna         USE statement added to unify triggering mechanism in ProcessCoordinator
*/
DECLARE @Hyper_V_monitoring AS BIT = 1

USE Device_Monitoring

UPDATE Inventory
SET [MonitorHyper_V] = @Hyper_V_monitoring
WHERE DNSHostName in (
    SELECT DNSHostName 
    FROM Object_Hardware
    WHERE NOT (DeviceModel = 'Virtual Machine')
    )