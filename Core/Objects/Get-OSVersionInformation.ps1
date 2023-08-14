<#
    .DESCRIPTION
    Script to get OS properties, version, build, activation status
#>
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script


New-Variable -Name "REMOTE_CONNECTION_TIMEOUT_SECONDS" -Value 20 -Force -Scope Script -Option ReadOnly
New-Variable -Name "OS_VERSION_TABLE" -Value "$ROOT_DIRECTORY/Object/OS_version.csv" -Force -Scope Script -Option ReadOnly

function Invoke-Main {
    $InputHash = @{
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
    try {
        $Credentials = Get-CredentialFromJenkins
        Get-WMIDataAsJob -Credentials $Credentials -InputHash $InputHash
        $Result = New-Object System.Collections.ArrayList
        Get-WindowsVersion
        Export-ObjectTable -OutputTable $OS_VERSION_TABLE -Result $Result
    }
    catch {
        Write-Error -Message $_.Exception.Message
        $EXIT_CODE = 1
    }
    finally {
        exit $EXIT_CODE
    }
}


function Get-WindowsVersion {
    $Timer = [System.Diagnostics.Stopwatch]::StartNew()
    $LastUpdate = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    while ($null -ne (Get-Job) -and ($Timer.ElapsedMilliseconds -le ($REMOTE_CONNECTION_TIMEOUT_SECONDS * 1000))) {
        $jobName = $null
        $jobName = (Get-Job | Where-Object { $_.State -ne "Running" } | Select-Object -First 1).Name
        if ($null -ne $jobName) {
            Write-Host "Operations during timeout - $jobname"
            $Entry = [PSCustomObject]@{
                'DNSHostName'        = $jobName
                'LastUpdate'         = ""
                'OS Version'         = ""
                'OS build'           = ""
                'OS Architecture'    = ""
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
                    $Entry.'OS Version' = $Output.OS.Caption
                    $Entry.'OS build' = $Output.OS.Version
                    $Entry.'OS Architecture' = $($Output.OS.OSArchitecture).Substring(0, 6)
                    $Entry.'isLicenseActivated' = `
                        [bool](($Output.License | Where-Object { $_.PartialProductKey }).LicenseStatus)
                    $Entry.'LastUpdate' = $LastUpdate
                }
            }
            $Result.Add($Entry) | Out-Null
            Remove-Job -Name $jobName
        }
    }
    Get-Job -State Running
    Get-Job | Remove-Job
}

Invoke-Main