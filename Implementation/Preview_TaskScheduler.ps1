


function Invoke-Main {
    New-TaskSchedulerFolder
    New-MonitorWindowsDomainDevicesTask
}

function New-TaskSchedulerFolder {
    $TaskScheduler = New-Object -ComObject schedule.service
    $TaskScheduler.connect()
    $rootFolder = $TaskScheduler.GetFolder("\")
    try {
        $rootFolder.CreateFolder("MonitorWindowsDomainDevices")
    }
    catch {
        Write-Host "Folder already exists"
    }
}
function New-MonitorWindowsDomainDevicesTask {
    $processCoordinatorPath = Get-ProcessCoordinatorFullPath
    $WorkingDir = $processCoordinatorPath.Split("\") | Select-Object -SkipLast 1
    $WorkingDir = $WorkingDir -join "\"
    
    $trigger = New-ScheduledTaskTrigger -At "00:00" -Daily
    $triggerEveryMinute = New-ScheduledTaskTrigger -At "00:00" -Once `
        -RepetitionInterval (New-TimeSpan -Minutes 1) `
        -RepetitionDuration (New-TimeSpan -Days (365 * 10))
    $trigger.Repetition = $triggerEveryMinute.Repetition

    $action = New-ScheduledTaskAction -Execute Powershell.exe `
        -Argument $processCoordinatorPath `
        -WorkingDirectory $WorkingDir

    Register-ScheduledTask -TaskName "Process_Coordinator" `
        -TaskPath "MonitorWindowsDomainDevices" `
        -Description "Core process for Monitoring Windows Domain Devices" `
        -RunLevel Highest `
        -Trigger $trigger -Action $action
}
function Get-ProcessCoordinatorFullPath {
    $CurrentPath = (Get-Location).Path
    $file = Get-ChildItem -Path $CurrentPath -Filter "*Process_Coordinator.ps1"
    if ($null -eq $file) {
        Set-Location ..
        $file = Get-ChildItem -Filter "*Process_Coordinator.ps1"
        Set-Location $CurrentPath
    }
    if ($null -eq $file) {
        throw "There is no Process_Coordinator file"
    }
    return $($file.FullName)
}

Invoke-Main

