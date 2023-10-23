/*
    .DESCRIPTION
        Query to update table if data already exist otherwise insert a new row
        It is checking if the row with particular row identifier already exist:
            - If yes then row is updated
            - If no then new row is inserted
        Mostly use in scripts which are pushing object related properties to SQL DB.
        All INPUTS are replaced during query creation in PowerShell scripts.

    .INPUTS
        PRIMARY_KEY_VARIABLE - Column name which is used to identify particular row.
        TABLE_NAME_VARIABLE - Name of the table which is meant to be updated.
        COMPUTER_DNS_HOSTNAME_VARIABLE - Row identifier value.
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
        Creation Date:      16-Aug-2023
        ChangeLog:

        Date            Who                     What

*/
DECLARE @DNS_Host_Name AS NVARCHAR(500) = 'COMPUTER_DNS_HOSTNAME_VARIABLE'

IF EXISTS (SELECT PRIMARY_KEY_VARIABLE FROM TABLE_NAME_VARIABLE WHERE PRIMARY_KEY_VARIABLE = @DNS_Host_Name) 
BEGIN

    UPDATE_QUERY_BLOCK_VARIABLE

END
ELSE
BEGIN

    INSERT_QUERY_BLOCK_VARIABLE

END