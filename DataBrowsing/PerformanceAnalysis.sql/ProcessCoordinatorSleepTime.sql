DECLARE @StartDate AS Date = '2023-09-12'
DECLARE @EndDate AS Date = '2023-09-13'

SELECT 
    AVG(CAST(SUBSTRING([Message], PATINDEX('%[0-9]%', [Message]), PATINDEX('%[0-9][^0-9]%', [Message] + 't') - PATINDEX('%[0-9]%', 
                    [Message]) + 1) as int)) AS 'Average Process Coordinator Sleep time [ms]'
FROM Log_Process_coordinator
WHERE Message_type = 'SLEEP' AND [Timestamp] > @StartDate AND [Timestamp] < @EndDate