<#
    .DESCRIPTION
    Script to run scripts gathering object data
#>
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script

function Invoke-Main {
    $Timer = [System.Diagnostics.Stopwatch]::StartNew()
    "$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss")) Event Pipe started" | Out-File -FilePath ./log.txt -Append
    & ".\Core\SyncData\Test-ActiveDevices.ps1"
    "$($Timer.Elapsed.ToString("hh\:mm\:ss\.fff")) - Test-DevicesActive" | Out-File -FilePath ./log.txt -Append
    Start-ObjectJobs
    Wait-ObjectJobs
    "$($Timer.Elapsed.ToString("hh\:mm\:ss\.fff")) - Execution Completed" | Out-File -FilePath ./log.txt -Append
}

function Start-ObjectJobs {
    $scripts = Get-ChildItem ".\Core\Events"
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
            "$($Timer.Elapsed.ToString("hh\:mm\:ss\.fff")) - $jobname" | Out-File -FilePath ./log.txt -Append
            Write-Host "$($Timer.Elapsed.ToString("hh\:mm\:ss\.fff")) - $jobname"
            Receive-Job $jobName
            Remove-Job -Name $jobName
            Write-Host "`n"
        }
    }
    
}

Invoke-Main