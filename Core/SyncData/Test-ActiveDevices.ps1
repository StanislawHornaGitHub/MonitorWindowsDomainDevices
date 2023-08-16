<#
    .DESCRIPTION
    Script to check if device is active before retrieving data

#>
Import-Module "./Core/Import-AllModules.psm1"

New-Variable -Name "PING_TIMEOUT" -Value 50 -Force -Scope Script -Option ReadOnly
function Invoke-Main {
    $Credentials = Get-CredentialFromJenkins
    $Computer = Get-ComputerListToProcess
    Test-Computers
    $Computer | Export-Csv -Path $AVAILABLE_DEVICES_TABLE -NoTypeInformation
}
function Test-Computers {
    $UpdateIsActiveQueryTemplate = Get-Content -Path "$SQL_QUERIES_DIRECTORY/UpdateIsActive.sql"
    for ($i = 0; $i -lt $Computer.Count; $i++) {
        $IP = $Computer[$i].IPaddress
        if ((Invoke-Ping -IPaddress $IP).PingSucceded -eq $false) {
            $Hostname = $Computer[$i].DNSHostName
            $QueryToInvoke = $UpdateIsActiveQueryTemplate.Replace("COMPUTER_DNS_HOSTNAME_VARIABLE", $Hostname)
            Invoke-SQLquery -Query $QueryToInvoke -Credential $Credentials
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