<#
    .DESCRIPTION
    Script to check if device is active before retrieving data

#>
Import-Module "./Core/Import-AllModules.psm1"

New-Variable -Name 'TEST_PS_REMOTING_TIMEOUT' -Value 100 -Force -Scope Script -Option ReadOnly
New-Variable -Name "PING_TIMEOUT" -Value 50 -Force -Scope Script -Option ReadOnly
function Invoke-Main {
    $Credentials = Get-CredentialFromJenkins
    [System.Collections.ArrayList]$Computer = Get-ComputerListToProcess
    Test-Computers
    $Computer | Export-Csv -Path $AVAILABLE_DEVICES_TABLE -NoTypeInformation
}
function Test-Computers {
    $IndexesToRemove = @()
    for ($i = 0; $i -lt $Computer.Count; $i++) {
        $IP = $Computer[$i].IPaddress
        if((Invoke-Ping -IPaddress $IP).PingSucceded -eq $false){
            $IndexesToRemove += $i
        }
    }
    $IndexesToRemove | ForEach-Object {
        $Computer.RemoveAt($_)
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