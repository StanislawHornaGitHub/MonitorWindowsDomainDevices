DECLARE @RecentlyStarted AS BIT = 0

UPDATE Inventory
SET RecentlyStarted = @RecentlyStarted