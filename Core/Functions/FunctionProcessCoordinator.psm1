<#
.SYNOPSIS
    Module with functions used in Process_Coordinator.ps1

.DESCRIPTION
    Module consists of functions which are used only one time during the execution - Before the MainLoop
    and those which are used in each iteration.
        - One time FUNCTIONS (Before MainLoop):
            * Test-RootContents - Test if all scripts configured in Config file are available in path read out from file.
            * Invoke-LogFolderStructure - Create missing directories used to store log files.
            * Test-SQLserver - Loop to wait until Configured SQL server will be responsive.
            * Remove-OldJobs -  Check and remove any Background jobs if exists.
            * Set-StopFlagToFalse - Set Stop_Process_Coordinator value in Config file to 0.
            * Stop-AllJobs - Wait configured time for running jobs and remove them. (used on ProcessCoordinator exit).
            * Disable-ProcessCoordinatorScheduledTask - According to Stop_Process_and_Disable_Task_Scheduler value in Config file.
        - Loop FUNCTIONS (Inside MainLoop):
            * Remove-OldLogFiles - Remove old log files (log file retention is configured in VariableLog.psm1).
            * Remove-CompletedDataRetrievingJobs -  Remove Jobs which are not in Running state.
            * Get-ConfigurationDetails - Read out Config file and pull additional data from SQL server.
            * Get-LastExecution - Pull form SQL server data when scripts were executed for the last time.
            * Invoke-SQLqueryWithRepetitions - try to execute SQL query several times if all of them are failure throw Main process.
            * Update-RefreshIntervalinSQLtable - Update information about script refresh interval from Config file in SQL.
            * Get-NumberOfRecentylStartedDevices - Get number of devices which became active recenly (target devices to start "RecentlyStarted" process).
            * Start-RecentlyStartedProcess - Start process to run configured scripts out of schedule on devices which became active.
            * Invoke-ScriptTriggerShift - Sleep Coordinator process to prevent running multiple scripts at the same time.
            * Start-DataRetrievingJob - Start any Data Retrieving script in background job.
            * Remove-DataRetrievingJob - Remove completed jobs.
            * Invoke-UpdateStartLastExecution - Update last execution date in SQL.
            * Invoke-ProcessCoordinatorSleep - Sleep Coordinator until next script should be triggered.
            * Get-SleepTime - Calculate sleep time for Invoke-ProcessCoordinatorSleep.
            * Stop-ProcessCoordinator - Exit Process Coordinator according to settings in "Commands" section in Config file.

.NOTES

    Version:            1.2
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      19-Oct-2023
    ChangeLog:

    Date            Who                     What
    22-10-2023      Stanisław Horna         Unification of removing any DataRetrieving jobs, new functions added:
                                                    - Remove-DataRetrievingJob
                                                Remove-CompletedDataRetrievingJobs - function added to delete completed jobs,
                                                in each Main Loop iteration
    23-10-2023      Stanisław Horna         Get-ConfigurationDetails modified to support average script processing time in result variable.
                                                Invoke-ScriptTriggerShift - calculation changed form static shifts to maximum time available,
                                                between iterations and particular shift duration is based on average processing time of the script,
                                                which was invoked before current one (in foreach context)
#>
########################
## One time FUNCTIONS ##
########################
function Test-RootContents {
    Write-Log -Message "Component compliance started" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    # Read Config file file
    $Config = Get-Content -Path $CONFIG_FILEPATH | ConvertFrom-Json
    $Status = $true
    # Modules check
    # Loop through each module path and check if file exists
    foreach ($module in $Config.Modules) {
        if (-not (Test-Path "./Core/$module")) {
            Write-Log -Message "Module $module is missing" -Type "error" -Path $PROCESS_COORDINATOR_LOG_PATH
            $Status = $false
        }
    }
    # Scripts check
    # Loop through each script path and check if file exists
    foreach ($folder in ($Config | Get-Member -MemberType NoteProperty).Name) {
        foreach ($file in ($Config.$folder | Get-Member -MemberType NoteProperty).Name) {
            if ((-not (Test-Path "./Core/$folder/$file")) -and ($folder -ne "Commands") -and ($folder -ne "SQL")) {
                Write-Log -Message "PowerShell Script $file is missing" -Type "error" -Path $PROCESS_COORDINATOR_LOG_PATH
                $Status = $false
            }
            # Separate approach for SQL scripts
            if ($folder -eq "SQL") {
                if ((-not (Test-Path "./Core/$folder/Scripts/$file"))) {
                    Write-Log -Message "SQL Script $file is missing" -Type "error" -Path $PROCESS_COORDINATOR_LOG_PATH
                    $Status = $false
                }
            }
        }
    }
    # Throw error if any file is missing
    if ($Status -eq $false) {
        throw "Test-RootContents: Some Components are missing"
    }
    Write-Log -Message "Component compliance passed" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
}
function Invoke-LogFolderStructure {
    Write-Log -Message "Logs structure started" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    # Create catalog for main logs
    if (-not (Test-Path -Path $LOGS_ROOT_DIRECTORY)) {
        New-Item -ItemType Directory -Path $LOGS_ROOT_DIRECTORY | Out-Null
        Write-Log -Message "Logs root directiory created" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    }
    # Create catalog for job logs
    if (-not (Test-Path -Path "$LOGS_ROOT_DIRECTORY\Job")) {
        New-Item -ItemType Directory -Path "$LOGS_ROOT_DIRECTORY\Job" | Out-Null
        Write-Log -Message "Logs job directiory created" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    }
    Write-Log -Message "Logs structure completed" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
}
function Test-SQLserver {
    Write-Log -Message "SQL Server Availability started" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    # Wait until the SQL Server will be able to comunicate with the Process Server
    while ($(Test-SQLserverAvailability -BypassEmptyInventory $SQL_BYPASS_EMPTY_INVENTORY) -eq $false) {
        Start-Sleep -Seconds $TEST_SQL_SLEEP_TIME_SECONDS
    }
    Write-Log -Message "SQL Server Availability passed" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
}
function Invoke-InstanceLock {
    Write-Log -Message "InstanceLock started" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    $runSuccessfully = $false
    $sqlError = ""
    for ($i = 0; $i -lt $SQL_NUMBER_OF_TRIES_BEFORE_EXIT; $i++) {
        Start-Sleep -Milliseconds ($i * $SQL_SLEEPTIME_BETWEEN_TRIES_MS)
        # Get all core data from Last Execution SQL table
        try {
            $lastInstancePID = Invoke-SQLquery -FileQuery "$SQL_LAST_INSTANCE_PID"  -SQLDBName $SQL_LOG_DATABASE
            $runSuccessfully = $true
            break
        }
        catch {
            $sqlError += "Invoke-InstanceLock: $_"
            Write-Log -Message "$sqlError" -Type "warning" -Path $PROCESS_COORDINATOR_LOG_PATH 
        }
        if ($runSuccessfully -eq $false) {
            throw $sqlError
        }
    }
    # Try to find the process with ID from last Instance lock
    # If process does not exist then Get-Process will return error
    try {
        Get-Process -Id $lastInstancePID.PID -ErrorAction Stop | Out-Null
    }   
    catch {
        Write-Log -Message "Lock created for PID: $($PID)" -Type "InstanceLock" -Path $PROCESS_COORDINATOR_LOG_PATH 
        return
    }
    # If catch block was not invoked it means that process with ID from instance lock is still running
    throw "Process with ID: $($PID) can not continue. There is another ProcessCoordinator ($($lastInstancePID.PID)) running"
}
function Remove-OldJobs {
    Write-Log -Message "Remove old jobs started" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    # To avoid errors remove jobs if there are any
    try {
        Get-Job | Remove-Job -Force -ErrorAction Stop
    }
    catch {
        throw "Remove-OldJobs: $_"
    }
    Write-Log -Message "Old jobs removed" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
}
function Set-StopFlagToFalse {
    Write-Log -Message "Set-StopFlagToFalse started" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    # Read config file
    $Config = Get-Content $CONFIG_FILEPATH | ConvertFrom-Json
    # Set Stop Process Coordinator to false
    $Config.Commands.Stop_Process_Coordinator = 0
    # Export to JSON format
    $ConfigToSave = $Config | ConvertTo-Json
    # Save modified file
    $savedSuccessfully = $false
    # Try to save config file until it will be successfully saved
    while (-not $savedSuccessfully) {
        try {
            $ConfigToSave | Set-Content -Path $CONFIG_FILEPATH
            $savedSuccessfully = $true
        }
        catch {
            Write-Log -Message "Cannot save modified config file" -Type "error" -Path $PROCESS_COORDINATOR_LOG_PATH
        }
        # Wait 500 ms between next save tries
        Start-Sleep -Milliseconds 500
    }
    Write-Log -Message "Modified config file saved successfully" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
}
function Stop-AllJobs {
    Write-Log -Message "Stop-AllJobs started" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    # Set the timer to monitor the time spent on waiting for jobs
    $Time = [System.Diagnostics.Stopwatch]::StartNew()
    Write-Log -Message "Entering the loop to wait for running jobs" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    # Loop until there will be no jobs left or the time will be over
    while ($null -ne (Get-Job) -and ($Time.ElapsedMilliseconds -le ($TIME_TO_WAIT_BEFORE_CANCELING_REMAING_JOBS * 1000))) {
        # Get the first job name which is not running
        $Name = (Get-Job | Where-Object { ($_.State -ne "Running") } | Select-Object -First 1).Name
        # If name is not null remove the job and write required log informations
        Remove-DataRetrievingJob -Name $Name
    }
    Write-Log -Message "Wait loop exited" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    # Get jobs which did not end in waiting period
    $remainingJobs = Get-Job
    # if there are no such jobs just continue
    if ($null -ne $remainingJobs) {
        # Stop all remaining jobs remove them and write a log
        $remainingJobs | Stop-Job -Confirm:$false
        $remainingJobs | Remove-Job -Force
        Write-log `
            -Message "Following background jobs were running longer than TIME_TO_WAIT_BEFORE_CANCELING_REMAING_JOBS ($TIME_TO_WAIT_BEFORE_CANCELING_REMAING_JOBS): $($remainingJobs.Name -join ", ")" `
            -Type "warning" -Path $PROCESS_COORDINATOR_LOG_PATH
    }
    
}
function Disable-ProcessCoordinatorScheduledTask {
    Write-Log -Message "Disable scheduled task started" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    # Disable task responisble for auto start of Process Coordinator
    try {
        Disable-ScheduledTask -TaskName $SCHEDULED_TASK_NAME `
            -TaskPath $SCHEDULED_TASK_PATH `
            -ErrorAction Stop | Out-Null
        Write-Log -Message "Scheduled task successfully disabled" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    }
    catch {
        Write-Log -Message "$($_.Exception.Message)" -Type "error" -Path $PROCESS_COORDINATOR_LOG_PATH
    }
}
########################
##   Loop FUNCTIONS   ##
########################
function Remove-OldLogFiles {
    Write-Log -Message "Logs Cleanup started" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    # Calculate the date limit based on the threshold in days
    $date = (Get-Date -Hour 0 -Minute 0 -Second 0).AddDays((-1 * $DAYS_TO_KEEP_LOGS_IN_FILE_FORMAT))
    # Get list of all files in root logs directory
    $rootLogs = Get-ChildItem -Path $LOGS_ROOT_DIRECTORY -File
    # Filter the files which should be removed
    $rootLogs = $rootLogs | Where-Object {
        $logdate = $_.Name.Split("_")[0]
        [System.DateTime]::ParseExact($logdate, "yyyy-MM-dd", $null) -lt $date
    }
    # remove filtered files
    $rootLogs | ForEach-Object {
        Remove-Item -Path $($_.FullName) -Force -Confirm:$false
    }
    # Get list of all files in job logs directory
    $jobLogs = Get-ChildItem -Path $LOGS_JOB_DIRECTORY -File
    # Filter the files which should be removed
    $jobLogs = $jobLogs | Where-Object {
        $logdate = $_.Name.Split("_")[0]
        [System.DateTime]::ParseExact($logdate, "yyyy-MM-dd", $null) -lt $date
    }
    # remove filtered files
    $jobLogs | ForEach-Object {
        Remove-Item -Path $($_.FullName) -Force -Confirm:$false
    }
    Write-Log -Message "Logs Cleanup completed" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
}
function Remove-CompletedDataRetrievingJobs {
    Write-Log -Message "Remove-CompletedDataRetrievingJobs started" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    # Get all job names with status different than "Running"
    $completedJobs = (Get-Job | Where-Object { ($_.State -ne "Running") }).Name
    $jobsRemovedCounter = 0
    # Loop through retrieved job names and try to remove them
    foreach ($Name in $completedJobs) {
        try {
            Remove-DataRetrievingJob -Name $Name
            $jobsRemovedCounter++
        }
        catch {
            Write-Log -Message "Remove-CompletedDataRetrievingJobs: $_" -Type "error" -Path $PROCESS_COORDINATOR_LOG_PATH
        }
    }
    Write-Log -Message "Remove-CompletedDataRetrievingJobs completed. $jobsRemovedCounter jobs removed" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
}
function Get-ConfigurationDetails {
    Write-Log -Message "Reading config file" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    # Read Config file file
    $Config = Get-Content -Path $CONFIG_FILEPATH | ConvertFrom-Json
    # Place the Command statuses from file to the variables
    New-Variable -Name "STOP_PROCESS_COORDINATOR" `
        -Value $($Config.Commands.Stop_Process_Coordinator) -Force -Scope Global
    New-Variable -Name "STOP_PROCESS_AND_DISABLE_TASK_SCHEDULER" `
        -Value $($Config.Commands.Stop_Process_and_Disable_Task_Scheduler) -Force -Scope Global
    $refreshIntervalsArray = New-Object System.Collections.ArrayList
    # Go through imported Config file and create a Hashtable to work in main loop
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
        $defaultLastRefreshDate = (Get-Date).AddDays(-360)
        $defaultNextRunDate = (Get-Date).AddDays(-359)
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
                $MAX_SLEEP_INTERVAL = $property.Value.Refresh_Interval_in_seconds
                $refreshIntervalsArray.Add($($property.Value.Refresh_Interval_in_seconds)) | Out-Null
            }
            # Create additional fields for data which will be pulled from SQL
            $hash.($Type.Name)[$property.Name] = $property.Value
            $hash.($Type.Name).($property.Name) | `
                Add-Member -MemberType NoteProperty -Name "Last_Refresh_time" -Value $defaultLastRefreshDate
            $hash.($Type.Name).($property.Name) | `
                Add-Member -MemberType NoteProperty -Name "Next_Run" -Value $defaultNextRunDate
            $hash.($Type.Name).($property.Name) | `
                Add-Member -MemberType NoteProperty -Name "AVG_Processing_Duration_ms" -Value 0
        }
    }
    # Calculate Shift time required to optimize the timing when scripts are triggered
    $Count = ($refreshIntervalsArray | Where-Object { $_ -eq $MAX_SLEEP_INTERVAL }).count
    New-Variable -Name "SHIFT_SCRIPT_RUN" -Value $($MAX_SLEEP_INTERVAL / ($Count + 1)) `
        -Force -Scope Global
    New-Variable -Name "NUMBER_OF_SCRIPTS_TO_RUN_OUT_OF_SCHEDULE" -Value $($ScriptsOutOfSchedule) -Force -Scope Global
    # Put last refresh intervals into SQL table
    Update-RefreshIntervalinSQLtable -Inputhash $hash
    # Run the SQL Query and get last execution dates
    $LastExecution = Get-LastExecution
    # Loop through data from SQL and overwrite the default last refresh date with the actual one
    for ($i = 0; $i -lt $LastExecution.Count; $i++) {
        $Type = $LastExecution[$i].Type
        $Name = $LastExecution[$i].Name
        $LastRefresh = $LastExecution[$i].Last_Start_Time
        $NextRun = $LastExecution[$i].Next_Run
        $AverageProcessingTime = $LastExecution[$i].AVG_Processing_Duration_ms
        # Skip the iteration if value is null
        if ($null -eq $LastRefresh) {
            continue
        }
        # Write values from SQL to Result hastable
        try {
            $hash.$Type.$Name.Last_Refresh_time = $LastRefresh
            $hash.$Type.$Name.Next_Run = $NextRun
            # To prevent further processing errors verify if the value is not null
            if ("DBNull" -ne $AverageProcessingTime.GetType().Name) {
                $hash.$Type.$Name.AVG_Processing_Duration_ms = $AverageProcessingTime
            }
            else {
                $hash.$Type.$Name.AVG_Processing_Duration_ms = ($SHIFT_SCRIPT_RUN * 1000)
            }
        }
        catch {
            # If script is skipped then it was running before, but current Config file does not have refresh interval set
            # If script is not skipped than it does not exist in Last Execution Table
            if ($Name -in $skippedScripts) {
                Write-Log -Message "$Type script $Name has refresh interval set to 0, but it was running in the past" -Type "warning" -Path $PROCESS_COORDINATOR_LOG_PATH
            }
            else {
                Write-Log -Message "$Type script $Name does not exist in Last Execution Table" -Type "warning" -Path $PROCESS_COORDINATOR_LOG_PATH
            }   
        }
    }
    # Return built hash
    return $hash
}
function Get-LastExecution {
    # Try to execute the query
    # If any error occur exit whole process
    try {
        $Result = Invoke-SQLqueryWithRepetitions -FileQuery "$SQL_LAST_EXECUTION" -SQLDBName $SQL_LOG_DATABASE
    }
    catch {
        throw "Get-LastExecution: $_"
    }
    return $Result
}
function Invoke-SQLqueryWithRepetitions {
    param (
        $FileQuery,
        $SQLDBName
    )
    $runSuccessfully = $false
    $sqlError = ""
    # Try several times to retrieve data from SQL if it was not possible after first try
    for ($i = 0; $i -lt $SQL_NUMBER_OF_TRIES_BEFORE_EXIT; $i++) {
        Start-Sleep -Milliseconds ($i * $SQL_SLEEPTIME_BETWEEN_TRIES_MS)
        # Get all core data from Last Execution SQL table
        try {
            $Result = Invoke-SQLquery -FileQuery "$FileQuery"  -SQLDBName $SQLDBName
            $runSuccessfully = $true
            break
        }
        catch {
            $sqlError += $_
        }
    }    
    if ($runSuccessfully -eq $false) {
        throw $sqlError
    }
    return $Result
}
function Update-RefreshIntervalinSQLtable {
    param(
        $Inputhash
    )
    # Loop through script Types
    foreach ($T in $Inputhash.Keys) {
        # Loop through scripts
        foreach ($S in $Inputhash.$T.Keys) {
            # Create and entry for a given script
            $Entry = [PSCustomObject]@{
                'Name'                        = $S
                'Refresh_Interval_in_seconds' = $($Inputhash.$T.$S.Refresh_Interval_in_seconds)
            }
            # Create appropriate Query 
            $Query = Get-SQLdataUpdateQuery -Entry $Entry -TableName "LastExecution" -sqlPrimaryKey 'Name'
            # Execute Query to update Refresh Interval
            Invoke-SQLquery -Query $Query -SQLDBName $SQL_LOG_DATABASE
        }
    }
}
function Get-NumberOfRecentylStartedDevices {
    # Invoke SQL query to get number of recently started devices which are active
    # If it is not possible to execute it write error log and return 0
    try {
        $Devices = Invoke-SQLquery -FileQuery "$SQL_RECENTLY_STARTED_QUERIES\NumberOfRecentlyActiveDevices.sql"
    }
    catch {
        Write-Log -Message "Get-NumberOfRecentylStartedDevices: $_" -Type "warning" -Path $PROCESS_COORDINATOR_LOG_PATH
        return 0
    }
    return $($Devices.RecentlyActiveDevices)
}
function Start-RecentlyStartedProcess {
    param(
        $Config,
        $NumberOfRecentlyStartedDevices
    )
    Write-Log -Message "Start-RecentlyStartedProcess started" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    # Try to get job with name "RecentlyStarted - Main Process"
    # Error will be returned if there is no such job
    try {
        $recentlyStartedjob = Get-Job -Name "RecentlyStarted - Main Process" -ErrorAction Stop
    }
    catch {
        $recentlyStartedjob = $null
    }
    # If there is job with RecenltyStarted name 
    if ($null -ne $recentlyStartedjob) {
        # If this job is in any other state than running
        if ($recentlyStartedjob.State -ne "Running") {
            # Try to get the output from this job
            # Output is not needed, however if there is any error, catch block will be executed
            try {
                Receive-Job -Name "RecentlyStarted - Main Process" -ErrorAction Stop | Out-Null
            }
            catch {
                Write-Log -Message "RecentlyStarted: $($_.Exception.Message)" -Type "error" -Path $PROCESS_COORDINATOR_LOG_PATH
            }
            # Remove the job after collecting errors
            Remove-Job -Name "RecentlyStarted - Main Process" -Force
        }
        else {
            # if job is running do not do anything with it just write appropriate log message
            Write-Log -Message "RecentlyStarted - Main Process last execution did not end" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
        }
    }
    # If job does not exist or it is not running
    if (($null -eq $recentlyStartedjob) -or ($recentlyStartedjob.State -ne "Running")) {
        # Start new Background job
        # Invoke script in it and pass config and number of devices as parameter
        Start-Job -Name "RecentlyStarted - Main Process" `
            -InitializationScript { Set-Location $env:DEVICE_MONITORING_ROOT_DIRECTORY } `
            -ScriptBlock {
            param(
                $INVOKE_SELECTED_SCRIPTS_ON_RECENLTY_STARTED_DEVICES,
                $Config,
                $NumberOfRecentlyStartedDevices
            )
            & "$INVOKE_SELECTED_SCRIPTS_ON_RECENLTY_STARTED_DEVICES" -ConfigData $Config `
                -NumberOfRecentlyStartedDevices $NumberOfRecentlyStartedDevices
        } -ArgumentList $INVOKE_SELECTED_SCRIPTS_ON_RECENLTY_STARTED_DEVICES, $Config, $NumberOfRecentlyStartedDevices | Out-Null
        Write-Log -Message "RecentlyStarted - Main Process job started" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    }
}
function Invoke-ScriptTriggerShift {
    param (
        $Config,
        $scriptInvokedInCurrentIteration,
        $scriptTriggeredBefore,
        $SleepTimeUsed
    )
    # Verify if any script was triggerred before and if allowed sleep time has not been exceeded
    if (($scriptInvokedInCurrentIteration -eq $true) -and 
        ($SleepTimeUsed -lt $MAX_SLEEP_INTERVAL)) {
        # Convert max one time sleep from seconds to milliseconds
        $timeToShift = $($SHIFT_SCRIPT_RUN * 1000)
        # Read average proccessing time for Job started on previous loop iteration
        $lastScriptProccesingTime = $Config.$($scriptTriggeredBefore.Type).$($scriptTriggeredBefore.Name).AVG_Processing_Duration_ms
        # Check if last script average processing time is less than one time sleep
        # If yes use last script average processing time
        if ($lastScriptProccesingTime -lt $timeToShift) {
            $timeToShift = $lastScriptProccesingTime
        }
        # Write log and Start sleep
        Write-Log -Message "Script trigger Shift invoked for $timeToShift miliseconds" -Type "sleep" -Path $PROCESS_COORDINATOR_LOG_PATH
        Start-Sleep -Milliseconds $timeToShift
        return $($SleepTimeUsed + $timeToShift)
    }
    return $SleepTimeUsed
}
function Start-DataRetrievingJob {
    param(
        $Type,
        $Name
    )
    # Check if job with this name already exist, if yes remove it
    Remove-DataRetrievingJob -Name $Name
    # Check if devices are replying to ICMP by invoking apropriate script
    try {
        & "$TEST_ICMP_DEVICE_ACTIVE"
        Write-Log -Message "Test-ActiveDevices.ps1 completed" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    }
    catch {
        Write-Log -Message "Test-ActiveDevices: $_" -Type "error" -Path $PROCESS_COORDINATOR_LOG_PATH
    }
    # Start new job
    Start-Job -Name $Name `
        -InitializationScript { Set-Location $env:DEVICE_MONITORING_ROOT_DIRECTORY } `
        -FilePath $("./Core/$Type/$Name") | Out-Null
    # Write success log and update SQL Last execution that Script was started
    Write-Log -Message "Job $Name started" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    Invoke-UpdateStartLastExecution -Name $Name -Type $Type
    return $true
}
function Remove-DataRetrievingJob {
    param(
        $Name
    )
    # Do not do anything if the name is null
    if ($null -eq $Name) {
        return
    }
    $Currentjob = Get-Job -Name $Name -ErrorAction SilentlyContinue
    # if it is null than nothing to process regarding job completion
    if ($null -eq $Currentjob) {
        return
    }
    # Create an entry for SQL Table update
    $Entry = [PSCustomObject]@{
        'Name'           = $Name
        'Last_Exit_Code' = $null
        'Errors'         = $null
    }
    # if job is still running use dedicated error code, write logs and stop it
    if ($Currentjob.State -eq "Running") {
        $Entry.'Last_Exit_Code' = 111
        $Entry.'Errors' = "$((Get-date).ToString("yyyy-MM-dd HH:mm:ss")) - Last execution did not end, Stop will be forced"
        Write-Log -Message "Job $Name last execution did not end" -Type "error" -Path $PROCESS_COORDINATOR_LOG_PATH
        Stop-Job -Name $Name -Confirm:$false
    }
    else {
        # Check if there were any errors inside of the job
        # Output is not needed, however if there is any error, catch block will be executed
        try {
            Receive-Job -Name $Name -ErrorAction Stop | Out-Null
            $Entry.'Last_Exit_Code' = 0
        }
        catch {
            Write-Log -Message "$Name - $_" -Type "error" -Path $PROCESS_COORDINATOR_LOG_PATH
            $Entry.'Errors' = $_
            $Entry.'Last_Exit_Code' = 1
        }
    }
    # Try to remove the job
    try {
        Remove-Job -Name $Name -Force -ErrorAction Stop
    }
    catch {
        throw "Remove-DataRetrievingJob: $_"
    }
    Write-Log -Message "Job $Name removed" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    # Retrun before updating SQL table if the job is "RecentlyStarted - Main Process"
    # It should not be included in LastExecution table, because this job is not run on regular basis
    if ($Name -eq "RecentlyStarted - Main Process") {
        return
    }
    # Update SQL
    $Query = Get-SQLdataUpdateQuery -Entry $Entry -TableName "LastExecution" -sqlPrimaryKey 'Name'
    Invoke-SQLquery -Query $Query -SQLDBName $SQL_LOG_DATABASE
}
function Start-SQLqueryJob {
    param(
        $SQLqueryFileName
    )
    # Check if job with this name already exist, if yes remove it
    Remove-DataRetrievingJob -Name $SQLqueryFileName
    # Start new job
    Start-Job -Name $SQLqueryFileName `
        -InitializationScript { Set-Location $env:DEVICE_MONITORING_ROOT_DIRECTORY } `
        -ScriptBlock {
        param(
            $SQLqueryFileName
        )
        # Import modules to work with custom functions
        Import-Module "./Core/Import-AllModules.psm1"
        # Create standard variables
        New-Variable -Name "TIMER" -Value $([System.Diagnostics.Stopwatch]::StartNew()) -Force -Scope Global
        New-Variable -Name "SCRIPT_NAME" -Value $SQLqueryFileName -Force -Scope Global -Option ReadOnly
        New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script
        # create job log entry
        Write-Joblog
        # Try to invoke Transact-SQL script
        # Any execution errors will by collected by catch block and saved in Job log
        try {
            $Result = Invoke-Sqlcmd `
                -ServerInstance $SQL_SERVER `
                -InputFile "./Core/SQL/Scripts/$SQLqueryFileName" `
                -ErrorAction Stop
            Write-Joblog -Message $Result
        }
        catch {
            Write-Joblog -Message $_.Exception.Message
            $EXIT_CODE = 1
        }
        finally {
            # Save job log entry without processed devices
            Write-Joblog -Completed -ProcessedDevices "" -EXIT_CODE $EXIT_CODE 
            exit 
        }
    } -ArgumentList $SQLqueryFileName | Out-Null
    # Write success log and update SQL
    Write-Log -Message "Job $SQLqueryFileName started" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    Invoke-UpdateStartLastExecution -Name $SQLqueryFileName -Type "SQL"
}
function Invoke-UpdateStartLastExecution {
    param(
        $Name,
        $Type
    )
    # Create an entry to update Script execution data
    $Entry = [PSCustomObject]@{
        'Name'            = $Name
        'Type'            = $Type
        'Last_Start_Time' = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    # Create appropriate Query 
    $Query = Get-SQLdataUpdateQuery -Entry $Entry -TableName "LastExecution" -sqlPrimaryKey 'Name'
    # Execute Query on the Server
    Invoke-SQLquery -Query $Query -SQLDBName $SQL_LOG_DATABASE
}
function Invoke-ProcessCoordinatorSleep {
    # Calculate number of milliseconds when process coordinator can sleep
    $SleepTime = Get-SleepTime
    Write-Log -Message "Start Sleep $([int]$SleepTime) miliseconds" -Type "sleep" -Path $PROCESS_COORDINATOR_LOG_PATH
    # Start sleeping
    Start-Sleep -Milliseconds $SleepTime
}
function Get-SleepTime {
    # Try to execute the query
    # If any error occur exit whole process
    try {
        $Result = Invoke-SQLqueryWithRepetitions -FileQuery "$SQL_SLEEP_TIME_FOR_PROCESS_COORDINATOR" -SQLDBName $SQL_LOG_DATABASE
    }
    catch {
        throw "Get-LastExecution: $_"
    }
    # If calculated sleep time is less than 500 ms, return 500ms as minimum sleep time
    if ($Result.SleepTime -lt 500) {
        $Result.SleepTime = 500
    }    
    return $($Result.SleepTime)
}
function Stop-ProcessCoordinator {
    # Check if STOP_PROCESS_COORDINATOR was set to 1 
    if ($STOP_PROCESS_COORDINATOR -eq 1) {
        Write-Log -Message "Stop process invoked by command STOP_PROCESS_COORDINATOR" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
        # Return value of while condition for Main Loop
        return $false
    }
    # Check if STOP_PROCESS_AND_DISABLE_TASK_SCHEDULER was set to 1 
    if ($STOP_PROCESS_AND_DISABLE_TASK_SCHEDULER -eq 1) {
        Write-Log -Message "Stop process invoked by command STOP_PROCESS_AND_DISABLE_TASK_SCHEDULER" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
        Disable-ProcessCoordinatorScheduledTask
        # Return value of while condition for Main Loop
        return $false
    }
    # Return value of while condition for Main Loop
    return $true
}