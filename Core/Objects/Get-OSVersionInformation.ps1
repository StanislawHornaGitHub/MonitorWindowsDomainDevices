<#
    .DESCRIPTION
    Script to get OS properties, version, build, activation status
#>
Import-Module "./Core/Import-AllModules.psm1"


New-Variable -Name "OS_CLASS" -Value "Win32_OperatingSystem" -Force -Scope Script -Option ReadOnly
New-Variable -Name "LICENSE_CLASS" -Value "SoftwareLicensingProduct" -Force -Scope Script -Option ReadOnly
New-Variable -Name "DB_PATH" -Value "./DataBase" -Force -Scope Script -Option ReadOnly
New-Variable -Name "OS_VERSION_TABLE" -Value "$ROOT_DIRECTORY/Object/OS_version.csv" -Force -Scope Script -Option ReadOnly

function Invoke-Main {
    $ExitCode = 0
    try {
        $Credentials = Get-CredentialFromJenkins
        $Computer = Get-ComputerListToProcess
        $Result = New-Object System.Collections.ArrayList
        Get-WindowsVersion
        Export-ObjectTable -OutputTable $OS_VERSION_TABLE -Result $Result
    }
    catch {
        Write-Error -Message $_.Exception.Message
        $ExitCode = 1
    }
    finally{
        exit $ExitCode
    }
}


function Get-WindowsVersion {
    $LastUpdate = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    foreach ($C in $Computer) {
        $Entry = [PSCustomObject]@{
            'DNSHostName'        = $($C.DNSHostName)
            'OS Version'         = ""
            'OS build'           = ""
            'OS Architecture'    = ""
            'isLicenseActivated' = $false
            'LastUpdate'         = ""
            'Error'              = ""
        }
        $successOS = $false
        # OS Version Section
        try {
            $OS = Get-WmiObject -Class $OS_CLASS -ComputerName $($C.DNSHostName) -Credential $Credentials -ErrorAction Stop
            $successOS = $true
        } # Exception if current iteration is running on server responsible for monitoring itself
        catch [System.Management.ManagementException] {
            try {
                $OS = Get-WmiObject -Class $OS_CLASS -ComputerName $($C.DNSHostName) -ErrorAction Stop
                $successOS = $true
            }
            catch {
                $Entry.Error += $($_.exception.message)
            }
        }
        catch {
            $Entry.Error += $($_.exception.message)
        }
        finally {
            if ($successOS) {
                $Entry.'OS Version' = $OS.Caption
                $Entry.'OS build' = $OS.Version
                $Entry.'OS Architecture' = $($OS.OSArchitecture).Substring(0,6)
            }
        }
        $successLicense = $false
        # OS License Section
        try {
            $License = Get-WMIObject -Class $LICENSE_CLASS -ComputerName $($C.DNSHostName) -Credential $Credentials `
                -Filter "Name like 'Windows%'" -ErrorAction Stop | `
                Where-Object { $_.PartialProductKey }
            $successLicense = $true
        } # Exception if current iteration is running on server responsible for monitoring itself
        catch [System.Management.ManagementException] {
            try {
                $License = Get-WMIObject -Class $LICENSE_CLASS -ComputerName $($C.DNSHostName) `
                    -Filter "Name like 'Windows%'" -ErrorAction Stop | `
                    Where-Object { $_.PartialProductKey }
                $successLicense = $true
            }
            catch {
                $Entry.Error += $($_.exception.message)
            }
        }
        catch {
            $Entry.Error += $($_.exception.message)
        }
        finally {
            if ($successLicense) {
                # translate number to bool
                $Entry.'isLicenseActivated' = [bool]$($License.LicenseStatus)
            }
        }
        if ($successOS -and $successLicense) {
            $Entry.'LastUpdate' = $LastUpdate
        }
        $Result.Add($Entry) | Out-Null
    }
}

Invoke-Main