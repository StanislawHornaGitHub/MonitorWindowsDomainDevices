<#
.SYNOPSIS
    Module with functions to retrieve information from monitored devices.

.DESCRIPTION
    Module consists of functions used get necessary data required to start collecting info from devices
    and those which are starting separate background job for each device to collect data.

    It contain following functions:
        Get-ComputerListToProcess - used to get the list of devices for further processing
        Get-WMIDataAsJob - used to create bacground jobs to collect WMI data from devices.
        Get-RegistryDataAsJob - used to create bacground jobs to collect Registry data from devices.

.NOTES

    Version:            1.0
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      26-Aug-2023
    ChangeLog:

    Date            Who                     What

#>
function Get-ComputerListToProcess {
    <#
    .DESCRIPTION
    Function to get the list of devices which are active at the moment.

#>
    param(
        $PredefinedQuery = "ActiveDevices.sql"
    )
    if($PredefinedQuery.length -le 5){
        $PredefinedQuery = "ActiveDevices.sql"
    }
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
        $InputHash,
        $PredefinedQuery = "ActiveDevices.sql"
    )
    # Get List of Available devices
    $Computer = Get-ComputerListToProcess -PredefinedQuery $PredefinedQuery
    foreach ($C in $Computer) {
        # Start Separate job for each device
        Start-Job -Name "WMI;$($C.DNSHostName)" -ScriptBlock {
            param(
                $ComputerName,
                $InputHash
            )
            # Collect data from WMI
            $Output = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
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
        } -ArgumentList $($C.DNSHostName), $InputHash | Out-Null
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
        $InputHash
    )
    $Computer = Get-ComputerListToProcess
    foreach ($C in $Computer) {
        # Start Separate job for each device
        Start-Job -Name "REG;$($C.DNSHostName)" -ScriptBlock {
            param(
                $ComputerName,
                $InputHash
            )
            # Collect data from WMI
            $Output = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
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
        } -ArgumentList $($C.DNSHostName), $InputHash | Out-Null
    }
}
function Convert-WMIDateTime {
    param (
        $DateTimeString
    )
    return $("$($DateTimeString.Substring(0,4))-$($DateTimeString.Substring(4,2))-$($DateTimeString.Substring(6,2)) $($DateTimeString.Substring(8,2)):$($DateTimeString.Substring(10,2)):$($DateTimeString.Substring(12,2))")
}
