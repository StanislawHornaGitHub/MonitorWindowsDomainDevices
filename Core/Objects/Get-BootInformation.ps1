<#
    .DESCRIPTION
    Script to get Boot details
#>
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script

New-Variable -Name "REMOTE_CONNECTION_TIMEOUT_SECONDS" -Value 40 -Force -Scope Script -Option ReadOnly

function Invoke-Main {
    $InputHash = @{
        'Registry' = @{
            "FastStart" = @{
                "RegistryPath" = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
                "Property"     = @("HiberbootEnabled")
            }
        }
        'WMI' = @{
            'LastBootTime' = @{
                "CLASS_Name" = 'Win32_OperatingSystem'
                "Property"   = @("LastBootUpTime")
                "Filter"     = ""
            }
        }
    }
    $Credentials = Get-CredentialFromJenkins
    Get-BootInformationAsJob
    Get-BootInformationFromJob
}
function Get-BootInformationAsJob {
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
                $Output = @{
                    'Registry' = @{}
                    'WMI'      = @{}
                }
                # Rebuild structure from input hash
                foreach ($D in $InputHash.'Registry'.Keys) {
                    $Output.'Registry'.Add($D, @{})
                    foreach ($P in $InputHash.'Registry'.$D.Property) {
                        try {
                            $Output.'Registry'.$D.Add($P, (Get-Item -path $($InputHash.'Registry'.$D.RegistryPath)`
                                        -ErrorAction Stop`
                                ).GetValue($P))
                        }
                        catch {
                            throw $_.Exception.Message
                        }
                    }
                }
                foreach ($D in $InputHash.'WMI'.Keys) {
                    try {
                        $Output.'WMI'.Add($D, $(Get-WmiObject -Class $($InputHash.'WMI'.$D.CLASS_Name) `
                                    -Property $($InputHash.'WMI'.$D.Property) `
                                    -Filter $($InputHash.'WMI'.$D.Filter) `
                                    -ErrorAction Stop)
                        )
                    }
                    catch {
                        throw $_.Exception.Message
                    }
    
                }
                return $Output
            } -ArgumentList $InputHash
            return $Output
        } -ArgumentList $($C.DNSHostName), $Credentials, $InputHash | Out-Null
    }
}
function Get-BootInformationFromJob {
    $Timer = [System.Diagnostics.Stopwatch]::StartNew()
    $LastUpdate = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    while ($null -ne (Get-Job) -and ($Timer.ElapsedMilliseconds -le ($REMOTE_CONNECTION_TIMEOUT_SECONDS * 1000))) {
        $jobName = $null
        $jobName = (Get-Job | Where-Object { ($_.State -ne "Running") } | Select-Object -First 1).Name
        if ($null -ne $jobName) {
            Write-Host "Operations during timeout - $jobname"
            $Entry = [PSCustomObject]@{
                'DNSHostName'        = $jobName
                'FastStartEnabled' = $null
                'LastBootTime' = $null

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
                    $Entry.LastBootTime = $(Convert-WMIDateTime -DateTimeString $($Output.'WMI'.LastBootTime.LastBootUpTime))
                    $entry.FastStartEnabled = [bool]$($Output.'Registry'.'FastStart'."HiberbootEnabled")
                    
                    $Entry.'LastUpdate' = $LastUpdate
                }
            }
            $updateQuery = Get-SQLdataUpdateQuery -Entry $Entry -TableName "OperatingSystem"
            Invoke-SQLquery -Query $updateQuery -Credential $Credentials 
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