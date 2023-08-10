<#
    .DESCRIPTION
    Script to get list of devices joined to AD with DNS names and IPs

#>
Import-Module "./Core/Import-AllModules.psm1"

New-Variable -Name "DNS_SERVER_NAME" -Value "pfsense" -Force -Scope Script -Option ReadOnly
New-Variable -Name "PING_TIMEOUT" -Value 500 -Force -Scope Script -Option ReadOnly
New-Variable -Name "DB_PATH" -Value "./DataBase" -Force -Scope Script -Option ReadOnly
New-Variable -Name "INVENTORY_TABLE" -Value "$DB_PATH/Object/Inventory.csv" -Force -Scope Script -Option ReadOnly
New-Variable -Name "AVAILABLE_DEVICES_TABLE" -Value "$DB_PATH/Temp/AvailableDevices.csv" -Force -Scope Script -Option ReadOnly
function Invoke-Main {
    $ExitCode = 0
    try {
        $Credentials = Get-CredentialFromJenkins
        $Computer = Get-ComputerList
        $Result = New-Object System.Collections.ArrayList
        Get-ComputerIsActive
        Invoke-Compare
        Export-Table
        Get-AvailableDevices
    }
    catch {
        Write-Error -Message $_.Exception.Message
        $ExitCode = 1
    }finally{
        exit $ExitCode
    }
}

function Get-ComputerList {
    try {
        $Computer = Get-ADComputer -Filter * -Credential $credentials -ErrorAction Stop
        $Computer = $Computer | Where-Object { $_.Enabled -eq $true }
    }
    catch {
        throw $_.Exception.Message
    }
    return $Computer
}

function Get-ComputerIsActive {
    $LastUpdate = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    foreach ($C in $Computer) {
        $Entry = [PSCustomObject]@{
            'computerSID' = ""
            'DNSHostName' = ""
            'IPaddress'   = $null
            'isActive'    = $false
            'Error'       = ""
            'LastUpdate'  = $LastUpdate
            'LastSeen'    = ""
        }
        $Entry.computerSID = $C.SID
        $Entry.DNSHostName = $C.DNSHostName
        
        try {
            $Entry.IPAddress = $(Resolve-DnsName -Name $($C.DNSHostName) `
                    -Server $DNS_SERVER_NAME `
                    -Type A `
                    -NoHostsFile `
                    -ErrorAction Stop | Select-Object -First 1).IPAddress
        }
        catch {
            $Entry.Error += "$($_.Exception.Message)`n"
        }
        if ($null -ne $($Entry.IPaddress)) {
            $ping = Invoke-Ping -IPaddress $($Entry.IPAddress) 
            $Entry.isActive = $ping.PingSucceded
            $Entry.Error += $Ping.Error
        }
        if ($Entry.isActive -eq $true) {
            $Entry.LastSeen = $LastUpdate
        }
        $Result.Add($Entry) | Out-Null
    }    
}

function Invoke-Compare {
    if (-not $(Test-Path -Path $INVENTORY_TABLE)) {
        return
    }
    $old = Import-Csv -Path $INVENTORY_TABLE
    $old = Convert-CsvToHash -SourceTable $old -ColumnNameGroup "DNSHostName"
    for ($i = 0; $i -lt $Result.Count; $i++) {
        if ($Result[$i].isActive -eq $false) {
            $Hostname = $Result[$i].'DNSHostName'
            $Result[$i].'IPaddress' = $($old.$Hostname.'IPaddress')
            $Result[$i].'Error' = $($old.$Hostname.'Error')
            $Result[$i].'LastSeen' = $($old.$Hostname.'LastSeen')
        }
    }
    
}

function Export-Table {
    if ($(Test-Path -Path $INVENTORY_TABLE)) {
        Remove-Item -Path $INVENTORY_TABLE -Force -Confirm:$false | Out-Null
    }
    $Result | Export-Csv -Path $INVENTORY_TABLE -NoTypeInformation
}

function Get-AvailableDevices {
    $AvailableDevices = $Result | Where-Object {$_.isActive -eq $true}
    $AvailableDevices | Export-Csv -Path $AVAILABLE_DEVICES_TABLE -NoTypeInformation
}

function Invoke-Ping {
    param (
        $IPaddress
    )
    $PingResult = @{
        "PingSucceded" = $false
        "Error"        = ""
    }
    $Ping = PING.EXE $IPaddress -n 1 -w $PING_TIMEOUT
    if ($Ping[2] -like "Reply from $IPadress*") {
        $PingResult.PingSucceded = $true
    }
    else {
        $PingResult.Error = "$($Ping[2])`n"   
    }
    return $PingResult
}

Invoke-Main