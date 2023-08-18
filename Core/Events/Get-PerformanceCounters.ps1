<#
    .DESCRIPTION
    Script to get Performance Counters
#>
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script


New-Variable -Name "REMOTE_CONNECTION_TIMEOUT_SECONDS" -Value 40 -Force -Scope Script -Option ReadOnly
New-Variable -Name "CREDENTIAL" -Value $(Get-CredentialFromJenkins) -Force -Scope Script -Option ReadOnly
New-Variable -Name 'INPUT_HASH' -Value @{
    "RegistryForCountereNames" = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Perflib\CurrentLanguage"
    "MonitoredCounters"        = @{
        "6"    = $null # % processor time
        "200"  = $null # % disk time
        "388"  = $null # NIC total bytes / sec
        "1406" = $null # % RAM usage
    }

} -Force -Scope Script -Option ReadOnly
function Invoke-Main {
    try {
        Get-PerformanceCountersAsJob
        Get-PerformanceCountersFromJob
    }
    catch {
        Write-Error -Message $_.Exception.Message
        $EXIT_CODE = 1
    }
    finally {
        exit $EXIT_CODE
    }
}

function Get-PerformanceCountersAsJob {
    $Computer = Get-ComputerListToProcess
    foreach ($C in $Computer) {
        Start-Job -Name "$($C.DNSHostName)" -ScriptBlock {
            param(
                $ComputerName,
                [PSCredential] $Credentials,
                $InputHash
            )
            # Collect data from WMI
            $Output = Invoke-Command -ComputerName $ComputerName -Credential $Credentials -ScriptBlock {
                param(
                    $InputHash
                )
                $MonitoredCounters = $InputHash."MonitoredCounters"
                # Rebuild structure from input hash
                $counter = (Get-ItemProperty -Path $($InputHash.'RegistryForCountereNames') -Name Counter).Counter
                $lastID = $MonitoredCounters.Keys | `
                    Sort-Object { [int]$_ } -Descending | `
                    Select-Object -First 1

                for ($i = 0; $i -lt $counter.Count; $i = $i + 2) {
                    $currentID = $($counter[$i])
                    if ($MonitoredCounters.ContainsKey($currentID)) {
                        $CounterName = $($counter[$i + 1])
                        $MonitoredCounters.$currentID = ((Get-Counter).countersamples | `
                                Where-Object { $_.Path -like "*$CounterName" }).CookedValue
                        if ($lastID -eq $($counter[$i])) {
                            break
                        }
                    }
                }
                return $MonitoredCounters
            } -ArgumentList $InputHash
            return $Output
        } -ArgumentList $($C.DNSHostName), $CREDENTIAL, $INPUT_HASH | Out-Null
    }
}
function Get-PerformanceCountersFromJob {
    $Timer = [System.Diagnostics.Stopwatch]::StartNew()
    $TimeStamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    while ($null -ne (Get-Job) -and ($Timer.ElapsedMilliseconds -le ($REMOTE_CONNECTION_TIMEOUT_SECONDS * 1000))) {
        $jobName = $null
        $jobName = (Get-Job | Where-Object { ($_.State -ne "Running") } | Select-Object -First 1).Name
        if ($null -ne $jobName) {
            Write-Host "Operations during timeout - $jobname"
            $Entry = [PSCustomObject]@{
                'DNSHostName'          = $jobName
                'TimeStamp'            = $null
                'CPU_time_Percentage'  = $null
                'RAM_usage_Percentage' = $null
                'Disk_time_Percentage' = $null
                'Network_Total_Mbps'   = $null
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
                    $Entry.CPU_time_Percentage = $Output.'6'
                    $Entry.RAM_usage_Percentage = $Output.'1406'
                    $Entry.Disk_time_Percentage = $( Get-DiskTimePercentage -ValueFromDevice $($Output.'200'))
                    $Entry.Network_Total_Mbps = $(Get-NetworkTotalMbps -ValueFromDevice $($Output.'388'))
                    $Entry.TimeStamp = $TimeStamp
                    $Entry
                    $insertQuery = Get-SQLinsertSection -Entry $Entry -TableName "PerformanceCounters"
                    Invoke-SQLquery -Query $insertQuery -Credential $CREDENTIAL
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
function Get-NetworkTotalMbps {
    param (
        $ValueFromDevice
    )
    $NetworkTraffic = 0
    $ValueFromDevice | ForEach-Object { $NetworkTraffic += $_ }
    $NetworkTraffic /= 1000000
    $NetworkTraffic *= 8
    $NetworkTraffic = [math]::Round($NetworkTraffic, 3)
    return $NetworkTraffic
}
function Get-DiskTimePercentage {
    param (
        $ValueFromDevice
    )
    if($ValueFromDevice -gt 100){
        return 100
    }else {
        return $ValueFromDevice
    }
}

Invoke-Main