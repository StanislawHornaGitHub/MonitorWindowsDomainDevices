<#
    .DESCRIPTION
    Script to check if device is active before retrieving data

#>
Import-Module "./Core/Import-AllModules.psm1"

New-Variable -Name 'TEST_PS_REMOTING_TIMEOUT' -Value 100 -Force -Scope Script -Option ReadOnly
function Invoke-Main {
    $Credentials = Get-CredentialFromJenkins
    [System.Collections.ArrayList]$Computer = Get-ComputerListToProcess
    Test-Computers
    $Computer | Export-Csv -Path $AVAILABLE_DEVICES_TABLE -NoTypeInformation
}
function Test-Computers {
    $IndexesToRemove = @()
    for ($i = 0; $i -lt $Computer.Count; $i++) {
        $Hostname = $Computer[$i].DNSHostName
        if($(Test-WinRMservice -ComputerName $Hostname) -eq $false){
            $IndexesToRemove += $i
        }
    }
    $IndexesToRemove | ForEach-Object {
        $Computer.RemoveAt($_)
    }
}
function Test-WinRMservice {
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
    return $false
}

Invoke-Main