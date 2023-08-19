<#
    .DESCRIPTION
    Script to get Volumes space status
#>
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script


New-Variable -Name "REMOTE_CONNECTION_TIMEOUT_SECONDS" -Value 60 -Force -Scope Script -Option ReadOnly
New-Variable -Name "CREDENTIAL" -Value $(Get-CredentialFromJenkins) -Force -Scope Script -Option ReadOnly
New-Variable -Name 'INPUT_HASH' -Value  @{
    "Volumes" = @{
        "CLASS_Name" = "Win32_Volume"
        "Property"   = @("Caption", "FileSystem", "Capacity", "FreeSpace")
        "Filter"     = "Caption like '%:%' AND (FileSystem like 'NTFS' OR FileSystem like 'REFS')"
    }
} -Force -Scope Script -Option ReadOnly
function Invoke-Main {
    try {
        Get-WMIDataAsJob -Credentials $CREDENTIAL -InputHash $INPUT_HASH
        Get-VolumeDetails
    }
    catch {
        Write-Error -Message $_.Exception.Message
        $EXIT_CODE = 1
    }
    finally {
        exit $EXIT_CODE
    }
}

function Get-VolumeDetails {
    $Timer = [System.Diagnostics.Stopwatch]::StartNew()
    $LastUpdate = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    while ($null -ne (Get-Job) -and ($Timer.ElapsedMilliseconds -le ($REMOTE_CONNECTION_TIMEOUT_SECONDS * 1000))) {
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
                Write-Host "$jobname - $($_.Exception.Message)"
                $Script:EXIT_CODE = 1 
            }
            finally {
                If ($success) {
                    $Entry = Get-SystemDriveDetails -Entry $Entry -Output $Output
                    $Entry = Get-AllDrivesDetails -Entry $Entry -Output $Output
                    $Entry.'LastUpdate' = $LastUpdate
                }
            }
            $updateQuery = Get-SQLdataUpdateQuery -Entry $Entry -TableName "Storage"
            Invoke-SQLquery -Query $updateQuery -Credential $CREDENTIAL 
            Remove-Job -Name $jobName
        }
    }
    $remainingJobs = Get-Job
    if ($null -ne $remainingJobs) {
        Get-Job | Remove-Job -Force
        $remainingJobs
        throw "Background jobs were running longer than REMOTE_CONNECTION_TIMEOUT_SECONDS ($REMOTE_CONNECTION_TIMEOUT_SECONDS)"
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
    $Entry.'SystemDriveUsed' = "$([math]::Round(($Entry.'SystemDriveUsed'), 2) * 100) %"

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
    $Entry.'AllDriveUsed' = "$([math]::Round(($Entry.'AllDriveUsed' ), 2) * 100) %"
    
    $Entry.'AllDriveCapacity_GB' = [math]::Round($($Entry.'AllDriveCapacity_GB'), 2)
    $Entry.'AllDriveFreeSpace_GB' = [math]::Round($($Entry.'AllDriveFreeSpace_GB'), 2)

    $Drives = $Output.Volumes | Where-Object { $_.Caption -ne "C:\" }
    $Drives | ForEach-Object {
        $Entry.'OtherDrivesDetails' += `
            "$($_.Caption) - $([math]::Round(($_.Capacity / 1GB),2))GB - $([math]::Round(($_.FreeSpace / 1GB),2))GB" }

    return $Entry
}

Invoke-Main