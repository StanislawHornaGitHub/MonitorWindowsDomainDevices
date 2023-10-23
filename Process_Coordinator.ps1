<#
.SYNOPSIS
    Main Script running constanly to run subsequent PowerShell scripts,
    which are responsible for retrieving data from monitored devices. 

.DESCRIPTION
    Process running constantly in infinite loop which starts subsequent scripts,
    as PowerShell Background Jobs within refresh interval time configured in Config.json
    The process involves regularly running scripts in Powershell and Transact-SQL.
    Uses SQL Device_Monitoring_Maintenance Database to store and process all information
    related to starting jobs, to optimize run times and reduce CPU usage spikes,
    by shifting scripts start times in thresholds calculated based on data from Config.json
    and historical data gathered in SQL Device_Monitoring_Maintenance Database.
    An additional mechanism has been implemented to track devices that have connected to the network recently,
    in order to execute, selected in config file, PowerShell scripts on them outside the schedule,
    to get some information or information changes as soon as possible
    To gracefully stop the process use commands in Config.json by changing 0 to 1,
    for the command which you would like to invoke.

    Steps performed on each Main Loop iteration:
        1. Get new Log file name and Remove old logs.
        2. Get all Configuration and statistical information.
            2.1. Read out Config.json.
            2.2. Find lowest refresh interval time.
            2.3. Count how many scripts should be run within lowest refresh interval time.
            2.4. Update SQL Table with refresh interval times configured in Config.json.
            2.5. Get from SQL next run time and average processing time for each script.
            2.6. Merge data from Config.json and SQL into one Configuration variable.
        3. Check if there are any devices Recently connected to Network:
            3.1. If yes start whole Recently Started Process.
        4. Go through all PowerShell script types in given order [SyncData / Events / Objects]:
            4.1. Go through all scripts within given type:
                4.1.1. Check if next run time is right now or already passed:
                4.1.2. If yes check if any script was already triggered.
                4.1.3. If yes get average processing time for the script triggered before.
                4.1.4. Compare it with allowed shift time and choose lower value.
                4.1.5. Start sleep for number of seconds chosen in previous step.
            4.2. Prepare to start desired PowerShell script:
                4.2.1. Check if this script is still running since previous execution.
                4.2.2. If yes stop it and push details to SQL log table.
                4.2.3. Try to ping once all active devices, all without reply mark as inactive.
                4.2.4. Start desired PowerShell script in Background Job.
            4.3. Save details about currently invoked script for next iteration.
        5. Go through all Transact-SQL scripts:
            5.1. Check if next run time is right now or already passed.
            5.2. If yes prepare to start desired Transact-SQL script:
                5.2.1. Check if this script is still running since previous execution.
                5.2.2. If yes stop it and push details to SQL log table.
                5.2.3. Start desired Transact-SQL script using PowerShell Background Job.
        6. Prepare to sleep Process Coordinator until next script should be triggered.
            6.1. Get date of next script execution in the nearest future from SQL.
            6.2. Calculate time until next execution.
            6.3. Start sleep for time from previous step.
        7. Check status of "Commands" section in config file.
            7.1. If Stop_Process_and_Disable_Task_Scheduler is set to 1 disable task Scheduler.
            7.2. Exit Main Loop.
            7.3. Close all completed jobs and wait for remaining for configured time.
            7.4. Exit the Process.
        8. Start next Main Loop iteration. (go to step no. 1)

.INPUTS
    PowerShell scripts in following directories (.\Core):
        * Events
        * Objects
        * SyncData
    PowerShell modules in following directories (.\Core):
        * Functions
        * Variables
    Transact-SQL Queries and scripts in following directory (.\Core) 
        * SQL
    Content of Config.json file.

.OUTPUTS
    Microsoft SQL Server Data Tables:
        * Device_Monitoring - Database to collect all information retrieved by sub scripts
        * Device_Monitoring_Maintenance - Additional procesisng information, to keep everything working
    Log file Stored in .\Log catalog - Details about actions taken

.NOTES

    Version:            2.0
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      17-Aug-2023
    ChangeLog:

    Date            Who                     What
    21-09-2023      Stanisław Horna         Old log files auto-cleanup.
    29-09-2023      Stanisław Horna         RecentlyStarted functionality added.
    19-10-2023      Stanisław Horna         Action triggering order changed, to invoke SyncData jobs first.
    20-10-2023      Stanisław Horna         Nested functions and script variables moved to dedicated files.
    21-10-2023      Stanisław Horna         Separate foreach loops for different types of scripts nested in outer one,
                                                which is going through script types.
                                                Sleep time calculation changed to Datetime which is retrieved from SQL,
                                                just before Start-Sleep the number of milliseconds to sleep is calculated.
    22-10-2023      Stanisław Horna         Deleting completed jobs in each iteration, 
                                                instead of deleting them before the script was triggered once again.
                                                Lock to run only one ProcessCoordinator instance added.
    23-10-2023      Stanisław Horna         Mechanism to run SQL queries regularly added.
    24-10-203       Stanisław Horna         Feedback based shifts between subsequent script runs,
                                                calculated on the basis of the average from the same time of the previous day.
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
        Invoke-InstanceLock
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
        # Remove jobs which are not in "Running" state
        Remove-CompletedDataRetrievingJobs
        # Get jobs to run and time thresholds
        $Config = Get-ConfigurationDetails
        # Prepare cross loop iterations variables
        $SleepTimeUsed = 0
        $scriptInvokedInCurrentIteration = $false
        $scriptTriggeredBefore = @{
            "Name" = $null
            "Type" = $null
        }
        # Run on recently started devices section
        $NumberOfRecentlyStartedDevices = $(Get-NumberOfRecentylStartedDevices)
        if (($NUMBER_OF_SCRIPTS_TO_RUN_OUT_OF_SCHEDULE -gt 0) -and ($NumberOfRecentlyStartedDevices -gt 0)) {
            Start-RecentlyStartedProcess -Config $Config -NumberOfRecentlyStartedDevices $NumberOfRecentlyStartedDevices
        }
        # Loop through all PowerShell Script types
        foreach ($T in $POWERSHELL_SCRIPT_TYPES_TO_LOOP_THROUGH) {
            Write-Log -Message "$T scripts loop started" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
            # Loop through all PowerShell scripts in a given type
            foreach ($S in $Config.$T.Keys) {
                # Check if next run time has passed
                if ($(Get-Date) -ge $($Config.$T.$S.'Next_Run')) {
                    Write-Log -Message "Invoking: $S" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
                    # Verify if there are any other scripts triggered in this While loop iteration
                    # If yes than invoke the time shift if number of shifts has not been exceeded
                    $SleepTimeUsed = Invoke-ScriptTriggerShift -Config $Config `
                        -scriptInvokedInCurrentIteration $scriptInvokedInCurrentIteration `
                        -scriptTriggeredBefore $scriptTriggeredBefore `
                        -SleepTimeUsed $SleepTimeUsed
                    # Invoke script to retrieve data
                    $scriptInvokedInCurrentIteration = `
                        Start-DataRetrievingJob -Name $S -Type $T
                    # Save Script name and type for next iteration
                    $scriptTriggeredBefore.Name = "$S"
                    $scriptTriggeredBefore.Type = "$T"
                }
            }
            Write-Log -Message "$T scripts loop completed" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
        }
        # Loop through SQL Scripts
        foreach ($SQL in $Config.SQL.Keys) {
            if ($(Get-Date) -ge $($Config.SQL.$SQL.'Next_Run')) {
                Write-Log -Message "Invoking: $SQL" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
                # Invoke SQL script
                Start-SQLqueryJob -SQLqueryFileName $SQL
            }
        }
        # Calculate the time until the next script should be invoked
        # Start-Sleep until the next script will require running
        Invoke-ProcessCoordinatorSleep
        # Check if params in "Commands" section in Config.json file has been changed
        $whileCondition = Stop-ProcessCoordinator
    }
    Write-Log -Message "Exiting main loop" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
}

Invoke-Main