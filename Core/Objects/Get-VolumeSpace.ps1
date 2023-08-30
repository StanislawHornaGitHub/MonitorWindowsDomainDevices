<#
.SYNOPSIS
    Script to get volumes' spaces 

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

        SystemDriveCapacity_GB - Capacity of the volume where OS is installed
        SystemDriveFreeSpace_GB - Free space of the volume where OS is installed
        SystemDriveUsed - Percentage of used space
        AllDriveCapacity_GB - Capacity of all volumes on the device
        AllDriveFreeSpace_GB - Free space of all volumes on the device
        AllDriveUsed - Percentage of overall usage
        OtherDrivesDetails - Listed partitions with letter, overall capacity and free space
                            (e.g D:\ - 1863.01GB - 1231.72GB)

.NOTES

    Version:            1.0
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      14-Aug-2023
    ChangeLog:

    Date            Who                     What

#>
param(
    [switch]$DEBUG
)
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "SCRIPT_NAME" -Value "Get-VolumeSpace" -Force -Scope Global -Option ReadOnly
New-Variable -Name "TIMER" -Value $([System.Diagnostics.Stopwatch]::StartNew()) -Force -Scope Global

New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script
New-Variable -Name "SQL_TABLE_TO_UPDATE" -Value "Storage" -Force -Scope Script -Option ReadOnly

New-Variable -Name "REMOTE_CONNECTION_TIMEOUT_SECONDS" -Value 60 -Force -Scope Script -Option ReadOnly
New-Variable -Name 'INPUT_HASH' -Value  @{
    "Volumes" = @{
        "CLASS_Name" = "Win32_Volume"
        "Property"   = @("Caption", "FileSystem", "Capacity", "FreeSpace")
        "Filter"     = "Caption like '%:%' AND (FileSystem like 'NTFS' OR FileSystem like 'REFS')"
    }
} -Force -Scope Script -Option ReadOnly
function Invoke-Main {
    Write-Joblog
    try {
        Get-WMIDataAsJob -InputHash $INPUT_HASH
        Get-VolumeDetails
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

function Get-VolumeDetails {
    $Time = [System.Diagnostics.Stopwatch]::StartNew()
    $LastUpdate = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    while ($null -ne (Get-Job) -and ($Time.ElapsedMilliseconds -le ($REMOTE_CONNECTION_TIMEOUT_SECONDS * 1000))) {
        $jobName = $null
        $jobName = (Get-Job | Where-Object { $_.State -ne "Running" } | Select-Object -First 1).Name
        if ($null -ne $jobName) {
            Write-Host "Operations during timeout - $jobname"
            $Entry = [pscustomobject] @{
                'DNSHostName'             = $($jobName.split(";")[1])
                'LastUpdate'              = ""
                'SystemDriveCapacity_GB'  = 0
                'SystemDriveFreeSpace_GB' = 0
                'SystemDriveUsed'         = 0
                'AllDriveCapacity_GB'     = 0
                'AllDriveFreeSpace_GB'    = 0
                'AllDriveUsed'            = 0
                'OtherDrivesDetails'      = ""
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
                If ($success) {
                    $Entry = Get-SystemDriveDetails -Entry $Entry -Output $Output
                    $Entry = Get-AllDrivesDetails -Entry $Entry -Output $Output
                    $Entry.'LastUpdate' = $LastUpdate
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

function Get-SystemDriveDetails {
    param (
        $Entry,
        $Output
    )
    $SystemDrive = $Output.Volumes | Where-Object { $_.Caption -eq "C:\" }

    $Entry.'SystemDriveCapacity_GB' = [math]::Round($($SystemDrive.Capacity / 1GB), 2)
    $Entry.'SystemDriveFreeSpace_GB' = [math]::Round($($SystemDrive.FreeSpace / 1GB), 2)
    $Entry.'SystemDriveUsed' = $(($SystemDrive.Capacity - $SystemDrive.FreeSpace) / $SystemDrive.Capacity)
    $Entry.'SystemDriveUsed' = $(($Entry.'SystemDriveUsed') * 100)

    return $Entry
}

function Get-AllDrivesDetails {
    param (
        $Entry,
        $Output
    )

    $Drives = $Output.Volumes
    if ($null -ne $Drives.Count) {
        for ($i = 0; $i -lt $Drives.Count; $i++) {
            $Entry.'AllDriveCapacity_GB' += ($Drives[$i].Capacity / 1GB)
            $Entry.'AllDriveFreeSpace_GB' += ($Drives[$i].FreeSpace / 1GB)
        }
    }
    else {
        $Entry.'AllDriveCapacity_GB' = ($Drives.Capacity / 1GB)
        $Entry.'AllDriveFreeSpace_GB' = ($Drives.FreeSpace / 1GB)
    }

    $Entry.'AllDriveUsed' = $(($($Entry.'AllDriveCapacity_GB') - $($Entry.'AllDriveFreeSpace_GB')) / $($Entry.'AllDriveCapacity_GB'))
    $Entry.'AllDriveUsed' = $(($Entry.'AllDriveUsed' ) * 100)
    
    $Entry.'AllDriveCapacity_GB' = [math]::Round($($Entry.'AllDriveCapacity_GB'), 2)
    $Entry.'AllDriveFreeSpace_GB' = [math]::Round($($Entry.'AllDriveFreeSpace_GB'), 2)

    $Drives = $Output.Volumes | Where-Object { $_.Caption -ne "C:\" }
    $Drives | ForEach-Object {
        $Entry.'OtherDrivesDetails' += `
            "$($_.Caption) - $([math]::Round(($_.Capacity / 1GB),2))GB - $([math]::Round(($_.FreeSpace / 1GB),2))GB`n" }

    return $Entry
}

Invoke-Main