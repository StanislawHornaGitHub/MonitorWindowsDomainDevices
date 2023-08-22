<#
    .DESCRIPTION
    Script to Deploy Open Hardware Monitor

#>
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script
New-Variable -Name "CREDENTIAL" -Value $(Get-CredentialFromJenkins) -Force -Scope Script -Option ReadOnly

New-Variable -Name 'DEPLOYMENT_SERVER_FOLDER_NAME_TO_COPY' -Value "OpenHardwareMonitor" -Force -Scope Script
New-Variable -Name "SQL_DEVICES_TO_DEPLOYMENT" -Value "$SQL_QUERIES_DIRECTORY\DevicesToDeployOpenHardwareMonitor.sql"
function Invoke-Main {
    try {
        Test-DevicesActive
        Invoke-Deployment
    }
    catch {
        Write-Host $_
        $EXIT_CODE = 1
    }
    finally {
        exit $EXIT_CODE
    }
}
function Test-DevicesActive {
    & ".\Core\SyncData\Test-ActiveDevices.ps1"
}
function Invoke-Deployment {
    $Computers = Get-ComputerListToDeployment
    [string]$UpdateIsOHMdeployed = Get-Content -Path "$SQL_QUERIES_DIRECTORY\UpdateIsOpenHardwareMonitorDeployed.sql"
    foreach ($C in $Computers) {
        Write-host "$($C.DNSHostName)"
        try {
            Invoke-Command -ComputerName $($C.DNSHostName) -Credential $CREDENTIAL -ScriptBlock {
                param(
                    $LOCAL_MONITORING_COMPONENTS_PATH,
                    $DEPLOYMENT_SERVER_FOLDER_NAME_TO_COPY,
                    $DEPLOYMENT_SERVER_SHARE,
                    [PSCredential] $CREDENTIAL
                )
                if (-not (Test-Path -Path $LOCAL_MONITORING_COMPONENTS_PATH)) {
                    New-Item -ItemType Directory -Path $LOCAL_MONITORING_COMPONENTS_PATH | Out-Null
                }
                New-PSDrive -Name "Deployment" -Root $DEPLOYMENT_SERVER_SHARE -PSProvider FileSystem -Credential $CREDENTIAL -ErrorAction Stop | Out-Null
                Copy-Item -Path "Deployment:\$DEPLOYMENT_SERVER_FOLDER_NAME_TO_COPY" `
                    -Destination $LOCAL_MONITORING_COMPONENTS_PATH `
                    -Recurse `
                    -ErrorAction Stop
            } -ArgumentList $LOCAL_MONITORING_COMPONENTS_PATH, $DEPLOYMENT_SERVER_FOLDER_NAME_TO_COPY, $DEPLOYMENT_SERVER_SHARE, $CREDENTIAL `
                -ErrorAction Stop
            $QueryToInvoke = $UpdateIsOHMdeployed.Replace("COMPUTER_DNS_HOSTNAME_VARIABLE", $($C.DNSHostName))
            Invoke-SQLquery -Query $QueryToInvoke -Credential $CREDENTIAL
        }
        catch {
            throw $_
        }

    }
}
function Get-ComputerListToDeployment {
    try {
        $Result = Invoke-SQLquery -FileQuery $SQL_DEVICES_TO_DEPLOYMENT
    }
    catch {
        throw $_.Exception.Message
    }
    if ($null -eq $Result) {
        throw "There are no devices to process."
    }
    return $Result
}

Invoke-Main