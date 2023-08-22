<#
    .DESCRIPTION
    Script to run scripts gathering object data
#>
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "PIPE_NAME" -Value $(($MyInvocation).MyCommand.Name) -Force -Scope Global -Option ReadOnly
New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Global
New-Variable -Name "TIMER" -Value $([System.Diagnostics.Stopwatch]::StartNew()) -Force -Scope Global

function Invoke-Main {
    Write-MainLog
    Test-DevicesActive
    Start-ObjectJobs
    Wait-ObjectJobs
    Write-MainLog -Completed
}

function Test-DevicesActive {
    & ".\Core\SyncData\Test-ActiveDevices.ps1"
    Write-MainLog -Message "Test-DevicesActive"
}
function Start-ObjectJobs {
    $scripts = Get-ChildItem ".\Core\Events" | Where-Object {$_.Name -notlike "Preview*"}
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
            Write-MainLog -Message $jobname
            Receive-Job $jobName
            Remove-Job -Name $jobName
            Write-Host "`n"
        }
    }
    
}

Invoke-Main