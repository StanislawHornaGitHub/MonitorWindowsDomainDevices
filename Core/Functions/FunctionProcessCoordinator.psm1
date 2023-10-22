<#
.SYNOPSIS
    Module with functions used in Process_Coordinator.ps1

.DESCRIPTION
    Module consists of functions which are used only one time during the execution - Before the MainLoop
    and those which are used in each iteration.
        - One time FUNCTIONS (Before MainLoop):
            * Test-RootContents
            * Invoke-LogFolderStructure
            * Test-SQLserver
            * Remove-OldJobs
            * Set-StopFlagToFalse
            * Stop-AllJobs
            * Disable-ProcessCoordinatorScheduledTask
        - Loop FUNCTIONS (Inside MainLoop):
            * Remove-OldLogFiles
            * Remove-CompletedDataRetrievingJobs
            * Get-ConfigurationDetails
            * Get-LastExecution
            * Update-RefreshIntervalinSQLtable
            * Get-NumberOfRecentylStartedDevices
            * Start-RecentlyStartedProcess
            * Invoke-ScriptTriggerShift
            * Start-DataRetrievingJob
            * Remove-DataRetrievingJob
            * Invoke-UpdateStartLastExecution
            * Invoke-ProcessCoordinatorSleep
            * Get-SleepTime
            * Stop-ProcessCoordinator

.NOTES

    Version:            1.1
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
#>
########################
## One time FUNCTIONS ##
########################
function Test-RootContents {
    Write-Log -Message "Component compliance started" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    # Read Config.json file
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
            if ((-not (Test-Path "./Core/$folder/$file")) -and ($folder -ne "Commands")) {
                Write-Log -Message "Script $file is missing" -Type "error" -Path $PROCESS_COORDINATOR_LOG_PATH
                $Status = $false
            }
        }
    }
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
    try {
        Get-Process -Id $lastInstancePID.PID -ErrorAction Stop | Out-Null
    }   
    catch {
        Write-Log -Message "Lock created for PID: $($PID)" -Type "InstanceLock" -Path $PROCESS_COORDINATOR_LOG_PATH 
        return
    }
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
    while (-not $savedSuccessfully) {
        try {
            $ConfigToSave | Set-Content -Path $CONFIG_FILEPATH
            $savedSuccessfully = $true
        }
        catch {
            Write-Log -Message "Cannot save modified config file" -Type "error" -Path $PROCESS_COORDINATOR_LOG_PATH
        }
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
    foreach($Name in $completedJobs){
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
                $Script:MAX_SLEEP_INTERVAL = $property.Value.Refresh_Interval_in_seconds
                $refreshIntervalsArray.Add($($property.Value.Refresh_Interval_in_seconds)) | Out-Null
            }
            # Add the script entry to the result hash with default last refresh date
            $hash.($Type.Name)[$property.Name] = $property.Value
            $hash.($Type.Name).($property.Name) | `
                Add-Member -MemberType NoteProperty -Name "Last_Refresh_time" -Value $defaultLastRefreshDate
            $hash.($Type.Name).($property.Name) | `
                Add-Member -MemberType NoteProperty -Name "Next_Run" -Value $defaultNextRunDate
        }
    }
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
        # Skip the iteration if value is null
        if ($null -eq $LastRefresh) {
            continue
        }
        try {
            $hash.$Type.$Name.Last_Refresh_time = $LastRefresh
            $hash.$Type.$Name.Next_Run = $NextRun
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
        -Force -Scope Global
    New-Variable -Name "NUMBER_OF_TIMES_SHIFT_SCRIPT_RUN_CAN_BE_USED" -Value $($Count) -Force -Scope Global
    New-Variable -Name "NUMBER_OF_SCRIPTS_TO_RUN_OUT_OF_SCHEDULE" -Value $($ScriptsOutOfSchedule) -Force -Scope Global
    # Return built hash
    return $hash
}
function Get-LastExecution {
    $runSuccessfully = $false
    $sqlError = ""
    for ($i = 0; $i -lt $SQL_NUMBER_OF_TRIES_BEFORE_EXIT; $i++) {
        Start-Sleep -Milliseconds ($i * $SQL_SLEEPTIME_BETWEEN_TRIES_MS)
        # Get all core data from Last Execution SQL table
        try {
            $Result = Invoke-SQLquery -FileQuery "$SQL_LAST_EXECUTION"  -SQLDBName $SQL_LOG_DATABASE
            $runSuccessfully = $true
            break
        }
        catch {
            $sqlError += "Get-LastExecution: $_"
            Write-Log -Message "$sqlError" -Type "warning" -Path $PROCESS_COORDINATOR_LOG_PATH 
        }
        if ($runSuccessfully -eq $false) {
            throw $sqlError
        }
    }
    return $Result
}
function Update-RefreshIntervalinSQLtable {
    param(
        $Inputhash
    )
    $powershellScriptTypes = @("SyncData", "Events", "Objects")
    foreach ($T in $powershellScriptTypes) {
        foreach ($S in $Inputhash.$T.Keys) {
            $Entry = [PSCustomObject]@{
                'Name'                        = $S
                'Refresh_Interval_in_seconds' = $($Inputhash.$T.$S.Refresh_Interval_in_seconds)
            }
            # Create appropriate Query 
            $Query = Get-SQLdataUpdateQuery -Entry $Entry -TableName "LastExecution" -sqlPrimaryKey 'Name'
            # Execute Query on the Server
            Invoke-SQLquery -Query $Query -SQLDBName $SQL_LOG_DATABASE
        }
    }
}
function Get-NumberOfRecentylStartedDevices {
    $Devices = Invoke-SQLquery -FileQuery "$SQL_QUERIES_DIRECTORY\ComputersToProcess\RecentlyStarted_ActiveDevices.sql"
    if (($null -ne $Devices)) {
        if (($null -ne $Devices.count)) {
            return $($Devices.count)
        }
        else {
            return 1
        }
    }
    return 0
}
function Start-RecentlyStartedProcess {
    param(
        $Config,
        $NumberOfRecentlyStartedDevices
    )
    Write-Log -Message "Start-RecentlyStartedProcess started" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    try {
        $recentlyStartedjob = Get-Job -Name "RecentlyStarted - Main Process" -ErrorAction Stop
    }
    catch {
        $recentlyStartedjob = $null
    }
    
    if ($null -ne $recentlyStartedjob) {
        if ($recentlyStartedjob.State -ne "Running") {
            try {
                Receive-Job -Name "RecentlyStarted - Main Process" -ErrorAction Stop | Out-Null
            }
            catch {
                Write-Log -Message "RecentlyStarted: $($_.Exception.Message)" -Type "error" -Path $PROCESS_COORDINATOR_LOG_PATH
            }
            Remove-Job -Name "RecentlyStarted - Main Process" -Force
        }
        else {
            Write-Log -Message "RecentlyStarted - Main Process last execution did not end" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
        }
    }
    if (($null -eq $recentlyStartedjob) -or ($recentlyStartedjob.State -ne "Running")) {
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
function Start-DataRetrievingJob {
    param(
        $Type,
        $Name
    )
    # Check if job with this name already exist, if yes remove it
    Remove-DataRetrievingJob -Name $Name
    # Check if devices are replying to ICMP
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
    # Write success log and update SQL
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
    # Write log
    Write-Log -Message "Job $Name removed" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    # Retrun before updating SQL table if the job is "RecentlyStarted - Main Process"
    # It should not be included in LastExecution table, because this job is not run on regular basis
    if($Name -eq "RecentlyStarted - Main Process"){
        return
    }
    # Update SQL
    $Query = Get-SQLdataUpdateQuery -Entry $Entry -TableName "LastExecution" -sqlPrimaryKey 'Name'
    Invoke-SQLquery -Query $Query -SQLDBName $SQL_LOG_DATABASE
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
    # Create appropriate Query 
    $Query = Get-SQLdataUpdateQuery -Entry $Entry -TableName "LastExecution" -sqlPrimaryKey 'Name'
    # Execute Query on the Server
    Invoke-SQLquery -Query $Query -SQLDBName $SQL_LOG_DATABASE
}
function Invoke-ProcessCoordinatorSleep {
    $SleepTime = Get-SleepTime
    Write-Log -Message "Start Sleep $([int]$SleepTime) miliseconds" -Type "sleep" -Path $PROCESS_COORDINATOR_LOG_PATH
    Start-Sleep -Milliseconds $SleepTime
}
function Get-SleepTime {
    $runSuccessfully = $false
    $sqlError = ""
    for ($i = 0; $i -lt $SQL_NUMBER_OF_TRIES_BEFORE_EXIT; $i++) {
        Start-Sleep -Milliseconds ($i * $SQL_SLEEPTIME_BETWEEN_TRIES_MS)
        # Get Sleep time during which Process Coordinator 
        try {
            $Result = Invoke-SQLquery -FileQuery "$SQL_SLEEP_TIME_FOR_PROCESS_COORDINATOR"  -SQLDBName $SQL_LOG_DATABASE
            $runSuccessfully = $true
            break
        }
        catch {
            $sqlError += "Get-SleepTime: $_`n"
            Write-Log -Message "$sqlError" -Type "warning" -Path $PROCESS_COORDINATOR_LOG_PATH 
        }
    }
    if ($runSuccessfully -eq $false) {
        throw $sqlError
    }
    if ($Result.SleepTime -le 500) {
        $Result.SleepTime = 500
    }    
    return $($Result.SleepTime)
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