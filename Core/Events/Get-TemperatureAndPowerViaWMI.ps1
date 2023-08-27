<#
    .DESCRIPTION
    Script to get Temperature
#>
param(
    [switch]$DEBUG
)
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script
New-Variable -Name "SQL_TABLE_TO_UPDATE" -Value "PowerAndTemperature" -Force -Scope Script -Option ReadOnly

New-Variable -Name "REMOTE_CONNECTION_TIMEOUT_SECONDS" -Value 60 -Force -Scope Script -Option ReadOnly

function Invoke-Main {
    try {
        Get-OpenHardwareMonitorAsJob
        Get-OpenHardwareMonitorFromJob
    }
    catch {
        Write-Error -Message $_.Exception.Message
        $EXIT_CODE = 1
    }
    finally {
        exit $EXIT_CODE
    }
}
function Get-OpenHardwareMonitorAsJob {
    $Computer = Get-ComputerListToProcess -PredefinedQuery "DevicesWithOpenHardwareMonitor.sql"
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
    $Timer = [System.Diagnostics.Stopwatch]::StartNew()
    $TimeStamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    while ($null -ne (Get-Job) -and ($Timer.ElapsedMilliseconds -le ($REMOTE_CONNECTION_TIMEOUT_SECONDS * 1000))) {
        $jobName = $null
        $jobName = (Get-Job | Where-Object { ($_.State -ne "Running") } | Select-Object -First 1).Name
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
            $success = $false
            try {
                $Output = Receive-Job -Name $jobName -ErrorAction Stop
                $success = $true
            }
            catch {
                Write-Host "$jobname - $($_.Exception.Message)"
                $Script:EXIT_CODE = 1 
            }
            finally {
                if ($success) {
                    if ($null -eq $Output) {
                        Write-Host "$jobname is null"
                    }
                    else {
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
                        Invoke-SQLquery -Query $insertQuery
                        }
                    }
                }
            }
            Remove-Job -Name $jobName
        }
    }
    $remainingJobs = Get-Job
    if ($null -ne $remainingJobs) {
        Get-Job | Remove-Job -Force
        $remainingJobs
        throw "Background jobs were running longer than REMOTE_CONNECTION_TIMEOUT_SECONDS ($REMOTE_CONNECTION_TIMEOUT_SECONDS)"
    }
}

Invoke-Main