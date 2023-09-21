<#
.SYNOPSIS
    Script to get list of devices

.DESCRIPTION
    Script to get list of devices joined to AD and their PS Remoting status,
    if they are ready to work with Monitor Windows Domain devices or not.
    Script is performing following steps for each device:
        1. Get IPv4 address from defined DNS Server
        2. Try to Ping it
        3. Test PS Remoting:
            - Test-WSMan
            - Get Service status of WinRM and RpcSs
        4. Push the result for Inventory table

.INPUTS
    DEBUG - switch - If it is set than no data will be pushed to the SQL server,
                    everything will be displayed in the console.

.OUTPUTS
    Based on input DEBUG setting data is displayed in the console or pushed to the SQL Server
            DNSHostName - DNSHostName stored in AD
            IPaddress - Adress received from DNS Served
            isActiveWinRM - Status of PS Remoting
            isActiveTCP - Status of ping
            isActive - Overall activeness status
            LastUpdate - Date when the record was updated for the last time
            LastSeen - Date when device was active for the last time
            Error - Any errors which were related to the particular device
        

.NOTES

    Version:            1.0
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      14-Aug-2023
    ChangeLog:

    Date            Who                     What
    21-09-2023      Stanisław Horna         Filtering out devices which are not running Windows OS

#>
Param(
    [switch]$DEBUG
)
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script
New-Variable -Name "SCRIPT_NAME" -Value "Get-DeviceHardwaredetails" -Force -Scope Global -Option ReadOnly
New-Variable -Name "TIMER" -Value $([System.Diagnostics.Stopwatch]::StartNew()) -Force -Scope Global

New-Variable -Name "DNS_SERVER_NAME" -Value "pfsense" -Force -Scope Script -Option ReadOnly
New-Variable -Name "PING_TIMEOUT" -Value 50 -Force -Scope Script -Option ReadOnly
New-Variable -Name "TEST_PS_REMOTING_TIMEOUT" -Value 10 -Scope Script -Option ReadOnly

function Invoke-Main {
    try {
        Write-Joblog
        Get-ComputerList
        Get-ComputerIsActive
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

function Get-ComputerList {
    try {
        # Get list of all Windows running devices joined to AD Domian
        $Computer = Get-ADComputer -filter * -Properties OperatingSystem -ErrorAction Stop | `
            Where-Object { $_.OperatingSystem -like "Windows*" } | `
            Select-Object DNSHostname, Enabled
        $Computer = $Computer | Where-Object { $_.DNSHostName -notin $DEVICES_TO_EXCLUDE_FROM_MONITORING }
    }
    catch {
        throw $_.Exception.Message
    }
    finally {
        # Filter the list to get only enable accounts
        $Computer = $Computer | Where-Object { $_.Enabled -eq $true }
    }
    $Script:Computer = $Computer
}

function Get-ComputerIsActive {
    # Get current date to refresh
    $LastUpdate = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    # Loop through the devices list
    foreach ($C in $Computer) {
        # Declare entry for the device
        $Entry = [PSCustomObject]@{
            'DNSHostName'   = $($C.DNSHostName)
            'IPaddress'     = $null
            'isActiveWinRM' = $false
            'isActiveTCP'   = $false
            'isActive'      = $false
            'LastUpdate'    = $LastUpdate
            'LastSeen'      = $null
            'Error'         = ""
        }
        # Get IP address of the device from defined server
        try {
            $Entry.IPAddress = $(Resolve-DnsName -Name $($Entry.DNSHostName) `
                    -Server $DNS_SERVER_NAME `
                    -Type A `
                    -NoHostsFile `
                    -ErrorAction Stop | Select-Object -First 1).IPAddress
        }
        catch {
            $Entry.Error += "$($_.Exception.Message)`n"
            Invoke-SQLUpdate -Entry $Entry 
            continue
        }
        # If DNS server was able to resolve the name try to ping it       
        try {
            $ping = Invoke-Ping -IPaddress $($Entry.IPAddress) 
            $Entry.isActiveTCP = $ping.PingSucceded
        }
        catch {
            $Entry.Error += "$_`n"
            Invoke-SQLUpdate -Entry $Entry 
            continue
        }
        # If ping was successfull try to test PS Remoting
        try {
            $Entry.isActiveWinRM = Test-PSRemotingServices -ComputerName $($Entry.DNSHostName) -ErrorAction Stop
        }
        catch {
            $Entry.Error += "$($_.Exception.Message)`n"
            Invoke-SQLUpdate -Entry $Entry 
            continue
        }
        
        $Entry.LastSeen = $LastUpdate
        $Entry.isActive = $true
        Invoke-SQLUpdate -Entry $Entry 
    }    
}
function Invoke-SQLUpdate {
    param (
        $Entry
    )
    if ($DEBUG) {
        $Entry | Format-List
    }
    else {
        $updateQuery = Get-SQLdataUpdateQuery -Entry $Entry -TableName "Inventory"
        Invoke-SQLquery -Query $updateQuery
    }
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
        throw "$($Ping[2])" 
        $PingResult.Error = "$($Ping[2]) ; "   
    }
    return $PingResult
}

function Test-PSRemotingServices {
    param (
        $ComputerName
    )
    try {
        (Test-WSMan -ComputerName $ComputerName -ErrorAction Stop) | Out-Null
    }   
    catch {
        throw $_.Exception.Message
    }
    try {
        # Invoke command remotely to verify if PS Remoting is active
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
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
            $Message += "$($s.Name) $($s.Status)`n"
        }
        throw $Message
    }
    return $false
}
Invoke-Main