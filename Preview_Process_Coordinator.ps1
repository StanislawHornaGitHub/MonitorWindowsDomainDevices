<#
    .DESCRIPTION
    Script to run all processes for monitoring purposes.
    Use SQL dedicated table to store when particular script was trigerred for the last time
    Infinite loop which is checking the timing for jobs and starting new scripts in background jobs
    rebuild logging capabilities

#>
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script


New-Variable -Name "MAX_SLEEP_INTERVAL" -Value 3600 -Force -Scope Script
New-Variable -Name "BYPASS_EMPTY_INVENTORY" -Value $false -Force -Scope Script -Option ReadOnly
New-Variable -Name "CONFIG_FILEPATH" -Value "./Config.json" -Force -Scope Script -Option ReadOnly
New-Variable -Name "TEST_SQL_SLEEP_TIME_SECONDS" -Value 60 -Force -Scope Script -Option ReadOnly


function Invoke-Main {
    try {
        Test-RootContents
        Test-SQLserver
        Invoke-MainLoop
    }
    catch {
        Write-Error -Message $_.Exception.Message
        $EXIT_CODE = 1
    }
    finally {
        exit $EXIT_CODE
    }
}
function Invoke-MainLoop {
    $whileCondition = $true
    while ($whileCondition) {
        # Get jobs to run and time thresholds
        $Config = Get-ConfigurationDetails

        $SleepTime = $Script:MAX_SLEEP_INTERVAL
        # SyncData Section
        foreach ($S in $Config.SyncData.Keys) {
            $currentTime = Get-Date
            $refreshInterval = $Config.SyncData.$S.'Refresh_Interval_in_seconds'
            # Get time when job should be invoked
            $runTime = $Config.SyncData.$S.'Last_Refresh_time'.AddSeconds($refreshInterval)
            # Calculate time difference between current time and desired run time
            $jobSleeptimeSeconds = ($currentTime - $runTime).TotalSeconds
            # If current time is -gt than runtime than it should be run now
            if ($jobSleeptimeSeconds -ge 0) {
                Write-Host "Start job $S" -ForegroundColor Green
                ### Start Appropriate job ###
                Start-DataRetrievingJob -Type "SyncData" -Name $S

            }
            else {
                # If time difference was -lt 0 than we have the sleep time for this job
                $jobSleeptimeSeconds *= (-1)
                if ($jobSleeptimeSeconds -lt $SleepTime) {
                    $SleepTime = $jobSleeptimeSeconds
                }
            }
        }
        # Object Section
        foreach ($O in $Config.Objects.Keys) {
            $currentTime = Get-Date
            $refreshInterval = $Config.Objects.$O.'Refresh_Interval_in_seconds'
            # Get time when job should be invoked
            $runTime = $Config.Objects.$O.'Last_Refresh_time'.AddSeconds($refreshInterval)
            # Calculate time difference between current time and desired run time
            $jobSleeptimeSeconds = ($currentTime - $runTime).TotalSeconds
            # If current time is -gt than runtime than it should be run now
            if ($jobSleeptimeSeconds -ge 0) {
                Write-Host "Start job $O" -ForegroundColor Green
                ### Start Appropriate job ###
                
                Invoke-UpdateStartLastExecution -Name $O -Type "Objects"
            }
            else {
                # If time difference was -lt 0 than we have the sleep time for this job
                $jobSleeptimeSeconds *= (-1)
                if ($jobSleeptimeSeconds -lt $SleepTime) {
                    $SleepTime = $jobSleeptimeSeconds
                }
            }
        }
        # Events Section
        foreach ($E in $Config.Events.Keys) {
            $currentTime = Get-Date
            $refreshInterval = $Config.Events.$E.'Refresh_Interval_in_seconds'
            # Get time when job should be invoked
            $runTime = $Config.Events.$E.'Last_Refresh_time'.AddSeconds($refreshInterval)
            # Calculate time difference between current time and desired run time
            $jobSleeptimeSeconds = ($currentTime - $runTime).TotalSeconds
            # If current time is -gt than runtime than it should be run now
            if ($jobSleeptimeSeconds -ge 0) {
                Write-Host "Start job $E" -ForegroundColor Green
                ### Start Appropriate job ###

                Invoke-UpdateStartLastExecution -Name $E -Type "Events"
            }
            else {
                # If time difference was -lt 0 than we have the sleep time for this job
                $jobSleeptimeSeconds *= (-1)
                if ($jobSleeptimeSeconds -lt $SleepTime) {
                    $SleepTime = $jobSleeptimeSeconds
                }
            }
        }
        
        
        Start-Sleep -Seconds 2
        Get-Job
        if ((Get-Job -Name "Get-DeviceInventoryToMonitor.ps1").State -eq "Completed") {
            Receive-Job -Name "Get-DeviceInventoryToMonitor.ps1"
            Get-Job -Name "Get-DeviceInventoryToMonitor.ps1" | Remove-Job
            $whileCondition = $false
        }
        # Start-Sleep -Seconds $SleepTime
    }
}
function Start-DataRetrievingJob {
    param(
        $Type,
        $Name
    )
    # TEMP CONDITION FOR DEBUG
    if ($Type -ne "SyncData") {
        return
    }
    $Currentjob = Get-Job -Name $Name -ErrorAction SilentlyContinue
    # if it is null than nothing to process regarding job completion
    if ($null -ne $Currentjob) {
        $Entry = [PSCustomObject]@{
            'Name'           = $Name
            'Last_Exit_Code' = $null
            'Errors'         = $null
        }
        # if job is still running 
        if ($Currentjob.State -eq "Running") {
            $Entry.'Last_Exit_Code' = 111
            $Entry.'Errors' = "Last execution did not end, Stop will be forced"
        
            Stop-Job -Name $Name -Confirm:$false
        }
        else {
            # Check if there were any errors
            try {
                $Output = Receive-Job -Name $Name -ErrorAction Stop
                $Entry.'Last_Exit_Code' = 0
            }
            catch {
                $Entry.'Errors' = $_
                $Entry.'Last_Exit_Code' = 1
            }
        }
        Remove-Job -Name $Name -Force
        $Query = Get-SQLdataUpdateQuery -Entry $Entry -TableName "LastExecution" -sqlPrimaryKey 'Name'
    }
    # Start new job
    Start-Job -Name $Name `
        -InitializationScript { Set-Location $env:DEVICE_MONITORING_ROOT_DIRECTORY } `
        -FilePath $("./Core/$Type/$Name")

    Write-Host "JOB STARTED $Name"
    Invoke-UpdateStartLastExecution -Name $Name -Type $Type
}
function Invoke-UpdateStartLastExecution {
    param(
        $Name,
        $Type
    )
    $Entry = [PSCustomObject]@{
        'Name'            = $Name
        'Type'            = $Type
        'Last_Start_Time' = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    $Query = Get-SQLdataUpdateQuery -Entry $Entry -TableName "LastExecution" -sqlPrimaryKey 'Name'
    Invoke-SQLquery -Query $Query
}
function Test-SQLserver {
    while ($(Test-SQLserverAvailability -BypassEmptyInventory $BYPASS_EMPTY_INVENTORY) -eq $false) {
        Start-Sleep -Seconds $TEST_SQL_SLEEP_TIME_SECONDS
    }
}
function Test-RootContents {
    $Config = Get-Content -Path $CONFIG_FILEPATH | ConvertFrom-Json
    $Status = $true
    # Modules check
    foreach ($module in $Config.Modules) {
        if (-not (Test-Path "./Core/$module")) {
            Write-Log -Message "Module $module is missing" -Path $PROCESS_COORDINATOR_LOG_PATH
            $Status = $false
        }
    }
    # Scripts check
    foreach ($folder in ($Config | Get-Member -MemberType NoteProperty).Name) {
        foreach ($file in ($Config.$folder | Get-Member -MemberType NoteProperty).Name) {
            if (-not (Test-Path "./Core/$folder/$file")) {
                Write-Log -Message "Script $file is missing" -Path $PROCESS_COORDINATOR_LOG_PATH
                $Status = $false
            }
        }
    }
    if ($Status -eq $false) {
        throw "Some Components are missing"
    }
}
function Get-ConfigurationDetails {
    $Config = Get-Content -Path $CONFIG_FILEPATH | ConvertFrom-Json
    $hash = @{}
    foreach ($Type in $Config.PSObject.Properties) {
        if (($Type.Name) -eq "Modules") {
            continue
        }
        $hash[$Type.Name] = @{}
        $defaultDate = (Get-Date).AddDays(-360)
        foreach ($property in $Config.($Type.Name).PSObject.Properties) {
            if ($property.Value.Refresh_Interval_in_seconds -le 0) {
                continue
            }
            if ($property.Value.Refresh_Interval_in_seconds -le $MAX_SLEEP_INTERVAL) {
                $Script:MAX_SLEEP_INTERVAL = $property.Value.Refresh_Interval_in_seconds
            }
            $hash.($Type.Name)[$property.Name] = $property.Value
            $hash.($Type.Name).($property.Name) | `
                Add-Member -MemberType NoteProperty -Name "Last_Refresh_time" -Value $defaultDate
        }
    }
    $LastExecution = Get-LastExecution
    for ($i = 0; $i -lt $LastExecution.Count; $i++) {
        $Type = $LastExecution[$i].Type
        $Name = $LastExecution[$i].Name
        $LastRefresh = $LastExecution[$i].Last_Start_Time
        $hash.$Type.$Name.Last_Refresh_time = $LastRefresh
    }
    return $hash
}
function Get-LastExecution {
    return (Invoke-SQLquery -FileQuery "$SQL_QUERIES_DIRECTORY/LastExecution.sql")
}

Invoke-Main