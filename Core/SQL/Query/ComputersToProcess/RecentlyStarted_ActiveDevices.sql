DECLARE @DeviceIsActive AS BIT = 1
DECLARE @RecentlyStarted AS BIT = 1

SELECT * FROM Inventory
WHERE RecentlyStarted = @RecentlyStarted AND isActive = @DeviceIsActive