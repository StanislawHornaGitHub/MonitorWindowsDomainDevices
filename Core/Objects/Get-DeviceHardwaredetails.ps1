<#
    .DESCRIPTION
    Script to get Device specs, CPU, amout of RAM etc.
#>
param(
    [switch]$DEBUG
)
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "SCRIPT_NAME" -Value "Get-HardwareDetails" -Force -Scope Global -Option ReadOnly
New-Variable -Name "TIMER" -Value $([System.Diagnostics.Stopwatch]::StartNew()) -Force -Scope Global

New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script
New-Variable -Name "SQL_TABLE_TO_UPDATE" -Value "Hardware" -Force -Scope Script -Option ReadOnly

New-Variable -Name "REMOTE_CONNECTION_TIMEOUT_SECONDS" -Value 60 -Force -Scope Script -Option ReadOnly
New-Variable -Name 'INPUT_HASH' -Value @{
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
    "GPU"    = @{
        "CLASS_Name" = "Win32_VideoController"
        "Property"   = @("Caption")
        "Filter"     = ""
    }
} -Force -Scope Script -Option ReadOnly

function Invoke-Main {
    Write-Joblog
    try {
        Get-WMIDataAsJob -InputHash $INPUT_HASH
        Get-DeviceDetails
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

function Get-DeviceDetails {
    $Time = [System.Diagnostics.Stopwatch]::StartNew()
    $LastUpdate = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    while ($null -ne (Get-Job) -and ($Time.ElapsedMilliseconds -le ($REMOTE_CONNECTION_TIMEOUT_SECONDS * 1000))) {
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
                'RAMCapacity_GB'            = 0
                'RAMSpeed_MHz'              = ""
                'RAMmanufacturer'           = ""
                'GPU_Model'                 = ""
                'DiskName'                  = ""
                'StorageCapacity_GB'        = 0
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
                    $Entry = Get-DeviceModel -Entry $Entry -Output $Output
                    $Entry = Get-CPUdetails -Entry $Entry -Output $Output
                    $Entry = Get-RAMdetails -Entry $Entry -Output $Output
                    $Entry = Get-DiskDetails -Entry $Entry -Output $Output

                    $Entry.'GPU_Model' = $Output.GPU.Caption | Where-Object {$_ -notlike "*Remote Display*"}
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
    $Disks = $Output.Drive.Caption | Sort-Object -Unique
    if ($Disks.count -gt 1) {
        $Entry.'DiskName' = [string]$Disks[0]
        for ($i = 1; $i -lt $Disks.Count; $i++) {
            $Entry.'DiskName' += "`n$($Disks[$i])"
        }
    }
    else {
        $Entry.'DiskName' = $Disks
    }
    $Output.Drive | ForEach-Object { $Entry.'StorageCapacity_GB' += ($_.Size / 1GB) }
    $Entry.'StorageCapacity_GB' = [math]::Round($($Entry.'StorageCapacity_GB'), 0)
    return $Entry
}

Invoke-Main