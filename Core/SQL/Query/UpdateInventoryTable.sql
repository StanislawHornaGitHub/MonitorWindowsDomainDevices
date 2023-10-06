/*
    .DESCRIPTION
        Query to update inventory table.
        It is checking if the row with particular DNSHostName already exist:
            - If yes then row is updated:
                Additionally query is checking if isActive status is changed from 0 to 1
                and the time difference between LastSeen date and current one.
                    * if both conditions are true than additional column (RecentlyStarted) is set to true
                    * if conditions are not met than existing fields are overwritten with new values
            - If no then new row is inserted
        Query is used in "Get-DeviceInventoryToMonitor.ps1" only.
        All INPUTS are replaced during query creation in PowerShell scripts.

    .INPUTS
        PRIMARY_KEY_VARIABLE - Column name which is used to identify particular row.
        TABLE_NAME_VARIABLE - Name of the table which is meant to be updated.
        COMPUTER_DNS_HOSTNAME_VARIABLE - Row identifier value.
        #Temp_TABLE_TEMPORARY_NAME_VARIABLE - Name of the temporary table used during this query execution only.
        COLUMNS_TO_COMPARE_DURING_UPDATE_VARIABLE - Names of columns which are taken under the consideration during comparison
        UPDATE_QUERY_BLOCK_VARIABLE - Standard update query block,
            which is generated in PowerShell scripts using custom function "Get-SQLupdateSection",
            from SQL.psm1 module located under path: ./Core/SQL/Module/SQL.psm1.
            Format:
                UPDATE TABLE_NAME_VARIABLE
                SET ColumnName1 = 'Value1', ColumnName2 = 'Value2', ColumnName3 = 'Value3'
                WHERE PRIMARY_KEY_VARIABLE = 'COMPUTER_DNS_HOSTNAME_VARIABLE'
        INSERT_QUERY_BLOCK_VARIABLE - Standard insert query block,
            which is generated in PowerShell scripts using custom function "Get-SQLinsertSection", 
            from SQL.psm1 module located under path: ./Core/SQL/Module/SQL.psm1.
            Format:
                INSERT INTO TABLE_NAME_VARIABLE (ColumnName1, ColumnName2, ColumnName3)
                VALUES ('Value1', 'Value2', 'Value3')

    .OUTPUTS
        None

    .NOTES

        Version:            1.0
        Author:             Stanisław Horna
        Mail:               stanislawhorna@outlook.com
        GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
        Creation Date:      29-Aug-2023
        ChangeLog:

        Date            Who                     What

*/
DECLARE @isActive BIT
DECLARE @TimeDiffSeconds INT
DECLARE @NumberOfEntriesToReturn AS INT = 1
DECLARE @DNS_Host_Name AS NVARCHAR(50) = 'COMPUTER_DNS_HOSTNAME_VARIABLE'

IF EXISTS (SELECT PRIMARY_KEY_VARIABLE FROM TABLE_NAME_VARIABLE WHERE PRIMARY_KEY_VARIABLE = @DNS_Host_Name) 
BEGIN
    -- Copy currently saved data to temporary table
    SELECT TOP(@NumberOfEntriesToReturn) *
    INTO #Temp_TABLE_TEMPORARY_NAME_VARIABLE FROM TABLE_NAME_VARIABLE
    WHERE PRIMARY_KEY_VARIABLE = @DNS_Host_Name

    UPDATE_QUERY_BLOCK_VARIABLE

    -- Save new isActive status to variable
    SELECT @isActive = IsActive
    FROM TABLE_NAME_VARIABLE
    WHERE PRIMARY_KEY_VARIABLE = @DNS_Host_Name

    -- Calculate time difference in seconds between previous last seen date and current one
    SELECT @TimeDiffSeconds = DATEDIFF(SECOND, #Temp_TABLE_TEMPORARY_NAME_VARIABLE.LastSeen, TABLE_NAME_VARIABLE.LastSeen)
    FROM TABLE_NAME_VARIABLE
    LEFT JOIN  #Temp_TABLE_TEMPORARY_NAME_VARIABLE ON TABLE_NAME_VARIABLE.PRIMARY_KEY_VARIABLE = #Temp_TABLE_TEMPORARY_NAME_VARIABLE.PRIMARY_KEY_VARIABLE
    WHERE TABLE_NAME_VARIABLE.PRIMARY_KEY_VARIABLE = @DNS_Host_Name

    -- If number of entries is grater than IsActive value is different
    -- additionally check if current IsActive is set to 1 and
    -- time difference between LastSeen is grated than 150 seconds
    IF (
        SELECT 
            COUNT(*) 
        FROM (
            SELECT 
                DNSHostName, isActive
            FROM #Temp_TABLE_TEMPORARY_NAME_VARIABLE

        UNION

            SELECT 
                DNSHostName, isActive
            FROM TABLE_NAME_VARIABLE
            WHERE PRIMARY_KEY_VARIABLE = @DNS_Host_Name) a
        ) > 1 AND @isActive = 1 AND @TimeDiffSeconds > 150
    BEGIN

        -- Update RecentlyStarted column if all conditions are met
        UPDATE TABLE_NAME_VARIABLE
        SET RecentlyStarted = 1
        WHERE PRIMARY_KEY_VARIABLE = @DNS_Host_Name

    END

    DROP TABLE #Temp_TABLE_TEMPORARY_NAME_VARIABLE

END
ELSE
BEGIN

    INSERT_QUERY_BLOCK_VARIABLE

END