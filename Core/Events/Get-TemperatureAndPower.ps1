<#
    .DESCRIPTION
    Script to get Temperature
#>
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script


New-Variable -Name "REMOTE_CONNECTION_TIMEOUT_SECONDS" -Value 40 -Force -Scope Script -Option ReadOnly
New-Variable -Name "CREDENTIAL" -Value $(Get-CredentialFromJenkins) -Force -Scope Script -Option ReadOnly

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
                [PSCredential] $Credentials,
                $OPEN_HARDWARE_MONITOR_PATH
            )
            # Collect data from WMI
            $Output = Invoke-Command -ComputerName $ComputerName -Credential $Credentials -ScriptBlock {
                param(
                    $OPEN_HARDWARE_MONITOR_PATH
                )
                $Output = @{
                    'Temperature' = $null
                    'Power'       = $null
                }
                if (-not (Test-Path -Path "$OPEN_HARDWARE_MONITOR_PATH\OpenHardwareMonitorReport.exe")) {
                    return $null
                }
                $Report = & "$OPEN_HARDWARE_MONITOR_PATH\OpenHardwareMonitorReport.exe"
                # Filter out Temperature related information
                $Temperature = $Report | Where-Object { $_ -like "|  +- CPU Core #*:*(/*/?/temperature/*)" }
                # Calculate Average
                $Output.Temperature = $Temperature | ForEach-Object { $_.Split(":")[1].Trim().split(" ")[0] } | Measure-Object -Average -Maximum -Minimum
                # Filter out Power related information
                $PowerArray = @()
                $Power = $Report | Where-Object { $_ -like "|  +-*:*(/*/?/power/*)" }
                $Power = $Power | Where-Object { $_ -notlike "*Cores*" }
                $Power = $Power | ForEach-Object { $_.split(":")[1].split(" ") }
                for ($i = 0; $i -lt $Power.Count; $i++) {
                    if ($Power[$i] -like "(/*/?/power/*)") {
                        $PowerArray += $Power[($i - 1)]
                    }
                }
                # Calculate sum of consumed power
                $Output.Power = $PowerArray | Measure-Object -Sum
                
                return $Output
            } -ArgumentList $OPEN_HARDWARE_MONITOR_PATH
            return $Output
        } -ArgumentList $($C.DNSHostName), $CREDENTIAL, $OPEN_HARDWARE_MONITOR_PATH | Out-Null
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
                'DNSHostName'             = $jobName
                'TimeStamp'               = $null
                'CPU_Temperature_Average' = $null
                'CPU_Temperature_Min'     = $null
                'CPU_Temperature_Max'     = $null
                'PowerConsumption'        = $null
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
                        $Entry.CPU_Temperature_Average = $Output.'Temperature'.Average
                        $Entry.CPU_Temperature_Min = $Output.'Temperature'.Minimum
                        $Entry.CPU_Temperature_Max = $Output.'Temperature'.Maximum
                        $Entry.PowerConsumption = $Output.'Power'.Sum
                        $Entry.TimeStamp = $TimeStamp

                        $insertQuery = Get-SQLinsertSection -Entry $Entry -TableName "PowerAndTemperature"
                        Invoke-SQLquery -Query $insertQuery -Credential $CREDENTIAL
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