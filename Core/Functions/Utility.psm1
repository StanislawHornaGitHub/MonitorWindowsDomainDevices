function Get-CompletedJobName {
    $jobName = $null
    $jobName = (Get-Job | Where-Object { $_.State -ne "Running" } | Select-Object -First 1).Name
    return $jobName
}
function Remove-RemainingJobs {
    $remainingJobs = Get-Job
    if ($null -ne $remainingJobs) {
        $remainingJobs | Remove-Job -Force
        Write-Joblog -Message "Background jobs were running longer than REMOTE_CONNECTION_TIMEOUT_SECONDS ($REMOTE_CONNECTION_TIMEOUT_SECONDS)"
    }
}