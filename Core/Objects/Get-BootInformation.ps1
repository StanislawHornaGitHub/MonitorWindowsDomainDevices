<#
    .DESCRIPTION
    Script to get Boot details
#>
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script


New-Variable -Name "REMOTE_CONNECTION_TIMEOUT_SECONDS" -Value 60 -Force -Scope Script -Option ReadOnly
New-Variable -Name "CREDENTIAL" -Value $(Get-CredentialFromJenkins) -Force -Scope Script -Option ReadOnly
New-Variable -Name 'INPUT_HASH' -Value  @{
    'Registry' = @{
        "FastStart" = @{
            "RegistryPath" = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
            "Property"     = @("HiberbootEnabled")
        }
    }
    'WMI'      = @{
        'LastBootTime' = @{
            "CLASS_Name" = 'Win32_OperatingSystem'
            "Property"   = @("LastBootUpTime")
            "Filter"     = ""
        }
    }
} -Force -Scope Script -Option ReadOnly

function Invoke-Main {
    Get-BootInformationAsJob
    Get-BootInformationFromJob
}
function Get-BootInformationAsJob {
    $Computer = Get-ComputerListToProcess
    foreach ($C in $Computer) {
        Start-Job -Name "$($C.DNSHostName)" -ScriptBlock {
            param(
                $ComputerName,
                [PSCredential] $CREDENTIAL,
                $InputHash
            )
            # Collect data from WMI
            $Output = Invoke-Command -ComputerName $ComputerName -Credential $CREDENTIAL -ScriptBlock {
                param(
                    $InputHash
                )
                $Output = @{
                    'Registry'     = @{}
                    'WMI'          = @{}
                    'LastBootType' = ""
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
                $Output.'LastBootType' = (Get-WinEvent -ProviderName "Microsoft-Windows-Kernel-boot" `
                        -FilterXPath '*[System[EventID=27]]' `
                        -MaxEvents 1 ).Message
                return $Output
            } -ArgumentList $InputHash
            return $Output
        } -ArgumentList $($C.DNSHostName), $CREDENTIAL, $INPUT_HASH | Out-Null
    }
}
function Get-BootInformationFromJob {
    $Timer = [System.Diagnostics.Stopwatch]::StartNew()
    while ($null -ne (Get-Job) -and ($Timer.ElapsedMilliseconds -le ($REMOTE_CONNECTION_TIMEOUT_SECONDS * 1000))) {
        $jobName = $null
        $jobName = (Get-Job | Where-Object { ($_.State -ne "Running") } | Select-Object -First 1).Name
        if ($null -ne $jobName) {
            Write-Host "Operations during timeout - $jobname"
            $Entry = [PSCustomObject]@{
                'DNSHostName'      = $jobName
                'FastStartEnabled' = $null
                'LastBootTime'     = $null
                'LastBootType'     = $null

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
                    $Entry.FastStartEnabled = [bool]$($Output.'Registry'.'FastStart'."HiberbootEnabled")
                    $Entry.LastBootType = $(Get-BootTypeFromHex -MessageString $($Output.'LastBootType') )


                }
            }
            $updateQuery = Get-SQLdataUpdateQuery -Entry $Entry -TableName "OperatingSystem"
            Invoke-SQLquery -Query $updateQuery -Credential $CREDENTIAL 
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

function Get-BootTypeFromHex {
    param(
        $MessageString
    )
    if ($MessageString.Length -le 4) {
        return $null
    }
    $Hex = $MessageString.Substring($($MessageString.Length - 4), 3)
    switch ($Hex) {
        "0x0" {
            return "Normal boot"
        }
        "0x1" {
            return "Fast start"
        }
        "0x2" {
            return "Wakeup from Hibernation"
        }
    }
}


Invoke-Main