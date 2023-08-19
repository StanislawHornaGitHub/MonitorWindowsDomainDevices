<#
    .DESCRIPTION
    Script to check if device is active before retrieving data

#>
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script

New-Variable -Name "PING_TIMEOUT" -Value 100 -Force -Scope Script -Option ReadOnly
New-Variable -Name "CREDENTIAL" -Value $(Get-CredentialFromJenkins) -Force -Scope Script -Option ReadOnly
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
    $UpdateIsActiveQueryTemplate = Get-Content -Path "$SQL_QUERIES_DIRECTORY/UpdateIsActive.sql"
    for ($i = 0; $i -lt $COMPUTER.Count; $i++) {
        $IP = $COMPUTER[$i].IPaddress
        if ((Invoke-Ping -IPaddress $IP).PingSucceded -eq $false) {
            $Hostname = $COMPUTER[$i].DNSHostName
            $QueryToInvoke = $UpdateIsActiveQueryTemplate.Replace("COMPUTER_DNS_HOSTNAME_VARIABLE", $Hostname)
            Invoke-SQLquery -Query $QueryToInvoke -Credential $CREDENTIAL
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