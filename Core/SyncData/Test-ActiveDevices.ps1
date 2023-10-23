<#
.SYNOPSIS
    Script to check if device is activ

.DESCRIPTION
    Script to verify if the device is still active. To reduce the operations time only ICMP reply is tested.
    Only devices marked in Inventory as fully active are targetted.
    if the device is not active, than isActive is set to false in inventory.

.INPUTS
    DEBUG - switch - If it is set than no data will be pushed to the SQL server,
                    everything will be displayed in the console.

.OUTPUTS
    None

.NOTES

    Version:            1.0
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      14-Aug-2023
    ChangeLog:

    Date            Who                     What

#>
Param(
    [switch]$DEBUG
)
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script

New-Variable -Name "PING_TIMEOUT" -Value 100 -Force -Scope Script -Option ReadOnly
New-Variable -Name "COMPUTER" -Value $(Get-ComputerListToProcess) -Force -Scope Script -Option ReadOnly
function Invoke-Main {
    try {
        Test-ComputersViaPing
    }
    catch {
        Write-Error -Message $_.Exception.Message
        $EXIT_CODE = 1
    }
    finally {
        exit $EXIT_CODE
    }
}
function Test-ComputersViaPing {
    $UpdateIsActiveQueryTemplate = Get-Content -Path "$SQL_VALUE_UPDATE_QUERIES/UpdateIsActive.sql"
    for ($i = 0; $i -lt $COMPUTER.Count; $i++) {
        $IP = $COMPUTER[$i].IPaddress
        if ((Invoke-Ping -IPaddress $IP).PingSucceded -eq $false) {
            $Hostname = $COMPUTER[$i].DNSHostName
            if ($DEBUG) {
                Write-Host "$Hostname"
            } else {
                $QueryToInvoke = $UpdateIsActiveQueryTemplate.Replace("COMPUTER_DNS_HOSTNAME_VARIABLE", $Hostname)
                Invoke-SQLquery -Query $QueryToInvoke
            }
        }
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
        $PingResult.Error = "$($Ping[2]) ; "   
    }
    return $PingResult
}

Invoke-Main