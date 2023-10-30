<#
.SYNOPSIS
    Script to get Power consumption and CPU, GPU Temperature

.DESCRIPTION
    Script is connecting to each device marked as active in SQL Inventory Table and retrieving information.
    For each device script is creating separate Powershell Background job responsible for collecting data.
    Results are captured and pushed to SQL TemperatureAndPower Table

    To collect such data Open Hardware Monitor is required which is providing such data to WMI.
    On each device Open Hardware Monitor is started to collect data and right after it is closed.

.INPUTS
    DEBUG - switch - If it is set than no data will be pushed to the SQL server,
                    everything will be displayed in the console.
                    Remember that even if this param is used the connection to the SQL Server is still required,
                    to get the list of currently active devices

.OUTPUTS
    Based on input DEBUG setting data is displayed in the console or pushed to the SQL Server

    Open Hardware Monitor has Min, Max and current value for each sensor.
    Due to the fact that some sensors are active faster the others those Min Max current values can be different.
        TimeStamp - Current time
        CPU_Temperature_Current
        CPU_Temperature_Min
        CPU_Temperature_Max
        GPU_Temperature_Current
        GPU_Temperature_Min
        GPU_Temperature_Max
        PowerConsumption_Current
        PowerConsumption_Min
        PowerConsumption_Max

.NOTES

    Version:            1.0
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      22-Aug-2023
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
New-Variable -Name "SCRIPT_NAME" -Value "Get-TemperatureAndPowerViaWMI.ps1" -Force -Scope Global -Option ReadOnly
New-Variable -Name "QUERY_TO_RUN_WITH_SCHEDULE" -Value "ActiveDevicesWithOpenHardwareMonitor.sql" -Force -Scope Global -Option ReadOnly
New-Variable -Name "QUERY_TO_RUN_OUTOF_SCHEDULE" -Value "RecentlyStarted_WithOpenHardwareMonitor.sql" -Force -Scope Global -Option ReadOnly

New-Variable -Name "TIMER" -Value $([System.Diagnostics.Stopwatch]::StartNew()) -Force -Scope Global

New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script
New-Variable -Name "SQL_TABLE_TO_UPDATE" -Value "Event_PowerAndTemperature" -Force -Scope Script -Option ReadOnly
New-Variable -Name "PROCESSED_DEVICES" -Value 0 -Force -Scope Script -Option ReadOnly

New-Variable -Name "REMOTE_CONNECTION_TIMEOUT_SECONDS" -Value 60 -Force -Scope Script -Option ReadOnly

function Invoke-Main {
    Write-Joblog
    try {
        Start-CollectingOHMDataAsJob
        Get-OpenHardwareMonitorFromJob
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
function Start-CollectingOHMDataAsJob {
    $Computer = Get-DevicesList -RunOutOfSchedule $RunOutOfSchedule `
        -QueryWithSchedule $QUERY_TO_RUN_WITH_SCHEDULE `
        -QueryOutOfSchedule $QUERY_TO_RUN_OUTOF_SCHEDULE
    foreach ($C in $Computer) {
        Start-Job -Name "$($C.DNSHostName)" -ScriptBlock {
            param(
                $ComputerName,
                $OPEN_HARDWARE_MONITOR_PATH,
                $OPEN_HARDWARE_MONITOR_EXE
            )
            # Collect data from WMI
            $Output = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                param(
                    $OPEN_HARDWARE_MONITOR_PATH,
                    $OPEN_HARDWARE_MONITOR_EXE
                )
                $Output = @{
                    'Temperature_CPU' = @{
                        'Current' = 0
                        'Minimum' = 0
                        'Maximum' = 0
                    }
                    'Temperature_GPU' = @{
                        'Current' = 0
                        'Minimum' = 0
                        'Maximum' = 0
                    }
                    'Power'           = @{
                        'Current' = 0
                        'Minimum' = 0
                        'Maximum' = 0
                    }
                }
                if (-not (Test-Path -Path $OPEN_HARDWARE_MONITOR_EXE)) {
                    return $null
                }
                if ($(Get-Process OpenHardwareMonitor -ErrorAction SilentlyContinue).count -gt 1) {
                    Get-Process OpenHardwareMonitor | Stop-Process -Force -Confirm:$false
                }
                if ($null -eq $(Get-Process OpenHardwareMonitor -ErrorAction SilentlyContinue)) {
                    Start-Process -FilePath $OPEN_HARDWARE_MONITOR_EXE -Verb RunAs
                }
                while ($Output.Power.Current -le 0 -or 
                    $Output.Power.Minimum -le 0 -or 
                    $Output.Power.Maximum -le 0 -or 
                    $Output.Temperature_CPU.Current -le 0 -or
                    $Output.Temperature_CPU.Minimum -le 0 -or
                    $Output.Temperature_CPU.Maximum -le 0 ) {

                    Start-Sleep -Seconds 1
                    $CPUtemp = Get-WmiObject -namespace "root/OpenHardwareMonitor" `
                        -Class Sensor `
                        -Property Name, SensorType, value, min, max, parent `
                        -Filter "SensorType = 'Temperature' AND Name like '%CPU%'"
                    $Output.Temperature_CPU.Current = $($CPUtemp.value | Measure-Object -Average).Average
                    $Output.Temperature_CPU.Minimum = $($CPUtemp.min | Measure-Object -Average).Average
                    $Output.Temperature_CPU.Maximum = $($CPUtemp.max | Measure-Object -Average).Average

                    $GPUtemp = Get-WmiObject -namespace "root/OpenHardwareMonitor" `
                        -Class Sensor `
                        -Property Name, SensorType, value, min, max, parent `
                        -Filter "SensorType = 'Temperature' AND Name like '%GPU%'"
                    $Output.Temperature_GPU.Current = $($GPUtemp.value | Measure-Object -Average).Average
                    $Output.Temperature_GPU.Minimum = $($GPUtemp.min | Measure-Object -Average).Average
                    $Output.Temperature_GPU.Maximum = $($GPUtemp.max | Measure-Object -Average).Average   

                    $Power = Get-WmiObject -namespace "root/OpenHardwareMonitor" `
                        -Class Sensor `
                        -Property Name, SensorType, value, min, max, parent `
                        -Filter "SensorType = 'Power' AND NOT Name like '%Core%'"
                    $Output.Power.Current = $($Power.value | Measure-Object -Sum).Sum
                    $Output.Power.Minimum = $($Power.min | Measure-Object -Sum).Sum
                    $Output.Power.Maximum = $($Power.max | Measure-Object -Sum).Sum
                }

                return $Output
            } -ArgumentList $OPEN_HARDWARE_MONITOR_PATH, $OPEN_HARDWARE_MONITOR_EXE
            return $Output
        } -ArgumentList $($C.DNSHostName), $OPEN_HARDWARE_MONITOR_PATH, $OPEN_HARDWARE_MONITOR_EXE | Out-Null
    }   
}
function Get-OpenHardwareMonitorFromJob {
    $Time = [System.Diagnostics.Stopwatch]::StartNew()
    $TimeStamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    while ($null -ne (Get-Job) -and ($Time.ElapsedMilliseconds -le ($REMOTE_CONNECTION_TIMEOUT_SECONDS * 1000))) {
        $jobName = Get-CompletedJobName
        if ($null -ne $jobName) {
            Write-Host "Operations during timeout - $jobname"
            $Entry = [PSCustomObject]@{
                'DNSHostName'              = $jobName
                'TimeStamp'                = $null
                'CPU_Temperature_Current'  = $null
                'CPU_Temperature_Min'      = $null
                'CPU_Temperature_Max'      = $null
                'GPU_Temperature_Current'  = $null
                'GPU_Temperature_Min'      = $null
                'GPU_Temperature_Max'      = $null
                'PowerConsumption_Current' = $null
                'PowerConsumption_Min'     = $null
                'PowerConsumption_Max'     = $null
            }
            try {
                $Output = $null
                $Output = Receive-Job -Name $jobName -ErrorAction Stop
            }
            catch {
                Write-Joblog -Message "$jobname;$($_.Exception.Message)"
                $Script:EXIT_CODE = 1 
            }
            $Entry.CPU_Temperature_Current = $Output.'Temperature_CPU'.Current
            $Entry.CPU_Temperature_Min = $Output.'Temperature_CPU'.Minimum
            $Entry.CPU_Temperature_Max = $Output.'Temperature_CPU'.Maximum
            $Entry.GPU_Temperature_Current = $Output.'Temperature_GPU'.Current
            $Entry.GPU_Temperature_Min = $Output.'Temperature_GPU'.Minimum
            $Entry.GPU_Temperature_Max = $Output.'Temperature_GPU'.Maximum
            $Entry.PowerConsumption_Current = $Output.'Power'.Current
            $Entry.PowerConsumption_Min = $Output.'Power'.Minimum
            $Entry.PowerConsumption_Max = $Output.'Power'.Maximum
            $Entry.TimeStamp = $TimeStamp
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