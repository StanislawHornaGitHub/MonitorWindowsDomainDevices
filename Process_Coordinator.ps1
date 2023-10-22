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

    Version:            1.6
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
    21-10-2023      Stanisław Horna         Separate foreach loops for different types of scripts nested in outer one,
                                                which is going through script types.
                                                Sleep time calculation changed to Datetime which is retrieved from SQL,
                                                just before Start-Sleep the number of milliseconds to sleep is calculated.
    22-10-2023      Stanisław Horna         Deleting completed jobs in each iteration, 
                                                instead of deleting them before the script was triggered once again.
                                                Lock to run only one ProcessCoordinator instance added.
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
        $numTriggerShiftUsed = 0
        $scriptInvokedInCurrentIteration = $false
        # Run on recently started devices section
        $NumberOfRecentlyStartedDevices = $(Get-NumberOfRecentylStartedDevices)
        if (($NUMBER_OF_SCRIPTS_TO_RUN_OUT_OF_SCHEDULE -gt 0) -and ($NumberOfRecentlyStartedDevices -gt 0)) {
            Start-RecentlyStartedProcess -Config $Config -NumberOfRecentlyStartedDevices $NumberOfRecentlyStartedDevices
        }
        # Loop through all script types
        foreach ($C in $COMPONENTS_TO_LOOP_THROUGH) {
            Write-Log -Message "$C scripts loop started" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
            # Loop through all scripts in a given type
            foreach ($S in $Config.$C.Keys) {
                # Check if next run time has passed
                if ($(Get-Date) -ge $($Config.$C.$S.'Next_Run')) {
                    Write-Log -Message "Invoking: $S" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
                    # Verify if there are any other scripts triggered in this While loop iteration
                    # If yes than invoke the time shift if number of shifts has not been exceeded
                    $numTriggerShiftUsed = Invoke-ScriptTriggerShift `
                        -scriptInvokedInCurrentIteration $scriptInvokedInCurrentIteration `
                        -triggerShiftUsed $numTriggerShiftUsed
                    # Invoke script to retrieve data and increment launched scripts counter
                    $scriptInvokedInCurrentIteration = `
                        Start-DataRetrievingJob -Name $S -Type $C
                }
            }
            Write-Log -Message "$C scripts loop completed" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
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