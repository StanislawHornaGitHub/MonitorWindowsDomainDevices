
New-Variable -Name "CPU_CLASS" -Value "win32_processor" -Force -Scope Script -Option ReadOnly
New-Variable -Name "OS_CLASS" -Value "win32_operatingsystem" -Force -Scope Script -Option ReadOnly

function Invoke-main {
    $Servers = @("Server-Automation", "Server-Core", "Hornas-DC")
    $Result = New-Object System.Collections.ArrayList
    # $pass = $env:jenkinspass | ConvertTo-SecureString -AsPlainText -Force
    # $Credentials = New-Object System.Management.Automation.PSCredential($env:jenkinsuser, $pass)
    $Credentials = & "./Get-ADUserFromJenkins.ps1"
    foreach ($S in $Servers) {
        $Entry = [PSCustomObject]@{
            'commonName'  = $S
            'nameDNS'     = ""
            'addressIP'   = ""
            'Status'      = ""
            'Model'       = ""
            'Cores'       = ""
            'loadCPU'     = ""
            'totalMemory' = 0
            'freeMemory'  = 0
            'usageRAM'    = 0
            'errors'      = ""
            'lastRefresh' = $(Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }

        try {
            Get-ServerName -Server $S -ErrorAction Stop
            Get-CPUConsumption -Server $S  -ErrorAction Stop
            Get-RAMConsumption -Server $S  -ErrorAction Stop
            $Result.Add($Entry) | Out-Null
        }
        catch {
            
        }
    }
    $Result | fl
}

function Get-CPUConsumption {
    param(
        $Server = "localhost"
    )
    $success = $false
    try {
        $cpu = Get-WmiObject $CPU_CLASS -ComputerName $Server -Credential $Credentials -ErrorAction Stop
        $success = $true
    }
    catch [System.Management.ManagementException] {
        $cpu = Get-WmiObject $CPU_CLASS -ComputerName $Server -ErrorAction Stop
        $success = $true
    }
    catch {
        $Entry.Status = $_.exception.message
    }
    finally {
        if ($success) {
            $Entry.Status = $cpu.Status
            $Entry.Model = $cpu.Name
            $Entry.Cores = $cpu.NumberOfEnabledCore
            $Entry.loadCPU = $cpu.LoadPercentage
        }
    }
}

function Get-RAMConsumption {
    param(
        $Server = "localhost"
    )
    $success = $false
    try {
        $ram = Get-WmiObject $OS_CLASS -ComputerName $Server -Credential $Credentials -ErrorAction Stop
        $success = $true
    }
    catch [System.Management.ManagementException] {
        $ram = Get-WmiObject $OS_CLASS -ComputerName $Server -ErrorAction Stop
        $success = $true
    }
    catch {
        $Entry.errors = $_.exception.message
    }
    finally {
        if ($success) {
            $Entry.totalMemory = $ram.TotalVisibleMemorySize
            $Entry.freeMemory = $ram.FreePhysicalMemory
            $Entry.usageRAM = ($Entry.totalMemory - $Entry.freeMemory)
            $Entry.usageRAM /= $Entry.totalMemory
            $Entry.usageRAM *= 100
            $Entry.usageRAM = [math]::Round($($Entry.usageRAM), 0)
        }
    }
}   

function Get-ServerName {
    param (
        $Server
    )
    try {
        $nslookup = Resolve-DnsName -Name $Server -NoHostsFile -Type A -ErrorAction Stop
        $Entry.nameDNS = $nslookup.Name
        $Entry.addressIP = $nslookup.IPAddress
    }
    catch {
        $Entry.errors = $_.exception.message
    }
    
}

Invoke-main