<#
    .DESCRIPTION
    Script to run all processes for monitoring purposes.
    Use registry to store when particular script was trigerred for the last time
    Infinite loop which is checking the timing for jobs and starting new scripts in background jobs
    rebuild logging capabilities

#>
Import-Module "./Core/Import-AllModules.psm1"

New-Variable -Name "TEST_SQL_SLEEP_TIME_SECONDS" -Value 60 -Force -Scope Script -Option ReadOnly


function Invoke-Main {
    Test-SQLserver

}
function Invoke-MainLoop {
    
}
function Test-SQLserver {
    while ($(Test-SQLserverAvailability -BypassEmptyInventory $BypassEmptyInventory) -eq $false){
        Start-Sleep -Seconds $TEST_SQL_SLEEP_TIME_SECONDS
    }
}
function Test-ScriptsToRetrieveData {
    $Exit = $false
    $SyncData = Get-ChildItem -Path ".\Core\SyncData"
    if($SyncData.Count -le 1){
        Write-Log -Message "There are no scripts to get active devices list"
        $Exit = $true
    }
    $Objects = Get-ChildItem -Path ".\Core\Objects"
    if($Objects.Count -le 0){
        Write-Log -Message "There are no scripts to retrieve object data"
        $Exit = $true
    }
    $Events = Get-ChildItem -Path ".\Core\Events"
    if($Events.Count -le 0){
        Write-Log -Message "There are no scripts to retrieve event data"
        $Exit = $true
    }
}
Invoke-Main