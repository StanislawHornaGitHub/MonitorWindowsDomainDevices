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
            * Get-LastExecution
            * Update-RefreshIntervalinSQLtable
            * Get-NumberOfRecentylStartedDevices
            * Start-RecentlyStartedProcess
            * Start-DataRetrievingJob
            * Invoke-UpdateStartLastExecution

.NOTES

    Version:            1.0
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      19-Oct-2023
    ChangeLog:

    Date            Who                     What
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
        throw "Some Components are missing"
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
    while ($(Test-SQLserverAvailability -BypassEmptyInventory $BYPASS_EMPTY_INVENTORY) -eq $false) {
        Start-Sleep -Seconds $TEST_SQL_SLEEP_TIME_SECONDS
    }
    Write-Log -Message "SQL Server Availability passed" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
}
function Remove-OldJobs {
    Write-Log -Message "Remove old jobs started" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
    # To avoid errors remove remaining jobs
    Get-Job | Remove-Job -Force
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
        # If there is no such job continue to the next iteration
        if ($null -ne $Name) {
            if ($Name -eq "RecentlyStarted - Main Process") {
                Remove-Job -Name $Name -Force
                continue
            }
            else {
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
    }
    Write-Log -Message "Wait loop exited" -Type "info" -Path $PROCESS_COORDINATOR_LOG_PATH
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
function Get-LastExecution {
    # Get all data gathered in Last Execution SQL table
    return (Invoke-SQLquery -FileQuery "$SQL_QUERIES_DIRECTORY/LastExecution.sql"  -SQLDBName $SQL_LOG_DATABASE)
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
    & "$TEST_ICMP_DEVICE_ACTIVE"
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