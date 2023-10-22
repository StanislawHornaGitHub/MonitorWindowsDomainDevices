/*
    .DESCRIPTION
        Query to get PID of process coordinator,
        to check if there is no instance already running.

    .INPUTS
        @InstanceLockMessageType - Message type of log information with instance lockup

    .OUTPUTS
        PID of last Process Coordinator instance.

    .NOTES

        Version:            1.0
        Author:             Stanisław Horna
        Mail:               stanislawhorna@outlook.com
        GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
        Creation Date:      22-Oct-2023
        ChangeLog:

        Date            Who                     What

*/
DECLARE @InstanceLockMessageType AS NVARCHAR(20) = 'InstanceLock'
SELECT TOP(1)
CAST(SUBSTRING([Message], PATINDEX('%[0-9]%', [Message]), PATINDEX('%[0-9][^0-9]%', [Message] + 't') - PATINDEX('%[0-9]%', 
                    [Message]) + 1) as int) AS 'PID'
FROM Log_Process_coordinator WHERE Message_type = @InstanceLockMessageType ORDER BY [Timestamp] DESC