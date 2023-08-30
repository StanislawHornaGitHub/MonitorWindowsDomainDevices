<#
.SYNOPSIS
    Script to get Boot details from monitored devices.

.DESCRIPTION
    Script is connecting to each device marked as active in SQL Inventory Table and retrieving information.
    For each device script is creating separate Powershell Background job responsible for collecting data.
    Results are captured and pushed to SQL OperatingSystem Table

.INPUTS
    DEBUG - switch - If it is set than no data will be pushed to the SQL server,
                    everything will be displayed in the console.
                    Remember that even if this param is used the connection to the SQL Server is still required,
                    to get the list of currently active devices

.OUTPUTS
    Based on input DEBUG setting data is displayed in the console or pushed to the SQL Server

        FastStartEnabled - [bool] True - if Fast startup is enabled on the device
        LastBootTime - [datetime] - the date when the system started up 
        LastBootType - [Normal boot / Fast start] - type of the last boot

.NOTES

    Version:            1.0
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      17-Aug-2023
    ChangeLog:

    Date            Who                     What

#>
param(
    [switch]$DEBUG
)
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "SCRIPT_NAME" -Value "Get-BootInformation" -Force -Scope Global -Option ReadOnly
New-Variable -Name "TIMER" -Value $([System.Diagnostics.Stopwatch]::StartNew()) -Force -Scope Global

New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script
New-Variable -Name "SQL_TABLE_TO_UPDATE" -Value "OperatingSystem" -Force -Scope Script -Option ReadOnly

New-Variable -Name "REMOTE_CONNECTION_TIMEOUT_SECONDS" -Value 60 -Force -Scope Script -Option ReadOnly
New-Variable -Name 'INPUT_HASH' -Value  @{
    'Registry' = @{
        "FastStart" = @{
            "RegistryPath" = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
            "Property"     = @("HiberbootEnabled")
        }
    }
    'WMI'      = @{
        'LastBootTime' = @{
            "CLASS_Name" = 'Win32_OperatingSystem'
            "Property"   = @("LastBootUpTime")
            "Filter"     = ""
        }
    }
} -Force -Scope Script -Option ReadOnly

function Invoke-Main {
    Write-Joblog
    try {
        Get-BootInformationAsJob
        Get-BootInformationFromJob
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
function Get-BootInformationAsJob {
    $Computer = Get-ComputerListToProcess
    foreach ($C in $Computer) {
        Start-Job -Name "$($C.DNSHostName)" -ScriptBlock {
            param(
                $ComputerName,
                $InputHash
            )
            # Collect data from WMI and Registry
            $Output = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                param(
                    $InputHash
                )
                $Output = @{
                    'Registry'     = @{}
                    'WMI'          = @{}
                    'LastBootType' = ""
                }
                # Rebuild structure from input hash
                foreach ($D in $InputHash.'Registry'.Keys) {
                    $Output.'Registry'.Add($D, @{})
                    foreach ($P in $InputHash.'Registry'.$D.Property) {
                        try {
                            # Gather data from registry path
                            $Output.'Registry'.$D.Add($P, (Get-Item -path $($InputHash.'Registry'.$D.RegistryPath)`
                                        -ErrorAction Stop`
                                ).GetValue($P))
                        }
                        catch {
                            throw $_.Exception.Message
                        }
                    }
                }
                # Rebuild structure from input hash
                foreach ($D in $InputHash.'WMI'.Keys) {
                    try {
                        # Gather data from WMI
                        $Output.'WMI'.Add($D, $(Get-WmiObject -Class $($InputHash.'WMI'.$D.CLASS_Name) `
                                    -Property $($InputHash.'WMI'.$D.Property) `
                                    -Filter $($InputHash.'WMI'.$D.Filter) `
                                    -ErrorAction Stop)
                        )
                    }
                    catch {
                        throw $_.Exception.Message
                    }
                }
                # Gather data form Event log
                $Output.'LastBootType' = (Get-WinEvent -ProviderName "Microsoft-Windows-Kernel-boot" `
                        -FilterXPath '*[System[EventID=27]]' `
                        -MaxEvents 1 ).Message
                return $Output
            } -ArgumentList $InputHash
            return $Output
        } -ArgumentList $($C.DNSHostName), $INPUT_HASH | Out-Null
    }
}
function Get-BootInformationFromJob {
    $Time = [System.Diagnostics.Stopwatch]::StartNew()
    while ($null -ne (Get-Job) -and ($Time.ElapsedMilliseconds -le ($REMOTE_CONNECTION_TIMEOUT_SECONDS * 1000))) {
        $jobName = $null
        $jobName = (Get-Job | Where-Object { ($_.State -ne "Running") } | Select-Object -First 1).Name
        if ($null -ne $jobName) {
            Write-Host "Operations during timeout - $jobname"
            $Entry = [PSCustomObject]@{
                'DNSHostName'      = $jobName
                'FastStartEnabled' = $null
                'LastBootTime'     = $null
                'LastBootType'     = $null

            }
            $success = $false
            try {
                $Output = Receive-Job -Name $jobName -ErrorAction Stop
                $success = $true
            }
            catch {
                Write-Joblog -Message "$jobname - $($_.Exception.Message)"
                $Script:EXIT_CODE = 1 
            }
            finally {
                if ($success) {
                    $Entry.LastBootTime = $(Convert-WMIDateTime -DateTimeString $($Output.'WMI'.LastBootTime.LastBootUpTime))
                    $Entry.FastStartEnabled = [bool]$($Output.'Registry'.'FastStart'."HiberbootEnabled")
                    $Entry.LastBootType = $(Get-BootTypeFromHex -MessageString $($Output.'LastBootType') )
                }
            }
            if ($DEBUG) {
                $Entry | Format-List
            }
            else {
                $updateQuery = Get-SQLdataUpdateQuery -Entry $Entry -TableName $SQL_TABLE_TO_UPDATE
                try {
                    Invoke-SQLquery -Query $updateQuery
                }
                catch {
                    Write-Joblog -Message $_
                }
                
            }
            Remove-Job -Name $jobName
        }
    }
    $remainingJobs = Get-Job
    if ($null -ne $remainingJobs) {
        $remainingJobs | Remove-Job -Force
        Write-Joblog -Message "Background jobs were running longer than REMOTE_CONNECTION_TIMEOUT_SECONDS ($REMOTE_CONNECTION_TIMEOUT_SECONDS)"
    }
}

function Get-BootTypeFromHex {
    param(
        $MessageString
    )
    if ($MessageString.Length -le 4) {
        return $null
    }
    $Hex = $MessageString.Substring($($MessageString.Length - 4), 3)
    switch ($Hex) {
        "0x0" {
            return "Normal boot"
        }
        "0x1" {
            return "Fast start"
        }
        "0x2" {
            return "Wakeup from Hibernation"
        }
    }
}


Invoke-Main