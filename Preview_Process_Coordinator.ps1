<#
    .DESCRIPTION
    Script to run all processes for monitoring purposes.
#>
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script


New-Variable -Name "MAX_SLEEP_INTERVAL" -Value 3600000 -Force -Scope Script
New-Variable -Name "BYPASS_EMPTY_INVENTORY" -Value $false -Force -Scope Script -Option ReadOnly
New-Variable -Name "CONFIG_FILEPATH" -Value "./Config.json" -Force -Scope Script -Option ReadOnly
New-Variable -Name "TEST_SQL_SLEEP_TIME_SECONDS" -Value 60 -Force -Scope Script -Option ReadOnly


function Invoke-Main {
    Write-Log -Message "Process started" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    try {
        Test-RootContents
        Test-SQLserver
        Remove-OldJobs
        Invoke-MainLoop
    }
    catch {
        Write-Log -Message "$($_.Exception.Message)" -Type "error" -Path $PROCESS_COORDINATOR_LOG_PATH
        $EXIT_CODE = 1
    }
    finally {
        Write-Log -Message "Process exited with code $EXIT_CODE" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
        exit $EXIT_CODE
    }
}
function Invoke-MainLoop {
    Write-Log -Message "Entering main loop" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    $whileCondition = $true
    while ($whileCondition) {
        # Get Log name for current date
        New-Variable -Name "PROCESS_COORDINATOR_LOG_PATH" `
        -Value "$LOGS_ROOT_DIRECTORY\$((Get-Date).ToString("yyyy-MM-dd"))_Process_coordinator_Log.txt" `
        -Force -Scope Global -Option ReadOnly
        # Get jobs to run and time thresholds
        $Config = Get-ConfigurationDetails
        $SleepTime = ($Script:MAX_SLEEP_INTERVAL * 1000) 
        # SyncData Section
        foreach ($S in $Config.SyncData.Keys) {
            $currentTime = Get-Date
            $refreshInterval = $Config.SyncData.$S.'Refresh_Interval_in_seconds'
            # Get time when job should be invoked
            $runTime = $Config.SyncData.$S.'Last_Refresh_time'.AddSeconds($refreshInterval)
            # Calculate time difference between current time and desired run time
            $jobSleeptimeMiliseconds = ($currentTime - $runTime).TotalMilliseconds
            # If current time is -gt than runtime than it should be run now
            if ($jobSleeptimeMiliseconds -ge 0) {
                Write-Host "Start job $S" -ForegroundColor Green
                ### Start Appropriate job ###
                Start-DataRetrievingJob -Name $S -Type "SyncData"
            }
            else {
                # If time difference was -lt 0 than we have the sleep time for this job
                $jobSleeptimeMiliseconds *= (-1)
                if ($jobSleeptimeMiliseconds -lt $SleepTime) {
                    $SleepTime = $jobSleeptimeMiliseconds
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
            $jobSleeptimeMiliseconds = ($currentTime - $runTime).TotalMilliseconds
            # If current time is -gt than runtime than it should be run now
            if ($jobSleeptimeMiliseconds -ge 0) {
                Write-Host "Start job $O" -ForegroundColor Green
                ### Start Appropriate job ###
                Start-DataRetrievingJob -Name $O -Type "Objects"
            }
            else {
                # If time difference was -lt 0 than we have the sleep time for this job
                $jobSleeptimeMiliseconds *= (-1)
                if ($jobSleeptimeMiliseconds -lt $SleepTime) {
                    $SleepTime = $jobSleeptimeMiliseconds
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
            $jobSleeptimeMiliseconds = ($currentTime - $runTime).TotalMilliseconds
            # If current time is -gt than runtime than it should be run now
            if ($jobSleeptimeMiliseconds -ge 0) {
                Write-Host "Start job $E" -ForegroundColor Green
                ### Start Appropriate job ###
                Start-DataRetrievingJob -Name $E -Type "Events"
            }
            else {
                # If time difference was -lt 0 than we have the sleep time for this job
                $jobSleeptimeMiliseconds *= (-1)
                if ($jobSleeptimeMiliseconds -lt $SleepTime) {
                    $SleepTime = $jobSleeptimeMiliseconds
                }
            }
        }
        Write-Log -Message "Start Sleep $([int]$SleepTime) miliseconds" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
        Start-Sleep -Milliseconds $SleepTime
    }
    Write-Log -Message "Exiting main loop" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
}
function Start-DataRetrievingJob {
    param(
        $Type,
        $Name
    )
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
            Write-Log -Message "Job $Name last execution did not end" -Type "error" -Path $PROCESS_COORDINATOR_LOG_PATH
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
        Write-Log -Message "Job $Name removed" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
        $Query = Get-SQLdataUpdateQuery -Entry $Entry -TableName "LastExecution" -sqlPrimaryKey 'Name'
        $Entry
        $Query
        Invoke-SQLquery -Query $Query
    }
    # Start new job
    Start-Job -Name $Name `
        -InitializationScript { Set-Location $env:DEVICE_MONITORING_ROOT_DIRECTORY } `
        -FilePath $("./Core/$Type/$Name")

    Write-Log -Message "Job $Name started" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
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
    Write-Log -Message "SQL Server Availability passed" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
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
                Write-Log -Message "Script $file is missing" -Type "warning" -Path $PROCESS_COORDINATOR_LOG_PATH
                $Status = $false
            }
        }
    }
    if ($Status -eq $false) {
        throw "Some Components are missing"
    }
    Write-Log -Message "Component compliance passed" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
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
function Remove-OldJobs {
    Get-Job | Remove-Job -Force
    Write-Log -Message "Old jobs removed" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
}

Invoke-Main