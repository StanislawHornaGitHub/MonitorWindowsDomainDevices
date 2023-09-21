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

    Version:            1.0
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      17-Aug-2023
    ChangeLog:

    Date            Who                     What
    21-09-2023      Stanisław Horna         Old log files auto-cleanup
#>
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "SCHEDULED_TASK_NAME" -Value "Process_Coordinator" -Force -Scope Script -Option ReadOnly
New-Variable -Name "SCHEDULED_TASK_PATH" "\MonitorWindowsDomainDevices" -Force -Scope Script -Option ReadOnly
New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script


New-Variable -Name "MAX_SLEEP_INTERVAL" -Value 3600000 -Force -Scope Script
New-Variable -Name "SHIFT_SCRIPT_RUN" -Value 0 -Force -Scope Script
New-Variable -Name "NUMBER_OF_TIMES_SHIFT_SCRIPT_RUN_CAN_BE_USED" -Value 0 -Force -Scope Script
New-Variable -Name "BYPASS_EMPTY_INVENTORY" -Value $false -Force -Scope Script -Option ReadOnly
New-Variable -Name "CONFIG_FILEPATH" -Value "./Config.json" -Force -Scope Script -Option ReadOnly
New-Variable -Name "TEST_SQL_SLEEP_TIME_SECONDS" -Value 60 -Force -Scope Script -Option ReadOnly

New-Variable -Name "STOP_PROCESS_COORDINATOR" -Value 0 -Force -Scope Global
New-Variable -Name "STOP_PROCESS_AND_DISABLE_TASK_SCHEDULER" -Value 0 -Force -Scope Global
New-Variable -Name "TIME_TO_WAIT_BEFORE_CANCELING_REMAING_JOBS" -Value 60 -Force -Scope Script -Option ReadOnly

function Invoke-Main {
    Write-Log -Message "Process started PID: $($PID)" -Type "start" -Path $PROCESS_COORDINATOR_LOG_PATH
    try {
        Test-RootContents
        Invoke-LogFolderStructure
        Test-SQLserver
        Remove-OldJobs
        Invoke-MainLoop
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
        
        $SleepTime = Get-MainLoopSleepTime -SleepTime $SleepTime -triggerShiftUsed $numTriggerShiftUsed
        Write-Log -Message "Start Sleep $([int]$SleepTime) miliseconds" -Type "sleep" -Path $PROCESS_COORDINATOR_LOG_PATH
        Start-Sleep -Milliseconds $SleepTime
        
        $whileCondition = Stop-ProcessCoordinator
    }
    Write-Log -Message "Exiting main loop" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
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
            $Entry.'Errors' = "$((Get-date).ToString("yyyy-MM-dd HH:mm:ss")) - Last execution did not end, Stop will be forced"
            Write-Log -Message "Job $Name last execution did not end" -Type "error" -Path $PROCESS_COORDINATOR_LOG_PATH
            Stop-Job -Name $Name -Confirm:$false
        }
        else {
            # Check if there were any errors
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
        Stop-Job -Name $Name -Confirm:$false
        Remove-Job -Name $Name -Force
        Write-Log -Message "Job $Name removed" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
        $Query = Get-SQLdataUpdateQuery -Entry $Entry -TableName "LastExecution" -sqlPrimaryKey 'Name'
        Invoke-SQLquery -Query $Query -SQLDBName $SQL_LOG_DATABASE
    }
    # Check if devices are replying to ICMP
    & "./Core/SyncData/Test-ActiveDevices.ps1"
    Write-Log -Message "Test Active devices invoked" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    # Start new job
    Start-Job -Name $Name `
        -InitializationScript { Set-Location $env:DEVICE_MONITORING_ROOT_DIRECTORY } `
        -FilePath $("./Core/$Type/$Name") | Out-Null
    # Write Log and update Last execution date in SQL
    Write-Log -Message "Job $Name started" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    Invoke-UpdateStartLastExecution -Name $Name -Type $Type
    return $true
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
function Get-ConfigurationDetails {
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
    # Return built hash
    return $hash
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
function Stop-ProcessCoordinator {
    # Check if STOP_PROCESS_COORDINATOR was set to 1 
    if ($STOP_PROCESS_COORDINATOR -eq 1) {
        Write-Log -Message "Stop process invoked by command STOP_PROCESS_COORDINATOR" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
        Stop-AllJobs

        return $false
    }
    # Check if STOP_PROCESS_AND_DISABLE_TASK_SCHEDULER was set to 1 
    if ($STOP_PROCESS_AND_DISABLE_TASK_SCHEDULER -eq 1) {
        Write-Log -Message "Stop process invoked by command STOP_PROCESS_AND_DISABLE_TASK_SCHEDULER" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
        Stop-AllJobs
        Disable-ProcessCoordinatorScheduledTask

        return $false
    }
    return $true
}
function Stop-AllJobs {
    # Set the timer to monitor the time spent on waiting for jobs
    $Time = [System.Diagnostics.Stopwatch]::StartNew()
    Write-Log -Message "Entering the loop to wait for running jobs" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    # Loop until there will be no jobs left or the time will be over
    while ($null -ne (Get-Job) -and ($Time.ElapsedMilliseconds -le ($TIME_TO_WAIT_BEFORE_CANCELING_REMAING_JOBS * 1000))) {
        # Get the first job name which is not running
        $Name = (Get-Job | Where-Object { ($_.State -ne "Running") } | Select-Object -First 1).Name
        # If there is no such job continue to the next iteration
        if ($null -ne $Name) {
            # Create entry to push to the SQL statuses
            $Entry = [PSCustomObject]@{
                'Name'           = $Name
                'Last_Exit_Code' = $null
                'Errors'         = $null
            }
            # Get job output
            try {
                Receive-Job -Name $Name -ErrorAction Stop | Out-Null
                $Entry.'Last_Exit_Code' = 0
            }
            catch {
                Write-Log -Message "$Name - $_" -Type "error" -Path $PROCESS_COORDINATOR_LOG_PATH
                $Entry.'Errors' = $_
                $Entry.'Last_Exit_Code' = 1
            }
            Remove-Job -Name $Name -Force
            # Write Log and update information in SQL
            Write-Log -Message "Job $Name removed" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
            $Query = Get-SQLdataUpdateQuery -Entry $Entry -TableName "LastExecution" -sqlPrimaryKey 'Name'
            Invoke-SQLquery -Query $Query -SQLDBName $SQL_LOG_DATABASE
        }
    }
    Write-Log -Message "Exiting waiting loop" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    # Get jobs which did not end in waiting period
    $remainingJobs = Get-Job
    # if there are no such jobs just continue
    if ($null -ne $remainingJobs) {
        # Stop all remaining jobs remove them and write a log
        $remainingJobs | Stop-Job -Confirm:$false
        $remainingJobs | Remove-Job -Force
        Write-log -Message "Background jobs were running longer than TIME_TO_WAIT_BEFORE_CANCELING_REMAING_JOBS ($TIME_TO_WAIT_BEFORE_CANCELING_REMAING_JOBS)" `
            -Type "warning" -Path $PROCESS_COORDINATOR_LOG_PATH
    }
    
}
function Disable-ProcessCoordinatorScheduledTask {
    Write-Log -Message "Disable scheduled task invoked" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
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
function Test-SQLserver {
    # Wait until the SQL Server will be able to comunicate with the Process Server
    while ($(Test-SQLserverAvailability -BypassEmptyInventory $BYPASS_EMPTY_INVENTORY) -eq $false) {
        Start-Sleep -Seconds $TEST_SQL_SLEEP_TIME_SECONDS
    }
    Write-Log -Message "SQL Server Availability passed" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
}
function Invoke-LogFolderStructure {
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
function Test-RootContents {
    # Read Config.json file
    $Config = Get-Content -Path $CONFIG_FILEPATH | ConvertFrom-Json
    $Status = $true
    # Modules check
    # Loop through each module path and check if file exists
    foreach ($module in $Config.Modules) {
        if (-not (Test-Path "./Core/$module")) {
            Write-Log -Message "Module $module is missing" -Path $PROCESS_COORDINATOR_LOG_PATH
            $Status = $false
        }
    }
    # Scripts check
    # Loop through each script path and check if file exists
    foreach ($folder in ($Config | Get-Member -MemberType NoteProperty).Name) {
        foreach ($file in ($Config.$folder | Get-Member -MemberType NoteProperty).Name) {
            if ((-not (Test-Path "./Core/$folder/$file")) -and ($folder -ne "Commands")) {
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
function Get-LastExecution {
    # Get all data gathered in Last Execution SQL table
    return (Invoke-SQLquery -FileQuery "$SQL_QUERIES_DIRECTORY/LastExecution.sql"  -SQLDBName $SQL_LOG_DATABASE)
}
function Remove-OldJobs {
    # To avoid errors remove remaining jobs
    Get-Job | Remove-Job -Force
    Write-Log -Message "Old jobs removed" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
}
function Remove-OldLogFiles {
    Write-Log -Message "Logs Cleanup invoked" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
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

Invoke-Main