<#
    .DESCRIPTION
    Script to get OS properties, version, build, activation status
#>
param(
    [switch]$DEBUG
)
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "SCRIPT_NAME" -Value "Get-OSVersionInformation" -Force -Scope Global -Option ReadOnly
New-Variable -Name "TIMER" -Value $([System.Diagnostics.Stopwatch]::StartNew()) -Force -Scope Global

New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script
New-Variable -Name "SQL_TABLE_TO_UPDATE" -Value "OperatingSystem" -Force -Scope Script -Option ReadOnly

New-Variable -Name "REMOTE_CONNECTION_TIMEOUT_SECONDS" -Value 60 -Force -Scope Script -Option ReadOnly

New-Variable -Name 'INPUT_HASH' -Value @{
    'Registry' = @{
        "OS" = @{
            "RegistryPath" = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
            "Property"     = @('ReleaseID', 'DisplayVersion', 'UBR')
        }
    }
    'WMI'      = @{
        "OS"                = @{
            "CLASS_Name" = 'Win32_OperatingSystem'
            "Property"   = @("Caption", "Version", "OSArchitecture")
            "Filter"     = ""
        }
        "License"           = @{
            "CLASS_Name" = "SoftwareLicensingProduct"
            "Property"   = @("LicenseStatus", "PartialProductKey")
            "Filter"     = "Name like 'Windows%'"
        }
        "CurrentlyLoggedOn" = @{
            "CLASS_Name" = "Win32_process"
            "Property"   = "*"
            "Filter"     = "Name='explorer.exe' OR Name='cmd.exe'"
        }
    }
} -Force -Scope Script -Option ReadOnly

function Invoke-Main {
    Write-Joblog
    try {
        Get-OSVersionAsJob
        Get-WindowsVersionFromJob
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
function Get-OSVersionAsJob {
    $Computer = Get-ComputerListToProcess
    foreach ($C in $Computer) {
        Start-Job -Name "$($C.DNSHostName)" -ScriptBlock {
            param(
                $ComputerName,
                $InputHash
            )
            # Collect data from WMI
            $Output = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
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
                try {
                    $Output.'WMI'.'CurrentlyLoggedOn' = $Output.'WMI'.'CurrentlyLoggedOn'.GetOwner() | `
                        Select-Object Domain, User -Unique | `
                        Where-Object { $_.Domain -notlike "*NT*" }
                    $Output.'WMI'.'CurrentlyLoggedOn' = "$($Output.'WMI'.'CurrentlyLoggedOn'.Domain)\$($Output.'WMI'.'CurrentlyLoggedOn'.User)"
                }
                catch {
                    Write-Host $_
                    $Output.'WMI'.'CurrentlyLoggedOn' = "Nobody is currently logged in"
                }
                return $Output
            } -ArgumentList $InputHash
            return $Output
        } -ArgumentList $($C.DNSHostName), $INPUT_HASH | Out-Null
    }
}
function Get-WindowsVersionFromJob {
    $Time = [System.Diagnostics.Stopwatch]::StartNew()
    $LastUpdate = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    while ($null -ne (Get-Job) -and ($Time.ElapsedMilliseconds -le ($REMOTE_CONNECTION_TIMEOUT_SECONDS * 1000))) {
        $jobName = $null
        $jobName = (Get-Job | Where-Object { ($_.State -ne "Running") } | Select-Object -First 1).Name
        if ($null -ne $jobName) {
            Write-Host "Operations during timeout - $jobname"
            $Entry = [PSCustomObject]@{
                'DNSHostName'        = $jobName
                'LastUpdate'         = ""
                'CurrentlyLoggedOn'  = ""
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
                Write-Joblog -Message "$jobname - $($_.Exception.Message)"
                $Script:EXIT_CODE = 1 
            }
            finally {
                if ($success) {
                    $Entry.'CurrentlyLoggedOn' = $($Output.'WMI'.'CurrentlyLoggedOn')

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
            if ($DEBUG) {
                $Entry | Format-List
            }
            else {
                $updateQuery = Get-SQLdataUpdateQuery -Entry $Entry -TableName $SQL_TABLE_TO_UPDATE
                try {
                    Invoke-SQLquery -Query $updateQuery 
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