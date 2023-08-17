<#
    .DESCRIPTION
    Script to get OS properties, version, build, activation status
#>
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script


New-Variable -Name "REMOTE_CONNECTION_TIMEOUT_SECONDS" -Value 40 -Force -Scope Script -Option ReadOnly
New-Variable -Name "CREDENTIAL" -Value $(Get-CredentialFromJenkins) -Force -Scope Script -Option ReadOnly
New-Variable -Name 'INPUT_HASH' -Value @{
    'Registry' = @{
        "OS" = @{
            "RegistryPath" = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
            "Property"     = @('ReleaseID', 'DisplayVersion', 'UBR')
        }
    }
    'WMI'      = @{
        "OS"      = @{
            "CLASS_Name" = 'Win32_OperatingSystem'
            "Property"   = @("Caption", "Version", "OSArchitecture")
            "Filter"     = ""
        }
        "License" = @{
            "CLASS_Name" = "SoftwareLicensingProduct"
            "Property"   = @("LicenseStatus", "PartialProductKey")
            "Filter"     = "Name like 'Windows%'"
        }
    }
} -Force -Scope Script -Option ReadOnly

function Invoke-Main {
    try {
        Get-OSVersionAsJob
        Get-WindowsVersionFromJob
    }
    catch {
        Write-Error -Message $_.Exception.Message
        $EXIT_CODE = 1
    }
    finally {
        exit $EXIT_CODE
    }
}
function Get-OSVersionAsJob {
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
        } -ArgumentList $($C.DNSHostName), $CREDENTIAL, $INPUT_HASH | Out-Null
    }
}
function Get-WindowsVersionFromJob {
    $Timer = [System.Diagnostics.Stopwatch]::StartNew()
    $LastUpdate = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    while ($null -ne (Get-Job) -and ($Timer.ElapsedMilliseconds -le ($REMOTE_CONNECTION_TIMEOUT_SECONDS * 1000))) {
        $jobName = $null
        $jobName = (Get-Job | Where-Object { ($_.State -ne "Running") } | Select-Object -First 1).Name
        if ($null -ne $jobName) {
            Write-Host "Operations during timeout - $jobname"
            $Entry = [PSCustomObject]@{
                'DNSHostName'        = $jobName
                'LastUpdate'         = ""
                'OS_Version'         = ""
                'OS_Display_Version' = ""
                'OS_build'           = ""
                'OS_Architecture'    = ""
                'isLicenseActivated' = $false
                'Error'              = ""
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
                    $Entry.'OS_Version' = $Output.'WMI'.OS.Caption
                    $Entry.'OS_build' = "$($Output.'WMI'.OS.Version).$($Output.'Registry'.OS.UBR)"
                    $Entry.'OS_Architecture' = $($Output.'WMI'.OS.OSArchitecture).Substring(0, 6)
                    $Entry.'isLicenseActivated' = `
                        [bool](($Output.'WMI'.License | Where-Object { $_.PartialProductKey }).LicenseStatus)
                    
                    if ($Output.'Registry'.OS.DisplayVersion.length -ge 4) {
                        $Entry.'OS_Display_Version' = $Output.'Registry'.OS.DisplayVersion
                    }
                    else {
                        $Entry.'OS_Display_Version' = $Output.'Registry'.OS.ReleaseID
                    }

                    $Entry.'LastUpdate' = $LastUpdate
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

Invoke-Main