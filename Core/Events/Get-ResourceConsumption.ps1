<#
    .DESCRIPTION
    Script to get Resource Consumption from WMI
#>
param(
    [switch]$DEBUG
)
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "SCRIPT_NAME" -Value "Get-ResourceConsumption" -Force -Scope Global -Option ReadOnly
New-Variable -Name "TIMER" -Value $([System.Diagnostics.Stopwatch]::StartNew()) -Force -Scope Global

New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script
New-Variable -Name "SQL_TABLE_TO_UPDATE" -Value "ResourceConsumption" -Force -Scope Script -Option ReadOnly

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
        Get-WMIDataAsJob -InputHash $INPUT_HASH
        Get-RecourceConsumption
    }
    catch {
        Write-Joblog -Message $_.Exception.Message
        $EXIT_CODE = 1
    }
    finally {
        Write-Joblog -Completed
        exit $EXIT_CODE
    }
}

function Get-RecourceConsumption {
    $Time = [System.Diagnostics.Stopwatch]::StartNew()
    while ($null -ne (Get-Job) -and ($Time.ElapsedMilliseconds -le ($REMOTE_CONNECTION_TIMEOUT_SECONDS * 1000))) {
        $jobName = $null
        $jobName = (Get-Job | Where-Object { $_.State -ne "Running" } | Select-Object -First 1).Name
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
            $success = $false
            try {
                $Output = Receive-Job -Name $jobName -ErrorAction Stop
                $success = $true
            }
            catch {
                Write-Joblog -Message "$jobname - $($_.Exception.Message)"
                $Script:EXIT_CODE = 1 
            }
            finally {
                if ($success) {
                    $Entry.CPU_Load_Percentage = ($Output.'CPU'.LoadPercentage | Measure-Object -Average).Average

                    $Entry.RAM_Usage_Percentage = ($($Output.'RAM'.TotalVisibleMemorySize) - $($Output.'RAM'.FreePhysicalMemory))
                    $Entry.RAM_Usage_Percentage /= $($Output.'RAM'.TotalVisibleMemorySize)
                    $Entry.RAM_Usage_Percentage *= 100

                    $Entry.Disk_Time_Percentage = (100 - ($Output.'Disk'.PercentIdleTime | Measure-Object -Average).Average)
                    $Entry.Disk_Read_MBps = $(($Output.'Disk'.DiskReadBytesPersec | Measure-Object -Average).Average / 1MB)
                    $Entry.Disk_Write_MBps = $(($Output.'Disk'.DiskWriteBytesPersec | Measure-Object -Average).Average / 1MB)

                    $Entry.NIC_Sent_Mbps = $((($Output.'NIC'.BytesSentPersec | Measure-Object -Average).Average / 1Mb) * 8)
                    $Entry.NIC_Received_MBps = $((($Output.'NIC'.BytesReceivedPersec | Measure-Object -Average).Average / 1Mb) * 8)
                }
            }
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
    $remainingJobs = Get-Job
    if ($null -ne $remainingJobs) {
        Get-Job | Remove-Job -Force
        Write-Joblog -Message "Background jobs were running longer than REMOTE_CONNECTION_TIMEOUT_SECONDS ($REMOTE_CONNECTION_TIMEOUT_SECONDS)"
    }
    
}

Invoke-Main
