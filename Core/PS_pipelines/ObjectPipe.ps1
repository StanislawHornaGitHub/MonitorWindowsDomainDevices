<#
    .DESCRIPTION
    Script to run scripts gathering object data
#>
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script
New-Variable -Name "TIMER" -Value $([System.Diagnostics.Stopwatch]::StartNew()) -Force -Scope Script

function Invoke-Main {
    "$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss")) Object Pipe started" | Out-File -FilePath ./log.txt -Append
    Test-DevicesActive
    "$($TIMER.Elapsed.ToString("hh\:mm\:ss\.fff")) - Test-DevicesActive" | Out-File -FilePath ./log.txt -Append
    Start-ObjectJobs
    Wait-ObjectJobs
    "$($TIMER.Elapsed.ToString("hh\:mm\:ss\.fff")) - Execution Completed" | Out-File -FilePath ./log.txt -Append
}

function Test-DevicesActive {
    & ".\Core\SyncData\Test-ActiveDevices.ps1"
}
function Start-ObjectJobs {
    $scripts = Get-ChildItem ".\Core\Objects"
    foreach ($S in $scripts) {
        Start-Job -Name $S.Name `
            -InitializationScript { Set-Location $env:DEVICE_MONITORING_ROOT_DIRECTORY } `
            -FilePath $($S.FullName)
    }
}

function Wait-ObjectJobs {
    while ($null -ne (Get-Job)) {
        $jobName = $null
        $jobName = (Get-Job | Where-Object { $_.State -ne "Running" } | Select-Object -First 1).Name
        if ($null -ne $jobName) {
            "$($TIMER.Elapsed.ToString("hh\:mm\:ss\.fff")) - $jobname" | Out-File -FilePath ./log.txt -Append
            Write-Host "$($TIMER.Elapsed.ToString("hh\:mm\:ss\.fff")) - $jobname"
            Receive-Job $jobName
            Remove-Job -Name $jobName
            Write-Host "`n"
        }
    }
}


Invoke-Main