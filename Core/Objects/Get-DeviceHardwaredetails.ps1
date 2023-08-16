<#
    .DESCRIPTION
    Script to get Device specs, CPU, amout of RAM etc.
#>
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script

New-Variable -Name "REMOTE_CONNECTION_TIMEOUT_SECONDS" -Value 30 -Force -Scope Script -Option ReadOnly
New-Variable -Name "DEVICE_PROPERTIES_TABLE" -Value "$ROOT_DIRECTORY/Object/Device_Hardware_details.csv" -Force -Scope Script -Option ReadOnly
function Invoke-Main {
    $InputHash = @{
        "CPU"    = @{
            "CLASS_Name" = 'Win32_Processor'
            "Property"   = @("Name", "NumberOfCores", "NumberOfLogicalProcessors")
            "Filter"     = ""
        }
        "Device" = @{
            "CLASS_Name" = "Win32_ComputerSystem"
            "Property"   = @("Manufacturer", "Model")
            "Filter"     = ""
        }
        "RAM"    = @{
            "CLASS_Name" = "Win32_PhysicalMemory"
            "Property"   = @("Capacity", "ConfiguredClockSpeed", "Manufacturer")
            "Filter"     = ""
        }
        "Drive"  = @{
            "CLASS_Name" = "Win32_DiskDrive"
            "Property"   = @("Caption", "Size")
            "Filter"     = ""
        }
    }
    try {
        $Credentials = Get-CredentialFromJenkins
        Get-WMIDataAsJob -Credentials $Credentials -InputHash $InputHash
        $Result = New-Object System.Collections.ArrayList
        Get-DeviceDetails
        Export-ObjectTable -OutputTable $DEVICE_PROPERTIES_TABLE -Result $Result
    }
    catch {
        Write-Error -Message $_.Exception.Message
        $EXIT_CODE = 1
    }
    finally {
        exit $EXIT_CODE
    }
}

function Get-DeviceDetails {
    $Timer = [System.Diagnostics.Stopwatch]::StartNew()
    $LastUpdate = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    while ($null -ne (Get-Job) -and ($Timer.ElapsedMilliseconds -le ($REMOTE_CONNECTION_TIMEOUT_SECONDS * 1000))) {
        $jobName = $null
        $jobName = (Get-Job | Where-Object { $_.State -ne "Running" } | Select-Object -First 1).Name
        if ($null -ne $jobName) {
            Write-Host "Operations during timeout - $jobname"
            $Entry = [pscustomobject] @{
                'DNSHostName'               = $($jobName.split(";")[1])
                'LastUpdate'                = ""
                'DeviceManufacturer'        = ""
                'DeviceModel'               = ""
                'NumberOfCPUs'              = 0
                'CPUmodel'                  = ""
                'NumberOfCores'             = 0
                'NumberOfLogicalProcessors' = 0
                'NumberOfRAMBanks'          = 0
                'RAMCapacity_GB'          = 0
                'RAMSpeed_MHz'            = ""
                'RAMmanufacturer'           = ""
                'DiskName'                  = ""
                'StorageCapacity_GB'      = 0
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
                    $Entry = Get-DeviceModel -Entry $Entry -Output $Output
                    $Entry = Get-CPUdetails -Entry $Entry -Output $Output
                    $Entry = Get-RAMdetails -Entry $Entry -Output $Output
                    $Entry = Get-DiskDetails -Entry $Entry -Output $Output

                    $Entry.'LastUpdate' = $LastUpdate
                }
            }
            $updateQuery = Get-SQLdataUpdateQuery -Entry $Entry -TableName "DeviceHardwareDetails"
            Invoke-SQLquery -Query $updateQuery -Credential $Credentials   
            $Result.Add($Entry) | Out-Null
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

function Get-DeviceModel {
    param (
        $Entry,
        $Output
    )
    $Entry.'DeviceManufacturer' = $Output.Device.Manufacturer
    $Entry.'DeviceModel' = $Output.Device.Model
    return $Entry
}
function Get-CPUdetails {
    param (
        $Entry,
        $Output
    )
    $Entry.'NumberOfCPUs' = ($Output.CPU.Name).count
    if ($Entry.'NumberOfCPUs' -ge 2) {
        $cpuModels = $Output.CPU.Name[0]
        for ($i = 1; $i -lt $Output.CPU.Name.Count; $i++) {
            $cpuModels += ";$($Output.CPU.Name[$i])"
        }
        $Entry.'CPUmodel' = $cpuModels
        $cores = 0
        $threads = 0
        $Output.CPU.NumberOfCores | ForEach-Object { $cores += $_ }
        $Output.CPU.NumberOfLogicalProcessors | ForEach-Object { $threads += $_ }
        $Entry.'NumberOfCores' = $cores
        $Entry.'NumberOfLogicalProcessors' = $threads
    }
    else {
        $Entry.'CPUmodel' = $Output.CPU.Name
        $Entry.'NumberOfCores' = $Output.CPU.NumberOfCores
        $Entry.'NumberOfLogicalProcessors' = $Output.CPU.NumberOfLogicalProcessors
    }
    return $Entry
}

function Get-RAMdetails {
    param (
        $Entry,
        $Output
    )
    $Entry.'NumberOfRAMBanks' = ($Output.RAM).count
    if ($null -eq $Entry.'NumberOfRAMBanks') {
        $Entry.'NumberOfRAMBanks' = 1
    }
    $Output.RAM | ForEach-Object { $Entry.'RAMCapacity_GB' += ($_.Capacity / 1GB) }
    
    $RAMmanufacturers = $Output.RAM.Manufacturer | Sort-Object -Unique
    if ( $RAMmanufacturers.Count -eq 1) {
        $Entry.'RAMmanufacturer' = $RAMmanufacturers
    }
    else {
        $Entry.'RAMmanufacturer' = $RAMmanufacturers[0]
        for ($i = 1; $i -lt $RAMmanufacturers.Count; $i++) {
            $Entry.'RAMmanufacturer' += ";$($RAMmanufacturers[$i])"
        }
    }
    
    $RAMspeeds = $Output.RAM.ConfiguredClockSpeed | Sort-Object -Unique
    $Entry.'RAMSpeed_MHz' = [string]$RAMspeeds[0]
    for ($i = 1; $i -lt $RAMspeeds.Count; $i++) {
        $Entry.'RAMSpeed_MHz' += ";$($RAMspeeds[$i])"
    }
    return $Entry
}

function Get-DiskDetails {
    param (
        $Entry,
        $Output
    )
    $Entry.'DiskName' = $Output.Drive[0].Caption
    for ($i = 1; $i -lt ($Output.Drive).Count; $i++) {
        $Entry.'DiskName' += ";$($Output.Drive[0].Caption)"
    }
    $Output.Drive | ForEach-Object { $Entry.'StorageCapacity_GB' += ($_.Size / 1GB) }
    $Entry.'StorageCapacity_GB' = [math]::Round($($Entry.'StorageCapacity_GB'), 0)
    return $Entry
}

Invoke-Main