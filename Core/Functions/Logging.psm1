<#
.SYNOPSIS
    Module with functions to create consistant logs

.DESCRIPTION
    Module consists of functions used to log what is happening in the scripts and Proces Coordinator.
    It contain following functions:
        
        Write-Joblog - Used to write the execution of both objects and events scripts to the file in csv format.
                       For each script following information is covered:
                            - Script name
                            - Start time
                            - End time
                            - Execution duration
                            - Exit Code
                            - Number of processed devices
                            - Message - anything else that should be saved such like warnings errors etc.
        Write-Log - Used to write information from Process Coordinator about current status in text format.
                    Following data are saved:
                            - Timestamp of the message in seconds
                            - Message type (INFO / WARNING / ERROR)

.NOTES

    Version:            1.0
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      19-Aug-2023
    ChangeLog:

    Date            Who                     What

#>
function Write-Joblog {
    param(
        $Message,
        [switch]$Completed,
        $EXIT_CODE
    )
    if ($Message) {
        $LOG_OBJECT.Message += "$($TIMER.Elapsed.ToString("hh\:mm\:ss\.fff")) - $Message`n"
    }
    else {
        if ($Completed) {
            $LOG_OBJECT.End_time = $((Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))
            $LOG_OBJECT.Duration = $($TIMER.Elapsed.ToString("hh\:mm\:ss\.fff"))
            $LOG_OBJECT.Exit_code = $EXIT_CODE
            $LOG_OBJECT.Processed_devices = $(Get-ComputerListToProcess).count
            
            $Success = $false
            while ($Success -eq $false) {
                try {
                    $LOG_OBJECT | Export-Csv -Path $JOB_LOG_PATH -NoTypeInformation -Append -ErrorAction Stop
                    $Success = $true
                }
                catch {
                    continue
                }
            }
            $LOG_OBJECT.Message = $LOG_OBJECT.Message.Replace("'", "`"")
            $insertQuery = Get-SQLinsertSection -Entry $LOG_OBJECT -TableName "Log_Job" -sqlPrimaryKey 'Script_name'
            try {
                Invoke-SQLquery -Query $insertQuery -SQLDBName $SQL_LOG_DATABASE
            }
            catch {
                Write-Log -Message "$SCRIPT_NAME - Cannot update Job_Log Table - $($_)" -Type 'error' -Path $PROCESS_COORDINATOR_LOG_PATH
            }
        }
        else {
            New-Variable -Name "LOG_OBJECT" -Value $([PSCustomObject]@{
                    'Script_name'       = $SCRIPT_NAME
                    'Start_time'        = $((Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))
                    'End_time'          = $null
                    'Duration'          = $null
                    'Exit_code'         = $null
                    'Processed_devices' = $null
                    'Message'           = ""
                }) -Force -Scope Global
        }   
    }
}
function Write-Log {
    param (
        $Message,
        $Type,
        $Path,
        [bool]$UpdateFileLogOnly = $false
    )
    $Type = $Type.ToUpper()
    $date = $((Get-Date).ToString("yyyy-MM-dd HH:mm:ss\.fff"))
    "$date - $Type : $Message" | Out-File -FilePath $Path -Append
    if ($UpdateFileLogOnly -eq $false) {
        $Message = $Message.Replace("'", "`"")
        $Entry = [PSCustomObject]@{
            'Timestamp'    = $date
            'Message_type' = $Type
            'Message'      = $Message
        }
        $insertQuery = Get-SQLinsertSection -Entry $Entry -TableName "Log_Process_coordinator" -sqlPrimaryKey 'Timestamp'
        try {
            Invoke-SQLquery -Query $insertQuery -SQLDBName $SQL_LOG_DATABASE
        }
        catch {
            Write-Log -Type 'error' `
                -Message "Cannot update Log_Process_coordinator Table - $($_)" `
                -Path $PROCESS_COORDINATOR_LOG_PATH `
                -UpdateFileLogOnly $true
        }
    }
}