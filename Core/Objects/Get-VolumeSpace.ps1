<#
.SYNOPSIS
    Script to get volumes' spaces 

.DESCRIPTION
    Script is connecting to each device marked as active in SQL Inventory Table and retrieving information.
    For each device script is creating separate Powershell Background job responsible for collecting data.
    Results are captured and pushed to SQL Partitions Table

.INPUTS
    DEBUG - switch - If it is set than no data will be pushed to the SQL server,
                    everything will be displayed in the console.
                    Remember that even if this param is used the connection to the SQL Server is still required,
                    to get the list of currently active devices

.OUTPUTS
    Based on input DEBUG setting data is displayed in the console or pushed to the SQL Server

    PartitionLetter - Letter assigned to the partition
    Label - name of the partition
    FileSystem - partition file system
    DriveCapacity_GB - partition capacity in GBs
    DriveFreeSpace_GB - partition free space in GBs
    DriveUsed_Percentage - partition used capacity in percentage

.NOTES

    Version:            1.1
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      14-Aug-2023
    ChangeLog:

    Date            Who                     What
    10-09-2023      Stanisław Horna         Redesigned format of pushing data to SQL,
                                            each partition has own row in SQL Table
    11-09-2023      Stanisław Horna         Additional columns added:
                                                - Automount
                                                - BootVolume
                                                - Compressed
                                                - IndexingEnabled
                                                - PageFilePresent
                                                - QuotasEnabled
    29-09-2023      Stanisław Horna         Support for RunOutOfSchedule mechanizm added
    30-09-2023      Stanisław Horna         More accurate number of processed devices in Joblog
#>
param(
    [bool]$RunOutOfSchedule = $false,
    [switch]$DEBUG
)
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "SCRIPT_NAME" -Value "Get-VolumeSpace.ps1" -Force -Scope Global -Option ReadOnly
New-Variable -Name "QUERY_TO_RUN_OUTOF_SCHEDULE" -Value "RecentlyStarted_ActiveDevices.sql" -Force -Scope Global -Option ReadOnly
New-Variable -Name "TIMER" -Value $([System.Diagnostics.Stopwatch]::StartNew()) -Force -Scope Global

New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script
New-Variable -Name "SQL_TABLE_TO_UPDATE" -Value "Object_Partitions" -Force -Scope Script -Option ReadOnly


New-Variable -Name "REMOTE_CONNECTION_TIMEOUT_SECONDS" -Value 60 -Force -Scope Script -Option ReadOnly
New-Variable -Name 'INPUT_HASH' -Value  @{
    "Volumes" = @{
        "CLASS_Name" = "Win32_Volume"
        "Property"   = @("Caption", 
            "DriveLetter",    
            "FileSystem", 
            "Capacity", 
            "FreeSpace", 
            "Label",
            "Automount",
            "BootVolume",
            "Compressed",
            "IndexingEnabled",
            "PageFilePresent",
            "QuotasEnabled")
        "Filter"     = "Caption like '%:%' AND (FileSystem like 'NTFS' OR FileSystem like 'REFS')"
    }
} -Force -Scope Script -Option ReadOnly
function Invoke-Main {
    Write-Joblog
    try {
        Start-CollectingVolumeDataAsJob
        Get-VolumeDetails
    }
    catch {
        Write-Joblog -Message $_.Exception.Message
        $EXIT_CODE = 1
    }
    finally {
        Write-Joblog -Completed -ProcessedDevices $PROCESSED_DEVICES -EXIT_CODE $EXIT_CODE
        exit $EXIT_CODE
    }
}
function Start-CollectingVolumeDataAsJob {
    if($RunOutOfSchedule -eq $true){
        Get-WMIDataAsJob -InputHash $INPUT_HASH -PredefinedQuery $QUERY_TO_RUN_OUTOF_SCHEDULE
    }else{
        Get-WMIDataAsJob -InputHash $INPUT_HASH
    }
}
function Get-VolumeDetails {
    $Time = [System.Diagnostics.Stopwatch]::StartNew()
    $LastUpdate = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    while ($null -ne (Get-Job) -and ($Time.ElapsedMilliseconds -le ($REMOTE_CONNECTION_TIMEOUT_SECONDS * 1000))) {
        $jobName = Get-CompletedJobName
        if ($null -ne $jobName) {
            Write-Host "Operations during timeout - $jobname"
            try {
                $Output = Receive-Job -Name $jobName -ErrorAction Stop
            }
            catch {
                Write-Joblog -Message "$jobname - $($_.Exception.Message)"
                $Script:EXIT_CODE = 1 
            }
            foreach ($partition in $Output.Volumes) {
                $Entry = [pscustomobject] @{
                    'PartitionLetter'      = $($partition.Caption)
                    'DNSHostName'          = $($jobName.split(";")[1])
                    'Label'                = $($partition.Label)
                    'FileSystem'           = $($partition.FileSystem)
                    'DriveCapacity_GB'     = $($partition.Capacity / 1GB)
                    'DriveFreeSpace_GB'    = $($partition.FreeSpace / 1GB)
                    'DriveUsed_Percentage' = $((($partition.Capacity - $partition.FreeSpace) / $partition.Capacity) * 100)
                    'Automount'            = $partition.Automount
                    'BootVolume'           = $partition.BootVolume
                    'Compressed'           = $partition.Compressed
                    'IndexingEnabled'      = $partition.IndexingEnabled
                    'PageFilePresent'      = $partition.PageFilePresent
                    'QuotasEnabled'        = $partition.QuotasEnabled
                    'LastUpdate'           = $LastUpdate
                    'Row_ID'               = "$($jobName.split(";")[1])_$($partition.DriveLetter[0])"
                }
                if ($DEBUG) {
                    $Entry | Format-List
                }
                else {
                    $updateQuery = Get-SQLdataUpdateQuery -Entry $Entry  -TableName $SQL_TABLE_TO_UPDATE -sqlPrimaryKey "Row_ID"
                    try {
                        Invoke-SQLquery -Query $updateQuery 
                    }
                    catch {
                        Write-Error $_
                        $updateQuery
                    }
                }
            }
            Remove-Job -Name $jobName
        }
    }
    Remove-RemainingJobs
}

Invoke-Main