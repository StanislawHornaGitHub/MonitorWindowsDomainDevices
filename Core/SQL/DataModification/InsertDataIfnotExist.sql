/*
    .DESCRIPTION
        Query to insert data that not exist.
        It is checking if the row with particular row identifier already exist:
            - If yes nothing happens
            - If no data is inserted
        Commonly used in cases where selected events from Windows Event Log are pushed to SQL DB.
        All INPUTS are replaced during query creation in PowerShell scripts.

    .INPUTS
        PRIMARY_KEY_VARIABLE - Column name which is used to identify particular row.
        TABLE_NAME_VARIABLE - Name of the table which is meant to be updated.
        ROW_ID_VALUE_TO_CHECK - Row identifier value.
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
        Creation Date:      12-Sep-2023
        ChangeLog:

        Date            Who                     What

*/
IF NOT EXISTS (SELECT PRIMARY_KEY_VARIABLE FROM TABLE_NAME_VARIABLE WHERE PRIMARY_KEY_VARIABLE ='ROW_ID_VALUE_TO_CHECK') 
BEGIN

INSERT_QUERY_BLOCK_VARIABLE

END