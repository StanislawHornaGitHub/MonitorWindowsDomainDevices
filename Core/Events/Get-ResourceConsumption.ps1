<#
.SYNOPSIS
    Script to get Resource Consumption from WMI

.DESCRIPTION
    Script is connecting to each device marked as active in SQL Inventory Table and retrieving information.
    For each device script is creating separate Powershell Background job responsible for collecting data.
    Results are captured and pushed to SQL ResourceConsumption Table

.INPUTS
    DEBUG - switch - If it is set than no data will be pushed to the SQL server,
                    everything will be displayed in the console.
                    Remember that even if this param is used the connection to the SQL Server is still required,
                    to get the list of currently active devices

.OUTPUTS
    Based on input DEBUG setting data is displayed in the console or pushed to the SQL Server

        TimeStamp - Current time
        CPU_Load_Percentage - used processor time
        RAM_Usage_Percentag - used RAM memory
        Disk_Time_Percentage - Average of disk activity time
        Disk_Read_MBps - Average of Disk read speeds
        Disk_Write_MBps - Average of Disk write speeds
        NIC_Sent_Mbps - Average of data sent via Network Adapters
        NIC_Received_MBps - Average of data received via Network Adapters

.NOTES

    Version:            1.0
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      23-Aug-2023
    ChangeLog:

    Date            Who                     What
    29-09-2023      Stanisław Horna         Support for RunOutOfSchedule mechanizm added
    30-09-2023      Stanisław Horna         More accurate number of processed devices in Joblog
#>
param(
    [bool]$RunOutOfSchedule = $false,
    [switch]$DEBUG
)
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "SCRIPT_NAME" -Value "Get-ResourceConsumption.ps1" -Force -Scope Global -Option ReadOnly
New-Variable -Name "QUERY_TO_RUN_WITH_SCHEDULE" -Value "" -Force -Scope Global -Option ReadOnly
New-Variable -Name "QUERY_TO_RUN_OUTOF_SCHEDULE" -Value "RecentlyStarted_ActiveDevices.sql" -Force -Scope Global -Option ReadOnly
New-Variable -Name "TIMER" -Value $([System.Diagnostics.Stopwatch]::StartNew()) -Force -Scope Global

New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script
New-Variable -Name "SQL_TABLE_TO_UPDATE" -Value "Event_ResourceConsumption" -Force -Scope Script -Option ReadOnly
New-Variable -Name "PROCESSED_DEVICES" -Value 0 -Force -Scope Script -Option ReadOnly

New-Variable -Name "REMOTE_CONNECTION_TIMEOUT_SECONDS" -Value 40 -Force -Scope Script -Option ReadOnly
New-Variable -Name 'INPUT_HASH' -Value  @{
    "CPU"  = @{
        "CLASS_Name" = 'Win32_Processor'
        "Property"   = @("LoadPercentage")
        "Filter"     = ""
    }
    "RAM"  = @{
        "CLASS_Name" = 'Win32_OperatingSystem'
        "Property"   = @("TotalVisibleMemorySize", "FreePhysicalMemory")
        "Filter"     = ""
    }
    "Disk" = @{
        "CLASS_Name" = 'Win32_PerfFormattedData_PerfDisk_PhysicalDisk'
        "Property"   = @("PercentIdleTime", "DiskReadBytesPersec", "DiskWriteBytesPersec")
        "Filter"     = "Name = '_Total'"
    }
    "NIC"  = @{
        "CLASS_Name" = 'Win32_PerfFormattedData_Tcpip_NetworkInterface'
        "Property"   = @("BytesReceivedPersec", "BytesSentPersec")
        "Filter"     = ""
    }
} -Force -Scope Script -Option ReadOnly

function Invoke-Main {
    Write-Joblog
    try {
        Start-CollectingResourceConsumptionAsJob
        Get-RecourceConsumption
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
function Start-CollectingResourceConsumptionAsJob {
    if($RunOutOfSchedule -eq $true){
        Get-WMIDataAsJob -InputHash $INPUT_HASH -PredefinedQuery $QUERY_TO_RUN_OUTOF_SCHEDULE
    }else{
        Get-WMIDataAsJob -InputHash $INPUT_HASH
    }
}
function Get-RecourceConsumption {
    $Time = [System.Diagnostics.Stopwatch]::StartNew()
    while ($null -ne (Get-Job) -and ($Time.ElapsedMilliseconds -le ($REMOTE_CONNECTION_TIMEOUT_SECONDS * 1000))) {
        $jobName = Get-CompletedJobName
        if ($null -ne $jobName) {
            Write-Host "Operations during timeout - $jobname"
            $Entry = [pscustomobject] @{
                'DNSHostName'          = $($jobName.split(";")[1])
                'TimeStamp'            = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                'CPU_Load_Percentage'  = 0
                'RAM_Usage_Percentage' = 0
                'Disk_Time_Percentage' = 0
                'Disk_Read_MBps'       = 0
                'Disk_Write_MBps'      = 0
                'NIC_Sent_Mbps'        = 0
                'NIC_Received_MBps'    = 0

            }

            try {
                $Output = Receive-Job -Name $jobName -ErrorAction Stop
            }
            catch {
                Write-Joblog -Message "$jobname;$($_.Exception.Message)"
                $Script:EXIT_CODE = 1 
            }
            $Entry.CPU_Load_Percentage = ($Output.'CPU'.LoadPercentage | Measure-Object -Average).Average

                $Entry.RAM_Usage_Percentage = ($($Output.'RAM'.TotalVisibleMemorySize) - $($Output.'RAM'.FreePhysicalMemory))
                $Entry.RAM_Usage_Percentage /= $($Output.'RAM'.TotalVisibleMemorySize)
                $Entry.RAM_Usage_Percentage *= 100

                $Entry.Disk_Time_Percentage = (100 - ($Output.'Disk'.PercentIdleTime | Measure-Object -Average).Average)
                $Entry.Disk_Read_MBps = $(($Output.'Disk'.DiskReadBytesPersec | Measure-Object -Average).Average / 1MB)
                $Entry.Disk_Write_MBps = $(($Output.'Disk'.DiskWriteBytesPersec | Measure-Object -Average).Average / 1MB)

                $Entry.NIC_Sent_Mbps = $((($Output.'NIC'.BytesSentPersec | Measure-Object -Average).Average / 1Mb) * 8)
                $Entry.NIC_Received_MBps = $((($Output.'NIC'.BytesReceivedPersec | Measure-Object -Average).Average / 1Mb) * 8)
            if ($DEBUG) {
                $Entry | Format-List
            }
            else {
                $insertQuery = Get-SQLinsertSection -Entry $Entry -TableName $SQL_TABLE_TO_UPDATE
                try {
                    Invoke-SQLquery -Query $insertQuery 
                }
                catch {
                    Write-Joblog -Message $_
                }
            }
            Remove-Job -Name $jobName
        }
    }
    Remove-RemainingJobs
}

Invoke-Main
