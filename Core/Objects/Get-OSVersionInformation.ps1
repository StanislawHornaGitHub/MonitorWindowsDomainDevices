<#
.SYNOPSIS
    Script to get Device specification, CPU model, amount of RAM memory etc.

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
    
        CurrentlyLoggedOn - Currently loged on user
        OS_Version - OS version (e.g. Microsoft Windows Server 2022 Datacenter)
        OS_Display_Version - OS version based on installed patches (e.g. 21H2)
        OS_build - OS build number (e.g. 10.0.20348.1487)
        OS_Architecture - [32bit / 64bit]
        isLicenseActivated - indicates if windows is activated or not

.NOTES

    Version:            1.0
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      10-Aug-2023
    ChangeLog:

    Date            Who                     What

#>
param(
    [bool]$RunOutOfSchedule = $false,
    [switch]$DEBUG
)
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "SCRIPT_NAME" -Value "Get-OSVersionInformation" -Force -Scope Global -Option ReadOnly
New-Variable -Name "QUERY_TO_RUN_OUTOF_SCHEDULE" -Value "RecentlyStarted_ActiveDevices.sql" -Force -Scope Global -Option ReadOnly
New-Variable -Name "TIMER" -Value $([System.Diagnostics.Stopwatch]::StartNew()) -Force -Scope Global

New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script
New-Variable -Name "SQL_TABLE_TO_UPDATE" -Value "Object_OperatingSystem" -Force -Scope Script -Option ReadOnly

New-Variable -Name "REMOTE_CONNECTION_TIMEOUT_SECONDS" -Value 60 -Force -Scope Script -Option ReadOnly

New-Variable -Name 'INPUT_HASH' -Value @{
    'Registry' = @{
        "OS"        = @{
            "RegistryPath" = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
            "Property"     = @('ReleaseID', 'DisplayVersion', 'UBR')
        }
        "FastStart" = @{
            "RegistryPath" = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
            "Property"     = @("HiberbootEnabled")
        }
    }
    'WMI'      = @{
        "OS"                = @{
            "CLASS_Name" = 'Win32_OperatingSystem'
            "Property"   = @("Caption", "Version", "OSArchitecture")
            "Filter"     = ""
        }
        "License"           = @{
            "CLASS_Name" = "SoftwareLicensingProduct"
            "Property"   = @("LicenseStatus", "PartialProductKey")
            "Filter"     = "Name like 'Windows%'"
        }
        "CurrentlyLoggedOn" = @{
            "CLASS_Name" = "Win32_process"
            "Property"   = "*"
            "Filter"     = "Name='explorer.exe' OR Name='cmd.exe'"
        }
        'LastBootTime'      = @{
            "CLASS_Name" = 'Win32_OperatingSystem'
            "Property"   = @("LastBootUpTime")
            "Filter"     = ""
        }
    }
} -Force -Scope Script -Option ReadOnly

function Invoke-Main {
    Write-Joblog
    try {
        Start-CollectingOSVersionAsJob
        Get-WindowsVersionFromJob
    }
    catch {
        Write-Joblog -Message $_.Exception.Message
        $EXIT_CODE = 1
    }
    finally {
        Write-Joblog -Completed -EXIT_CODE $EXIT_CODE
        exit $EXIT_CODE
    }
}
function Start-CollectingOSVersionAsJob {
    if($RunOutOfSchedule -eq $true){
        $Computer = Get-ComputerListToProcess -PredefinedQuery $QUERY_TO_RUN_OUTOF_SCHEDULE
    }else {
        $Computer = Get-ComputerListToProcess
    }
    foreach ($C in $Computer) {
        Start-Job -Name "$($C.DNSHostName)" -ScriptBlock {
            param(
                $ComputerName,
                $InputHash
            )
            # Collect data from WMI
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
                            $Output.'Registry'.$D.Add($P, (Get-Item -path $($InputHash.'Registry'.$D.RegistryPath)`
                                        -ErrorAction Stop`
                                ).GetValue($P))
                        }
                        catch {
                            throw $_.Exception.Message
                        }
                    }
                }
                foreach ($D in $InputHash.'WMI'.Keys) {
                    try {
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
                try {
                    $Output.'WMI'.'CurrentlyLoggedOn' = $Output.'WMI'.'CurrentlyLoggedOn'.GetOwner() | `
                        Select-Object Domain, User -Unique | `
                        Where-Object { $_.Domain -notlike "*NT*" }
                    $Output.'WMI'.'CurrentlyLoggedOn' = "$($Output.'WMI'.'CurrentlyLoggedOn'.Domain)\$($Output.'WMI'.'CurrentlyLoggedOn'.User)"
                }
                catch {
                    Write-Host $_
                    $Output.'WMI'.'CurrentlyLoggedOn' = "Nobody is currently logged in"
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
function Get-WindowsVersionFromJob {
    $Time = [System.Diagnostics.Stopwatch]::StartNew()
    $LastUpdate = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    while ($null -ne (Get-Job) -and ($Time.ElapsedMilliseconds -le ($REMOTE_CONNECTION_TIMEOUT_SECONDS * 1000))) {
        $jobName = Get-CompletedJobName
        if ($null -ne $jobName) {
            Write-Host "Operations during timeout - $jobname"
            $Entry = [PSCustomObject]@{
                'DNSHostName'        = $jobName
                'LastUpdate'         = ""
                'CurrentlyLoggedOn'  = ""
                'OS_Version'         = ""
                'OS_Display_Version' = ""
                'OS_build'           = ""
                'OS_Architecture'    = ""
                'isLicenseActivated' = $false
                'FastStartEnabled'   = $null
                'LastBootTime'       = $null
                'LastBootType'       = $null
                'Error'              = ""
            }

            try {
                $Output = Receive-Job -Name $jobName -ErrorAction Stop
            }
            catch {
                Write-Joblog -Message "$jobname - $($_.Exception.Message)"
                $Script:EXIT_CODE = 1 
            }
            $Entry.'CurrentlyLoggedOn' = $($Output.'WMI'.'CurrentlyLoggedOn')

            $Entry.'OS_Version' = $Output.'WMI'.OS.Caption
            $Entry.'OS_build' = "$($Output.'WMI'.OS.Version).$($Output.'Registry'.OS.UBR)"
            $Entry.'OS_Architecture' = $($Output.'WMI'.OS.OSArchitecture).Substring(0, 6)
            $Entry.'isLicenseActivated' = `
                [bool](($Output.'WMI'.License | Where-Object { $_.PartialProductKey }).LicenseStatus)
            
            if ($Output.'Registry'.OS.DisplayVersion.length -ge 4) {
                $Entry.'OS_Display_Version' = $Output.'Registry'.OS.DisplayVersion
            }
            else {
                $Entry.'OS_Display_Version' = $Output.'Registry'.OS.ReleaseID
            }
            $Entry.LastBootTime = $(Convert-WMIDateTime -DateTimeString $($Output.'WMI'.LastBootTime.LastBootUpTime))
            $Entry.FastStartEnabled = [bool]$($Output.'Registry'.'FastStart'."HiberbootEnabled")
            $Entry.LastBootType = $(Get-BootTypeFromHex -MessageString $($Output.'LastBootType') )
            $Entry.'LastUpdate' = $LastUpdate
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
    Remove-RemainingJobs 
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