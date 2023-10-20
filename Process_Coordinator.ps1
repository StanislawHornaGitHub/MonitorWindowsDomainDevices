<#
.SYNOPSIS
    Script to run all processes for monitoring purposes.

.DESCRIPTION
    Script running constantly in infinite loop which is starting scripts to retrieve data.
    Scripts are run in Powershell Background Jobs.
    Refresh intervals are collected from Config.json on each loop iteration.
    To gracefully stop the process use commands in Config.json by changing 0 to 1,
    for the command which you would like to invoke.

.INPUTS
    Content of Config.json file

.OUTPUTS
    Log file Stored in .\Log catalog

.NOTES

    Version:            1.1
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      17-Aug-2023
    ChangeLog:

    Date            Who                     What
    21-09-2023      Stanisław Horna         Old log files auto-cleanup
    29-09-2023      Stanisław Horna         RecentlyStarted functionality added
    19-10-2023      Stanisław Horna         Action triggering order changed, to invoke SyncData jobs first
    20-10-2023      Stanisław Horna         Nested functions and script variables moved to dedicated files
#>
Import-Module ".\Core\Import-AllModules.psm1"
Import-Module ".\Core\Variables\VariableProcessCoordinator.psm1"
Import-Module ".\Core\Functions\FunctionProcessCoordinator.psm1"

function Invoke-Main {
    Write-Log -Message "Process started PID: $($PID)" -Type "start" -Path $PROCESS_COORDINATOR_LOG_PATH
    try {
        Test-RootContents
        Invoke-LogFolderStructure
        Test-SQLserver
        Remove-OldJobs
        Set-StopFlagToFalse
        Invoke-MainLoop
        Stop-AllJobs
    }
    catch {
        Write-Log -Message "$($_.Exception.Message)" -Type "error" -Path $PROCESS_COORDINATOR_LOG_PATH
        $EXIT_CODE = 1
    }
    finally {
        Write-Log -Message "Process exited with code $EXIT_CODE" -Type "stop" -Path $PROCESS_COORDINATOR_LOG_PATH
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
        # Cleanup old logs
        Remove-OldLogFiles
        # Get jobs to run and time thresholds
        $Config = Get-ConfigurationDetails
        $SleepTime = ($Script:MAX_SLEEP_INTERVAL * 1000)
        $numTriggerShiftUsed = 0
        $scriptInvokedInCurrentIteration = $false
        # Run on recently started devices section
        $NumberOfRecentlyStartedDevices = $(Get-NumberOfRecentylStartedDevices)
        if (($NUMBER_OF_SCRIPTS_TO_RUN_OUT_OF_SCHEDULE -gt 0) -and ($NumberOfRecentlyStartedDevices -gt 0)) {
            Start-RecentlyStartedProcess -Config $Config -NumberOfRecentlyStartedDevices $NumberOfRecentlyStartedDevices
        }
        ##############################
        ## SyncData Scripts Section ##
        ##############################
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
                $numTriggerShiftUsed = Invoke-ScriptTriggerShift `
                    -scriptInvokedInCurrentIteration $scriptInvokedInCurrentIteration `
                    -triggerShiftUsed $numTriggerShiftUsed
        
                $scriptInvokedInCurrentIteration = Start-DataRetrievingJob -Name $S -Type "SyncData"
            }
            else {
                # If time difference was -lt 0 than we have the sleep time for this job
                $jobSleeptimeMiliseconds *= (-1)
                if ($jobSleeptimeMiliseconds -lt $SleepTime) {
                    $SleepTime = $jobSleeptimeMiliseconds
                }
            }
        }
        ##############################
        ##  Events Scripts Section  ##
        ##############################
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
                $numTriggerShiftUsed = Invoke-ScriptTriggerShift `
                    -scriptInvokedInCurrentIteration $scriptInvokedInCurrentIteration `
                    -triggerShiftUsed $numTriggerShiftUsed
        
                $scriptInvokedInCurrentIteration = Start-DataRetrievingJob -Name $E -Type "Events"
            }
            else {
                # If time difference was -lt 0 than we have the sleep time for this job
                $jobSleeptimeMiliseconds *= (-1)
                if ($jobSleeptimeMiliseconds -lt $SleepTime) {
                    $SleepTime = $jobSleeptimeMiliseconds
                }
            }
        }
        ##############################
        ## Objects Scripts Section  ##
        ##############################
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
                $numTriggerShiftUsed = Invoke-ScriptTriggerShift `
                    -scriptInvokedInCurrentIteration $scriptInvokedInCurrentIteration `
                    -triggerShiftUsed $numTriggerShiftUsed
        
                $scriptInvokedInCurrentIteration = Start-DataRetrievingJob -Name $O -Type "Objects"
            }
            else {
                # If time difference was -lt 0 than we have the sleep time for this job
                $jobSleeptimeMiliseconds *= (-1)
                if ($jobSleeptimeMiliseconds -lt $SleepTime) {
                    $SleepTime = $jobSleeptimeMiliseconds
                }
            }
        }        
        $SleepTime = Get-MainLoopSleepTime -SleepTime $SleepTime -triggerShiftUsed $numTriggerShiftUsed
        Write-Log -Message "Start Sleep $([int]$SleepTime) miliseconds" -Type "sleep" -Path $PROCESS_COORDINATOR_LOG_PATH
        Start-Sleep -Milliseconds $SleepTime
        
        $whileCondition = Stop-ProcessCoordinator
    }
    Write-Log -Message "Exiting main loop" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
}
function Get-ConfigurationDetails {
    Write-Log -Message "Reading config file" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    # Read Config.json file
    $Config = Get-Content -Path $CONFIG_FILEPATH | ConvertFrom-Json
    # Place the Command statuses from file to the variables
    New-Variable -Name "STOP_PROCESS_COORDINATOR" `
        -Value $($Config.Commands.Stop_Process_Coordinator) -Force -Scope Global
    New-Variable -Name "STOP_PROCESS_AND_DISABLE_TASK_SCHEDULER" `
        -Value $($Config.Commands.Stop_Process_and_Disable_Task_Scheduler) -Force -Scope Global
    $refreshIntervalsArray = New-Object System.Collections.ArrayList
    # Go through imported Config.json and create a Hashtable to work in main loop
    $hash = @{}
    $skippedScripts = @()
    $ScriptsOutOfSchedule = 0
    # Loop through the root branches in file
    foreach ($Type in $Config.PSObject.Properties) {
        # Skip the iteration if branch is called Modules or Commands,
        # because there are no scripts which should be triggered periodically
        if ((($Type.Name) -eq "Modules") -or (($Type.Name) -eq "Commands")) {
            continue
        }
        # Add key for current branch
        $hash[$Type.Name] = @{}
        # Set the default last execution date 
        # (in case if there are no information in SQL about last execution)
        $defaultDate = (Get-Date).AddDays(-360)
        # Loop through the scripts in the current branch
        foreach ($property in $Config.($Type.Name).PSObject.Properties) {
            $ScriptsOutOfSchedule += $property.Value.RunOnceDeviceBecomeActive
            # Skip the itaration if the script refresh interval is set to 0,
            # those will be skipped from periodical triggering
            if ($property.Value.Refresh_Interval_in_seconds -le 0) {
                $skippedScripts += $($property.Name)
                continue
            }
            # Find the lowest refresh interval in seconds
            if ($property.Value.Refresh_Interval_in_seconds -le $MAX_SLEEP_INTERVAL) {
                $Script:MAX_SLEEP_INTERVAL = $property.Value.Refresh_Interval_in_seconds
                $refreshIntervalsArray.Add($($property.Value.Refresh_Interval_in_seconds)) | Out-Null
            }
            # Add the script entry to the result hash with default last refresh date
            $hash.($Type.Name)[$property.Name] = $property.Value
            $hash.($Type.Name).($property.Name) | `
                Add-Member -MemberType NoteProperty -Name "Last_Refresh_time" -Value $defaultDate
        }
    }
    # Run the SQL Query and get last execution dates
    $LastExecution = Get-LastExecution
    # Put last refresh intervals into SQL table
    Update-RefreshIntervalinSQLtable -Inputhash $hash
    # Loop through data from SQL and overwrite the default last refresh date with the actual one
    for ($i = 0; $i -lt $LastExecution.Count; $i++) {
        $Type = $LastExecution[$i].Type
        $Name = $LastExecution[$i].Name
        $LastRefresh = $LastExecution[$i].Last_Start_Time
        # Skip the iteration if value is null
        if ($null -eq $LastRefresh) {
            continue
        }
        try {
            $hash.$Type.$Name.Last_Refresh_time = $LastRefresh
        }
        catch {
            if ($Name -in $skippedScripts) {
                Write-Log -Message "$Type script $Name has refresh interval set to 0, but it was running in the past" -Type "warning" -Path $PROCESS_COORDINATOR_LOG_PATH
            }
            else {
                Write-Log -Message "$Type script $Name does not exist in config file" -Type "warning" -Path $PROCESS_COORDINATOR_LOG_PATH
            }   
        }
    }
    # Calculate Shift time required to optimize the timing when scripts are triggered
    $Count = ($refreshIntervalsArray | Where-Object { $_ -eq $Script:MAX_SLEEP_INTERVAL }).count
    New-Variable -Name "SHIFT_SCRIPT_RUN" -Value $($Script:MAX_SLEEP_INTERVAL / ($Count + 1)) `
        -Force -Scope Script
    New-Variable -Name "NUMBER_OF_TIMES_SHIFT_SCRIPT_RUN_CAN_BE_USED" -Value $($Count) -Force -Scope Script
    New-Variable -Name "NUMBER_OF_SCRIPTS_TO_RUN_OUT_OF_SCHEDULE" -Value $($ScriptsOutOfSchedule) -Force -Scope Global
    # Return built hash
    return $hash
}
function Invoke-ScriptTriggerShift {
    param (
        $scriptInvokedInCurrentIteration,
        $triggerShiftUsed
    )
    if (($scriptInvokedInCurrentIteration -eq $true) -and 
        ($triggerShiftUsed -lt $Script:NUMBER_OF_TIMES_SHIFT_SCRIPT_RUN_CAN_BE_USED)) {
        
        $timeToShift = $($Script:SHIFT_SCRIPT_RUN * 1000)
        Write-Log -Message "Script trigger Shift invoked for $timeToShift miliseconds" -Type "sleep" -Path $PROCESS_COORDINATOR_LOG_PATH
        Start-Sleep -Milliseconds $timeToShift
        return $($triggerShiftUsed + 1)
    }
    return $triggerShiftUsed
}
function Get-MainLoopSleepTime {
    param (
        $SleepTime,
        $triggerShiftUsed
    )
    $SleepTime = $($SleepTime - $($Script:SHIFT_SCRIPT_RUN * $triggerShiftUsed * 1000))
    if ($SleepTime -ge 0) {
        return $SleepTime
    }
    return 0
}
function Stop-ProcessCoordinator {
    # Check if STOP_PROCESS_COORDINATOR was set to 1 
    if ($STOP_PROCESS_COORDINATOR -eq 1) {
        Write-Log -Message "Stop process invoked by command STOP_PROCESS_COORDINATOR" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
        return $false
    }
    # Check if STOP_PROCESS_AND_DISABLE_TASK_SCHEDULER was set to 1 
    if ($STOP_PROCESS_AND_DISABLE_TASK_SCHEDULER -eq 1) {
        Write-Log -Message "Stop process invoked by command STOP_PROCESS_AND_DISABLE_TASK_SCHEDULER" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
        Disable-ProcessCoordinatorScheduledTask
        return $false
    }
    return $true
}
Invoke-Main