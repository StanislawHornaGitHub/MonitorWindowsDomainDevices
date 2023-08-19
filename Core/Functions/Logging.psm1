function Write-MainLog {
    param(
        $Message,
        [switch]$Completed
    )
    if ($Message) {
       "$($TIMER.Elapsed.ToString("hh\:mm\:ss\.fff")) _ $Message" | Out-File -FilePath $(Get-PipeLogName) -Append
    }
    else {
        if ($Completed) {
            $numOfDevices = $(Get-ComputerListToProcess).count
            $logLine = "$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss")) _ $PIPE_NAME finished, ExitCode: $EXIT_CODE, Processed devices: $numOfDevices, took: $($TIMER.Elapsed.Seconds) seconds"
            $logLine | Out-File -FilePath $MAIN_LOG_PATH -Append
            $logLine | Out-File -FilePath $(Get-PipeLogName) -Append
        }
        else {
            $logLine = "$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss")) _ $PIPE_NAME started"
            $logLine | Out-File -FilePath $MAIN_LOG_PATH -Append
            $logLine | Out-File -FilePath $(Get-PipeLogName) -Append
        }   
    }      
}
function Get-PipeLogName {
    return $("$PIPELINE_LOGS_DIRECTORY\$((Get-Date).ToString("yyyy-MM-dd"))_$($PIPE_NAME.split(".")[0]).txt")
}