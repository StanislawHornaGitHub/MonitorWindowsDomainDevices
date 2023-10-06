/*
    .DESCRIPTION
        Query to Calculate average Process Coordinator sleep time,
        Average is calculated based on logs collected within time frame,
        which is configured in INPUTS variables.

        Logs with message type SLEEP have following format schemes:
            - Start Sleep XXXX miliseconds
            - Script trigger Shift invoked for XXXX miliseconds
        Before calculating the average the number of milliseconds needs to be extracted from Message,
            which is done using SUBSTRING and PATINDEX functions.
            Next extracted value is converted to datatype INT using function CAST.
            Last the function AVG is used to calculate the average.

    .INPUTS
        @StartDate
        @EndDate

        To have an average for particular day, set:
            StartDate for the date from which you would like to get the average
            EndDate - StartDate + 1
        E.g. @StartDate = '2023-09-12', @EndDate = '2023-09-13',
        in such case all logs collected on 2023-09-12 will be included in average.

    .OUTPUTS
        Average Process Coordinator Sleep time [ms] - Average sleep time in milliseconds

    .NOTES

        Version:            1.0
        Author:             Stanisław Horna
        Mail:               stanislawhorna@outlook.com
        GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
        Creation Date:      13-Sep-2023
        ChangeLog:

        Date            Who                     What

*/
DECLARE @StartDate AS Date = '2023-09-12'
DECLARE @EndDate AS Date = '2023-09-13'

SELECT 
    AVG(CAST(SUBSTRING([Message], PATINDEX('%[0-9]%', [Message]), PATINDEX('%[0-9][^0-9]%', [Message] + 't') - PATINDEX('%[0-9]%', 
                    [Message]) + 1) as int)) AS 'Average Process Coordinator Sleep time [ms]'
FROM Log_Process_coordinator
WHERE Message_type = 'SLEEP' AND [Timestamp] > @StartDate AND [Timestamp] < @EndDate