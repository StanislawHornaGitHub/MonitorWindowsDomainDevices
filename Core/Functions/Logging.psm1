function Get-PipeLogName {
    return $("$PIPELINE_LOGS_DIRECTORY\$((Get-Date).ToString("yyyy-MM-dd"))_$($PIPE_NAME.split(".")[0]).txt")
}

function Write-Mainlog {
    param(
        $Message,
        [switch]$Completed
    )
    if($Message){
        $LOG_OBJECT.Operations += "$($TIMER.Elapsed.ToString("hh\:mm\:ss\.fff")) - $Message`n"
    }else{
        if ($Completed) {
            $LOG_OBJECT.End_time = $((Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))
            $LOG_OBJECT.Duration = $($TIMER.Elapsed.ToString("hh\:mm\:ss\.fff"))
            $LOG_OBJECT.Exit_code = $EXIT_CODE
            $LOG_OBJECT.Processed_devices = $(Get-ComputerListToProcess).count
            
            $Success = $false
            while ($Success -eq $false) {
                try {
                    $LOG_OBJECT | Export-Csv -Path $MAIN_LOG_PATH -NoTypeInformation -Append -ErrorAction Stop
                    $Success = $true
                }
                catch {
                    continue
                }
            }
        }
        else {
            New-Variable -Name "LOG_OBJECT" -Value $([PSCustomObject]@{
                'Pipeline_name' = $PIPE_NAME
                'Start_time' = $((Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))
                'End_time' = $null
                'Duration' = $null
                'Exit_code' = $null
                'Processed_devices' = $null
                'Operations' = ""
            }) -Force -Scope Global
        }   
    }
}
function Write-Log {
    param (
        $Message,
        $Path
    )
    "$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss")) - $Message" | Out-File -FilePath $Path -Append
}