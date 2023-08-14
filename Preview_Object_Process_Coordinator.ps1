<#
    .DESCRIPTION
    Script to run all processes for monitoring purposes.

#>
Import-Module "./Core/Import-AllModules.psm1"

function Invoke-Main {
    $Timer = [System.Diagnostics.Stopwatch]::StartNew()
    New-FolderStructure
    Get-DeviceInventoryToMonitor
    Invoke-ObjectScripts
    Wait-StartedScripts
    "$($Timer.Elapsed.ToString("hh\:mm\:ss\.fff")) - Completed" | Out-File -FilePath ./log.txt -Append
}
function Invoke-ObjectScripts {
    $scriptsToRun = Get-ChildItem -Path ".\Core\Objects"
    foreach($S in $scriptsToRun){
        Start-Job -Name $($S.Name) -FilePath $S.FullName
    }
}
function Wait-StartedScripts {
    while ($null -ne (Get-Job)){
        $jobName = $null
        $jobName = (Get-Job | Where-Object { $_.State -ne "Running" } | Select-Object -First 1).Name
        if ($null -ne $jobName) {
            "$($Timer.Elapsed.ToString("hh\:mm\:ss\.fff")) - $jobname" | Out-File -FilePath ./log.txt -Append
            Remove-Job -Name $jobName
        }
    }
    
}
function New-FolderStructure {
    & ".\Core\New-FolderStructure.ps1"
}
function Get-DeviceInventoryToMonitor {
    & ".\Core\SyncData\Get-DeviceInventoryToMonitor.ps1"
    Get-Job | Remove-Job -Force
    "$($Timer.Elapsed.ToString("hh\:mm\:ss\.fff")) - Get-DeviceInventoryToMonitor"
}

Invoke-Main