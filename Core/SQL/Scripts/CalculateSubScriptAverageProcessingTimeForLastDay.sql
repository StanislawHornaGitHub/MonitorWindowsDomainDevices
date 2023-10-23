/*
    .DESCRIPTION
        Query to calculate average processing time for each data retrieving script
        and fill in number of miliseconds to AVG_Processing_Duration_ms in LastExecution Table.
        Average is calculated based on similar time of the yesterday.

        It is Recommended to cover whole 24H. If @NumberOfHoursToAverage is set to 4, 
        than the script should be triggered 6 times a day (24 / 4 = 6)

        Get-RecentlyStartedDeviceDetails.ps1 is excluded as it is not run on a regular basis

    .INPUTS
        @NumberOfHoursToAverage - time range in hours based on which the average will be calculated

    .OUTPUTS
        None

    .NOTES

        Version:            1.0
        Author:             Stanisław Horna
        Mail:               stanislawhorna@outlook.com
        GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
        Creation Date:      23-Oct-2023
        ChangeLog:

        Date            Who                     What

*/
DECLARE @NumberOfHoursToAverage AS INT = 4
DECLARE @StartDate AS DATETIME2
DECLARE @EndDate AS DATETIME2 

USE Device_Monitoring_Maintenance

SET @EndDate = DATEADD(DAY, -1 ,GETDATE())
SET @StartDate = DATEADD(HOUR, (-1 * @NumberOfHoursToAverage), @EndDate)

UPDATE LastExecution
    SET LastExecution.AVG_Processing_Duration_ms = ProcessingDuration.AVG_Processing_Duration_ms
FROM (
    SELECT
        Script_name,
        AVG(DATEDIFF(MILLISECOND, 0, Duration)) AS 'AVG_Processing_Duration_ms'
    FROM Log_Job
    WHERE Start_time < @EndDate AND 
        Start_time > @StartDate AND
        Script_name != 'Get-RecentlyStartedDeviceDetails.ps1'
    GROUP BY Script_name
) ProcessingDuration
WHERE ProcessingDuration.Script_name = LastExecution.Name