DECLARE @isActive BIT

IF EXISTS (SELECT PRIMARY_KEY_VARIABLE FROM TABLE_NAME_VARIABLE WHERE PRIMARY_KEY_VARIABLE ='COMPUTER_DNS_HOSTNAME_VARIABLE') 
BEGIN

SELECT TOP(1) *
INTO #Temp_TABLE_TEMPORARY_NAME_VARIABLE FROM TABLE_NAME_VARIABLE
WHERE PRIMARY_KEY_VARIABLE ='COMPUTER_DNS_HOSTNAME_VARIABLE'

UPDATE_QUERY_BLOCK_VARIABLE

SELECT @isActive = IsActive
FROM TABLE_NAME_VARIABLE
WHERE PRIMARY_KEY_VARIABLE = 'COMPUTER_DNS_HOSTNAME_VARIABLE'

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
        WHERE PRIMARY_KEY_VARIABLE ='COMPUTER_DNS_HOSTNAME_VARIABLE') a
    ) > 1 AND @isActive = 1
BEGIN

UPDATE TABLE_NAME_VARIABLE
SET RecentlyStarted = 1
WHERE PRIMARY_KEY_VARIABLE ='COMPUTER_DNS_HOSTNAME_VARIABLE'

END

DROP TABLE #Temp_TABLE_TEMPORARY_NAME_VARIABLE

END
ELSE
BEGIN

INSERT_QUERY_BLOCK_VARIABLE

END