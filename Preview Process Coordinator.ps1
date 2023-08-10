<#
    .DESCRIPTION
    Script to run all processes for monitoring purposes.

#>
Import-Module "./Core/Import-AllModules.psm1"

function Invoke-Main {
    New-DataBaseStructure
    Get-DeviceInventoryToMonitor
}

function New-FolderStructure {
    & ".\Core\New-FolderStructure.ps1"
}
function Get-DeviceInventoryToMonitor {
    & ".\Core\Objects\Get-DeviceInventoryToMonitor.ps1"   
}

Invoke-Main