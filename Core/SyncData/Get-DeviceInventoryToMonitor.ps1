<#
    .DESCRIPTION
    Script to get list of devices joined to AD with DNS names and IPs

#>
Import-Module "./Core/Import-AllModules.psm1"

New-Variable -Name "DNS_SERVER_NAME" -Value "pfsense" -Force -Scope Script -Option ReadOnly
New-Variable -Name "PING_TIMEOUT" -Value 500 -Force -Scope Script -Option ReadOnly
New-Variable -Name "TEST_PS_REMOTING_TIMEOUT" -Value 500 -Scope Script -Option ReadOnly


function Invoke-Main {
    $ExitCode = 0
    try {
        $Credentials = Get-CredentialFromJenkins
        $Computer = Get-ComputerList
        $Result = New-Object System.Collections.ArrayList
        Get-ComputerIsActive
        Get-AvailableDevices
        Export-Inventory
    }
    catch {
        Write-Error -Message $_.Exception.Message
        $ExitCode = 1
    }
    finally {
        exit $ExitCode
    }
}

function Get-ComputerList {
   
    try {
        # Get list of all devices joined to AD Domian
        $Computer = Get-ADComputer -Filter * -Credential $credentials -ErrorAction Stop   
        $Computer = $Computer | Where-Object {$_.DNSHostName -notin $DEVICES_RUNNING_OTHER_OS_THAN_WIN}
    }
    catch {
        throw $_.Exception.Message
    }
    finally {
        # Filter the list to get only enable accounts
        $Computer = $Computer | Where-Object { $_.Enabled -eq $true }
    }
    return $Computer
}

function Get-ComputerIsActive {
    # Get current date to refresh
    $LastUpdate = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    # Loop through the devices list
    foreach ($C in $Computer) {
        # Declare entry for the device
        $Entry = [PSCustomObject]@{
            'DNSHostName'   = ""
            'IPaddress'     = $null
            'isActiveWinRM' = $false
            'isActiveTCP'   = $false
            'isActive'      = $false
            'LastUpdate'    = $LastUpdate
            'LastSeen'      = ""
            'Error'         = ""
        }
        $Entry.DNSHostName = $C.DNSHostName
        try {
            # Get IP address of the device from defined server
            $Entry.IPAddress = $(Resolve-DnsName -Name $($C.DNSHostName) `
                    -Server $DNS_SERVER_NAME `
                    -Type A `
                    -NoHostsFile `
                    -ErrorAction Stop | Select-Object -First 1).IPAddress
        }
        catch {
            $Entry.Error += "$($_.Exception.Message) ; "
        }
        # If DNS server was able to resolve the name try to ping it
        if ($null -ne $($Entry.IPaddress)) {
            $ping = Invoke-Ping -IPaddress $($Entry.IPAddress) 
            $Entry.isActiveTCP = $ping.PingSucceded
            $Entry.Error += $Ping.Error
        }
        # If ping was successfull try to test PS Remoting
        if ($Entry.isActiveTCP -eq $true) {
            try {
                $Entry.isActiveWinRM = Test-PSRemotingServices -ComputerName $($C.DNSHostName) -ErrorAction Stop
            }
            catch {
                $Entry.Error += "$($_.Exception.Message) ; "
            }
        }
        # PS Remoting worked, ping worked - device is active
        if (($Entry.isActiveWinRM -eq $true)) {
            $Entry.LastSeen = $LastUpdate
            $Entry.isActive = $true
        }
        # Add device entry to the main loop
        $Result.Add($Entry) | Out-Null
    }    
}

function Get-AvailableDevices {
    # Get the devices which met all requirements to mark them as active
    $AvailableDevices = $Result | Where-Object { $_.isActive -eq $true } | Sort-Object -Property DNSHostName -Unique
    $AvailableDevices | Export-Csv -Path $AVAILABLE_DEVICES_TABLE -NoTypeInformation
}

function Invoke-Ping {
    param (
        $IPaddress
    )
    # Declare ping output
    $PingResult = @{
        "PingSucceded" = $false
        "Error"        = ""
    }
    # Ping the device with timeout to speed up proccessing
    $Ping = PING.EXE $IPaddress -n 1 -w $PING_TIMEOUT
    if ($Ping[2] -like "Reply from $IPadress*") {
        $PingResult.PingSucceded = $true
    }
    else {
        $PingResult.Error = "$($Ping[2]) ; "   
    }
    return $PingResult
}

function Test-PSRemotingServices {
    param (
        $ComputerName
    )
    try {
        # Invoke command remotely to verify if PS Remoting is active
        Invoke-Command -ComputerName $ComputerName -Credential $credentials -ScriptBlock {
            Get-Service -Name WinRM, RpcSs
        } -AsJob -JobName $ComputerName | Out-Null
    }
    catch {
        throw $_.Exception.Message
    }
    # Wait for PS Remoting response with timeout to speed up processing
    Wait-Job -Name $ComputerName -Timeout $TEST_PS_REMOTING_TIMEOUT | Out-Null
    try {
        # Collect the output
        $Rjob = Receive-Job -Name $ComputerName -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    Remove-Job -Name $ComputerName | Out-Null
    # Get services which are not running
    $notRunningServices = $Rjob | Where-Object { $_.Status -ne "Running" }
    # If all of them are running, PS Remoting is working 
    if ($null -eq $notRunningServices) {
        return $true
    }
    else {
        # List services with statuses and throw as an error
        $Message = ""
        foreach ($s in $notRunningServices) {
            $Message += "$($s.Name) $($s.Status) ; "
        }
        throw $Message
    }
    return $false
}

function Export-Inventory {
  
    # If the table does not exist there is nothing to compare
    if (-not $(Test-Path -Path $INVENTORY_TABLE)) {
        return
    }
    $old = Import-Csv -Path $INVENTORY_TABLE
    $old = Convert-CsvToHash -SourceTable $old -ColumnNameGroup "DNSHostName"
    # Loop through collected entries to lookup last seen date
    for ($i = 0; $i -lt $Result.Count; $i++) {
        $Hostname = $Result[$i].'DNSHostName'
        if (
            ($Result[$i].isActive -eq $false) `
                -and `
            ($old.ContainsKey($Hostname))
        ) {
            
            $Result[$i].'LastSeen' = $($old.$Hostname.'LastSeen')
        }
    }
    Remove-Item -Path $INVENTORY_TABLE -Force -Confirm:$false | Out-Null
    $Result | Export-Csv -Path $INVENTORY_TABLE -NoTypeInformation
}

Invoke-Main