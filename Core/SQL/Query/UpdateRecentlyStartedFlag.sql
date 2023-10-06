/*
    .DESCRIPTION
        Query to change RecentlyStarted column value to 0.
        Mostly used in "Get-RecentlyStartedDevicesDetails.ps1"

    .INPUTS
        COMPUTER_DNS_HOSTNAME_VARIABLE - Row identifier value.

    .OUTPUTS
        None

    .NOTES

        Version:            1.0
        Author:             Stanisław Horna
        Mail:               stanislawhorna@outlook.com
        GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
        Creation Date:      29-Sep-2023
        ChangeLog:

        Date            Who                     What

*/
DECLARE @RecentlyStarted AS BIT = 0

UPDATE Inventory
SET RecentlyStarted = @RecentlyStarted