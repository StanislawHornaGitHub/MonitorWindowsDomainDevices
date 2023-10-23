/*
    .DESCRIPTION
        Query to get number of recently started devices.
        Based on this number decision is made if RecentlyStarted process will be invoked.

    .INPUTS
        None

    .OUTPUTS
        RecentlyActiveDevices - Number of devices which has connected to network recently

    .NOTES

        Version:            1.0
        Author:             Stanisław Horna
        Mail:               stanislawhorna@outlook.com
        GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
        Creation Date:      23-Oct-2023
        ChangeLog:

        Date            Who                     What

*/
DECLARE @DeviceIsActive AS BIT = 1
DECLARE @RecentlyStarted AS BIT = 1

SELECT
    COUNT(*) AS 'RecentlyActiveDevices'
FROM Inventory
WHERE isActive = @DeviceIsActive AND 
      RecentlyStarted = @RecentlyStarted