<#
    .DESCRIPTION
    Script to get Device specs, CPU, amout of RAM etc.
#>
Import-Module "./Core/Import-AllModules.psm1"

New-Variable -Name "CPU_CLASS" -Value "Win32_Processor" -Force -Scope Script -Option ReadOnly
New-Variable -Name "REMOTE_CONNECTION_TIMEOUT_SECONDS" -Value 60 -Force -Scope Script -Option ReadOnly
New-Variable -Name "DEVICE_PROPERTIES_TABLE" -Value "$ROOT_DIRECTORY/Object/Device_properties.csv" -Force -Scope Script -Option ReadOnly
function Invoke-Main {
    $Credentials = Get-CredentialFromJenkins
    $Computer = Get-ComputerListToProcess
    $Result = New-Object System.Collections.ArrayList
    Get-CPUDetails
    Export-ObjectTable -OutputTable $DEVICE_PROPERTIES_TABLE -Result $Result
}

function Get-CPUDetails {

    foreach ($C in $Computer) {
        
            $CPU = Invoke-Command -ComputerName $ComputerName -Credential $Credentials -ScriptBlock {
                param(
                    $ClassName
                )
                return $(Get-WmiObject -Class $ClassName -Property Name, NumberOfCores, NumberOfLogicalProcessors)
            } -ArgumentList $CPU_CLASS
            $Device = Invoke-Command -ComputerName $ComputerName -Credential $Credentials -ScriptBlock {
                return $(Get-ComputerInfo -Property CsManufacturer, CsModel)
            } 
            
            $Output = @{
                "CPU"    = $CPU
                "Device" = $Device
            }
    }
    $Timer = [System.Diagnostics.Stopwatch]::StartNew()
    $LastUpdate = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    while ($null -ne (Get-Job) -and ($Timer.ElapsedMilliseconds -le ($REMOTE_CONNECTION_TIMEOUT_SECONDS * 1000))) {
        $jobName = $null
        $jobName = (Get-Job | Where-Object { $_.State -ne "Running" } | Select-Object -First 1).Name
        if ($null -ne $jobName) {
            Write-Host "Operations during timeout - $jobname"
            $Entry = [pscustomobject] @{
                'DNSHostName'               = $jobName
                'DeviceManufacturer'        = ""
                'DeviceModel'               = ""
                'NumberOfCPUs'              = 0
                'CPUmodel'                  = ""
                'NumberOfCores'             = ""
                'NumberOfLogicalProcessors' = ""
                'LastUpdate'                = ""
                'Error'                     = ""
            }
            try {
                $job = Receive-Job -Name $jobName -ErrorAction Stop
                
                $Entry.'DeviceManufacturer' = $job.Device.CsManufacturer
                $Entry.'DeviceModel' = $job.Device.CsModel
                $Entry.'NumberOfCPUs' = ($job.CPU.Name).count
                if ($Entry.'NumberOfCPUs' -ge 2) {
                    $cpuModels = $job.CPU.Name[0]
                    for ($i = 1; $i -lt $job.CPU.Name.Count; $i++) {
                        $cpuModels += ";$($job.CPU.Name[$i])"
                    }
                    $Entry.'CPUmodel' = $cpuModels
                    $cores = 0
                    $threads = 0
                    $job.CPU.NumberOfCores | ForEach-Object { $cores += $_ }
                    $job.CPU.NumberOfLogicalProcessors | ForEach-Object { $threads += $_ }
                    $Entry.'NumberOfCores' = $cores
                    $Entry.'NumberOfLogicalProcessors' = $threads
                }
                else {
                    $Entry.'CPUmodel' = $job.CPU.Name
                    $Entry.'NumberOfCores' = $job.CPU.NumberOfCores
                    $Entry.'NumberOfLogicalProcessors' = $job.CPU.NumberOfLogicalProcessors
                }
                $Entry.'LastUpdate' = $LastUpdate
            }
            catch {
                $Entry.'Error' = $($_.Message.Exception)
            }   
            $Result.Add($Entry) | Out-Null
            Remove-Job -Name $jobName
        }
    }
    Get-Job -State Running
    Get-Job -State Running | Receive-Job
    Get-Job -State Running | Stop-Job
    foreach ($jobName in $(Get-Job).Name) {
        $Entry = [pscustomobject] @{
            'DNSHostName'               = $jobName
            'DeviceManufacturer'        = ""
            'DeviceModel'               = ""
            'NumberOfCPUs'              = 0
            'CPUmodel'                  = ""
            'NumberOfCores'             = ""
            'NumberOfLogicalProcessors' = ""
            'LastUpdate'                = ""
            'Error'                     = ""
        }
        try {
            $job = Receive-Job -Name $jobName -ErrorAction Stop
      
            $Entry.'DeviceManufacturer' = $job.Device.CsManufacturer
            $Entry.'DeviceModel' = $job.Device.CsModel
            $Entry.'NumberOfCPUs' = ($job.CPU.Name).count
            if ($Entry.'NumberOfCPUs' -ge 2) {
                $cpuModels = $job.CPU.Name[0]
                for ($i = 1; $i -lt $job.CPU.Name.Count; $i++) {
                    $cpuModels += ";$($job.CPU.Name[$i])"
                }
                $Entry.'CPUmodel' = $cpuModels
                $cores = 0
                $threads = 0
                $job.CPU.NumberOfCores | ForEach-Object { $cores += $_ }
                $job.CPU.NumberOfLogicalProcessors | ForEach-Object { $threads += $_ }
                $Entry.'NumberOfCores' = $cores
                $Entry.'NumberOfLogicalProcessors' = $threads
            }
            else {
                $Entry.'CPUmodel' = $job.CPU.Name
                $Entry.'NumberOfCores' = $job.CPU.NumberOfCores
                $Entry.'NumberOfLogicalProcessors' = $job.CPU.NumberOfLogicalProcessors
            }
            $Entry.'LastUpdate' = $LastUpdate
        }
        catch {
            $Entry.'Error' = $($_.Message.Exception)
        }   
        $Result.Add($Entry) | Out-Null
    }
    Get-Job | Remove-Job

    
}

Invoke-Main