<#
.SYNOPSIS
    Script to enable monitoring via Monitor Windows Domain Devices

.DESCRIPTION
    Script is performing actions below to allow Process Server to Cmdlets on end-point device
    1. Check if the device is domain joined
    2. Create Firewall ping allow rule
    3. Enable PSRemoting

.INPUTS
    None

.OUTPUTS
    None

.NOTES

    Version:            1.0
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      31-Aug-2023
    ChangeLog:

    Date            Who                     What

#>
New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script
New-Variable -Name "SYSTEM_CLASS" -Value "Win32_ComputerSystem" -Force -Scope Script -Option ReadOnly
New-Variable -Name "ICMP_RULE_PARAMS" -Value @{
    Name        = "Allow ICMPv4 MWDD"
    DisplayName = "Allow incoming ICMP traffic to work with Monitor Windows Domain Devices"
    Enabled     = "True"
    Direction   = "Inbound"
    Action      = "Allow"
    Protocol    = "ICMPv4"
} -Force -Scope Script -Option ReadOnly

function Invoke-Main {
    try {
        Test-DomainJoined
        New-FWpingAllowRule
        Enable-PowerShellRemoting
        Write-SuccessInformation
    }
    catch {
        $EXIT_CODE = 1
        Write-Error $_
    }
    finally {
        Pause
        exit $EXIT_CODE
    }
}
function Test-DomainJoined {
    $Result = Get-WmiObject -Class $SYSTEM_CLASS -Property PartOfDomain
    if ($Result.PartOfDomain -ne $true) {
        throw "This device is not Domain Joined"
    }
    Write-Host "Computer is Domain Joined" -ForegroundColor Green
}
function New-FWpingAllowRule {
    try {
        Get-NetFirewallRule -Name $($ICMP_RULE_PARAMS.Name) -ErrorAction Stop
    }
    catch {
        try {
            New-NetFirewallRule @ICMP_RULE_PARAMS -ErrorAction Stop
        }
        catch {
            throw $_
        }
        Write-Host "Firewall rule successfully created" -ForegroundColor Green
        return
    }
    Write-Host "Firewall with name $($ICMP_RULE_PARAMS.Name) already exists" -ForegroundColor Yellow
}
function Enable-PowerShellRemoting {
    try {
        Enable-PSRemoting -Force -SkipNetworkProfileCheck -ErrorAction Stop
    }
    catch {
        throw $_
    }
    Write-Host "PSRemoting successfully enabled" -ForegroundColor Green
}
function Write-SuccessInformation {
    Write-Host ""
    Write-Host "-----------------------------------------------------------------------------------------------" -ForegroundColor Green
    Write-Host "-- Computer has been successfuly set up to work with Monitor Windows Domain Devices Solution --" -ForegroundColor Green
    Write-Host "-----------------------------------------------------------------------------------------------" -ForegroundColor Green
}
Invoke-Main 
