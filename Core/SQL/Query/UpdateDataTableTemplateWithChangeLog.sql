/*
    .DESCRIPTION
        Improved version of UpdateDataTableTemplate.sql
        Query to update table if data already exist otherwise insert a new row
        It is checking if the row with particular row identifier already exist:
            - If yes then row is updated:
                Query is checking if any value is changed in comparison to data already saved:
                    * if yes then snapshot of old values set is inserted to separate table
                    * if no then no further actions are taken
            - If no then new row is inserted
        Mostly use in scripts which are pushing object related properties to SQL DB, 
        where change history log is required.
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
        Creation Date:      31-Aug-2023
        ChangeLog:

        Date            Who                     What

*/
DECLARE @NumberOfEntriesToReturn AS INT = 1
DECLARE @DNS_Host_Name AS NVARCHAR(200) = 'COMPUTER_DNS_HOSTNAME_VARIABLE'

IF EXISTS (SELECT PRIMARY_KEY_VARIABLE FROM TABLE_NAME_VARIABLE WHERE PRIMARY_KEY_VARIABLE = @DNS_Host_Name) 
BEGIN

    -- Copy currently saved data to temporary table
    SELECT TOP(@NumberOfEntriesToReturn) *
    INTO #Temp_TABLE_TEMPORARY_NAME_VARIABLE FROM TABLE_NAME_VARIABLE
    WHERE PRIMARY_KEY_VARIABLE = @DNS_Host_Name

    UPDATE_QUERY_BLOCK_VARIABLE

    -- If number of entries is grater than 1 than some values are different
    IF (
        SELECT 
            COUNT(*) 
        FROM (
            SELECT 
                COLUMNS_TO_COMPARE_DURING_UPDATE_VARIABLE
            FROM #Temp_TABLE_TEMPORARY_NAME_VARIABLE

        UNION

            SELECT 
                COLUMNS_TO_COMPARE_DURING_UPDATE_VARIABLE
            FROM TABLE_NAME_VARIABLE
            WHERE PRIMARY_KEY_VARIABLE = @DNS_Host_Name) a
        ) > 1
    BEGIN

        -- Add randomly generated ID to the previously stored data,
        -- next insert it to the ChangeLog table
        INSERT INTO ChangeLog_TABLE_NAME_VARIABLE
        SELECT NEWID() AS 'ID',
        *
        FROM #Temp_TABLE_TEMPORARY_NAME_VARIABLE

    END

    -- Delete temporary table
    DROP TABLE #Temp_TABLE_TEMPORARY_NAME_VARIABLE

END
ELSE
BEGIN

    INSERT_QUERY_BLOCK_VARIABLE

END