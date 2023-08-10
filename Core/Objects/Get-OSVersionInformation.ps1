<#
    .DESCRIPTION
    Script to get OS properties, version, build, type.
#>
Import-Module "./Core/Import-AllModules.psm1"


New-Variable -Name "OS_CLASS" -Value "Win32_OperatingSystem" -Force -Scope Script -Option ReadOnly
New-Variable -Name "LICENSE_CLASS" -Value "SoftwareLicensingProduct" -Force -Scope Script -Option ReadOnly
New-Variable -Name "DB_PATH" -Value "./DataBase" -Force -Scope Script -Option ReadOnly
New-Variable -Name "OS_VERSION_TABLE" -Value "$DB_PATH/Object/OS_version.csv" -Force -Scope Script -Option ReadOnly

function Invoke-Main {
    $Credentials = Get-CredentialFromJenkins
    $Computer = Get-ComputerListToProcess
    $Result = New-Object System.Collections.ArrayList
    Get-WindowsVersion
    $Result | fl
    Export-Table
}


function Get-WindowsVersion {
    foreach ($C in $Computer) {
        $Entry = [PSCustomObject]@{
            'DNSHostName'        = $($C.DNSHostName)
            'OS Version'         = ""
            'OS build'           = ""
            'OS Architecture'    = ""
            'isLicenseActivated' = $false
            'Error'              = ""
        }
        $success = $false
        # OS Version Section
        try {
            $OS = Get-WmiObject -Class $OS_CLASS -ComputerName $($C.DNSHostName) -Credential $Credentials -ErrorAction Stop
            $success = $true
        }
        catch [System.Management.ManagementException] {
            try {
                $OS = Get-WmiObject -Class $OS_CLASS -ComputerName $($C.DNSHostName) -ErrorAction Stop
                $success = $true
            }
            catch {
                $Entry.Error += $($_.exception.message)
            }
        }
        catch {
            $Entry.Error += $($_.exception.message)
        }
        finally {
            if ($success) {
                $Entry.'OS Version' = $OS.Caption
                $Entry.'OS build' = $OS.Version
                $Entry.'OS Architecture' = $OS.OSArchitecture
            }
        }
        $success = $false
        # OS License Section
        try {
            $License = Get-WMIObject -Class $LICENSE_CLASS -ComputerName $($C.DNSHostName) -Credential $Credentials `
                -Filter "Name like 'Windows%'" -ErrorAction Stop | `
                Where-Object { $_.PartialProductKey }
                $success = $true
        }
        catch [System.Management.ManagementException] {
            try {
                $License = Get-WMIObject -Class $LICENSE_CLASS -ComputerName $($C.DNSHostName) `
                    -Filter "Name like 'Windows%'" -ErrorAction Stop | `
                    Where-Object { $_.PartialProductKey }
                    $success = $true
            }
            catch {
                $Entry.Error += $($_.exception.message)
            }
        }
        catch {
            $Entry.Error += $($_.exception.message)
        }
        finally {
            if ($success) {
                $Entry.'isLicenseActivated' = $License.LicenseStatus
            }
        }
        $Result.Add($Entry) | Out-Null
    }
}
function Export-Table {
    if ($(Test-Path -Path $OS_VERSION_TABLE)) {
        Remove-Item -Path $OS_VERSION_TABLE -Force -Confirm:$false | Out-Null
    }
    $Result | Export-Csv -Path $OS_VERSION_TABLE -NoTypeInformation
}

Invoke-Main