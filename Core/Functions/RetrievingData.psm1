function Get-ComputerListToProcess {
    <#
    .DESCRIPTION
    Function to get the list of devices which are active at the moment.

#>
    param(
        $PredefinedQuery = "ActiveDevices.sql"
    )
    try {
        $Result = Invoke-SQLquery -FileQuery "$SQL_QUERIES_DIRECTORY/$PredefinedQuery"
    }
    catch {
        throw $_.Exception.Message
    }
    if ($null -eq $Result) {
        throw "There are no devices to process."
    }
    return $Result
}
function Get-WMIDataAsJob {
    <#
    .DESCRIPTION
    Function to Start jobs collecting Data from WMI
    
    .INPUTS
    $InputHash = @{
        "CPU" = @{
            "CLASS_Name" = 'Win32_Processor'
            "Property" = @("Name", "NumberOfCores", "NumberOfLogicalProcessors")
            "Filter" = ""
        }
        "Device" = @{
            "CLASS_Name" = "Win32_ComputerSystem"
            "Property" = @("Manufacturer", "Model")
            "Filter" = ""
        }
        "RAM" = @{
            "CLASS_Name" = "Win32_PhysicalMemory"
            "Property" = @("Capacity", "ConfiguredClockSpeed", "Manufacturer")
            "Filter" = ""
        }
    }
#>   
    param (
        [PSCredential] $Credentials,
        $InputHash
    )
    # Get List of Available devices
    $Computer = Get-ComputerListToProcess
    foreach ($C in $Computer) {
        # Start Separate job for each device
        Start-Job -Name "WMI;$($C.DNSHostName)" -ScriptBlock {
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
                $Output = @{}
                # Rebuild structure from input hash
            
                foreach ($D in $InputHash.Keys) {
                    try {
                        $Output.Add($D, $(Get-WmiObject -Class $($InputHash.$D.CLASS_Name) `
                                    -Property $($InputHash.$D.Property) `
                                    -Filter $($InputHash.$D.Filter) `
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
function Get-RegistryDataAsJob {
    <#
    .DESCRIPTION
    Function to Start jobs collecting Data from Registry
    
    .INPUTS
    $InputHashREG = @{
        "OS" = @{
            "RegistryPath" = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
            "Property" = @('ReleaseID','DisplayVersion')
        }
    }
#>   
    param (
        [PSCredential] $Credentials,
        $InputHash
    )
    $Computer = Get-ComputerListToProcess
    foreach ($C in $Computer) {
        # Start Separate job for each device
        Start-Job -Name "REG;$($C.DNSHostName)" -ScriptBlock {
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
                $Output = @{}
                # Rebuild structure from input hash
                foreach ($D in $InputHash.Keys) {
                    $Output.Add($D, @{})
                    foreach ($P in $InputHash.$D.Property) {
                        try {
                            $Output.$D.Add($P, (Get-Item -path $($InputHash.$D.RegistryPath)`
                                        -ErrorAction Stop`
                                ).GetValue($P))
                        }
                        catch {
                            throw $_.Exception.Message
                        }
                    }
                }
                return $Output
            } -ArgumentList $InputHash
            return $Output
        } -ArgumentList $($C.DNSHostName), $Credentials, $InputHash | Out-Null
    }
}
function Convert-WMIDateTime {
    param (
        $DateTimeString
    )
    return $("$($DateTimeString.Substring(0,4))-$($DateTimeString.Substring(4,2))-$($DateTimeString.Substring(6,2)) $($DateTimeString.Substring(8,2)):$($DateTimeString.Substring(10,2)):$($DateTimeString.Substring(12,2))")
}
