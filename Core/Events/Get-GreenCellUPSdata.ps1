<#
.SYNOPSIS
    Script to get GreenCell uninterruptible power supply status.

.DESCRIPTION
    Script is connecting to each device with configured service using GC API.
    It is creating the access token based on the credentials and queries the API for current status.

.INPUTS
    DEBUG - switch - If it is set than no data will be pushed to the SQL server,
                    everything will be displayed in the console.
                    Remember that even if this param is used the connection to the SQL Server is still required,
                    to get the list of currently active devices

.OUTPUTS
    DNSHostName     - Host name of the device which is managing the UPS                                                                                                                                                              
    TimeStamp       - time of the measurement                                                                                                                                                                 
    inputVoltage    - UPS input voltage
    outputVoltage   - UPS output voltage
    inputFrequency  - UPS input frequency                                                                                                                                                             load           : 6                                                                                                                                                                                    batteryVoltage : 27,4                                                                                                                                                                                 
    batteryLevel    - UPS Battery level                                                                                                                                                           
    batteryLow      - UPS Battery low flag
    offline         - UPS Offline flag
    active          - UPS Active flag
    connected       - UPS Connected flag
    
.NOTES

    Version:            1.0
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      24-Feb-2024
    ChangeLog:

    Date            Who                     What
#>
param(
    [bool]$RunOutOfSchedule = $false,
    [switch]$DEBUG
)
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "SCRIPT_NAME" -Value "Get-GreenCellUPSdata.ps1" -Force -Scope Global -Option ReadOnly
New-Variable -Name "QUERY_TO_RUN_WITH_SCHEDULE" -Value "ActiveDevicesWithGCupsConnected.sql" -Force -Scope Global -Option ReadOnly
New-Variable -Name "QUERY_TO_RUN_OUTOF_SCHEDULE" -Value "ActiveDevicesWithGCupsConnected.sql" -Force -Scope Global -Option ReadOnly
New-Variable -Name "TIMER" -Value $([System.Diagnostics.Stopwatch]::StartNew()) -Force -Scope Global

New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script
New-Variable -Name 'SQL_TABLE_TO_UPDATE' -Value "Event_UPS_Status" -Force -Scope Global

New-Variable -Name 'API_URL_LOGIN' -Value 'http://DNS_HOST_NAME_TO_REPLACE:8080/api/login' -Force -Scope Global
New-Variable -Name 'API_URL_GET_STATUS' -Value 'http://DNS_HOST_NAME_TO_REPLACE:8080/api/current_parameters' -Force -Scope Global
New-Variable -Name 'API_LOGIN_PAYLOAD' -Value "{`"password`":`"PASSWORD_TO_REPLACE`"}" -Force -Scope Global
New-Variable -Name 'API_USER_AGENT' -Value "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36 Edg/121.0.0.0" -Force -Scope Global
New-Variable -Name 'COLUMNS_TO_DB' -Value @("inputVoltage", "outputVoltage", "inputFrequency", "load", "batteryVoltage", "batteryLevel", "batteryLow", "offline", "active", "connected") -Force -Scope Global

function Invoke-Main {
    Write-Joblog
    try {
        $Computer = Get-DevicesList -RunOutOfSchedule $RunOutOfSchedule `
            -QueryWithSchedule $QUERY_TO_RUN_WITH_SCHEDULE `
            -QueryOutOfSchedule $QUERY_TO_RUN_OUTOF_SCHEDULE
        foreach ($entry in $Computer) {
            try {
                $token = Get-AccessToken -SecretsEntry $entry
                $data = Get-CurrentValues -SecretsEntry $entry -SessionAndToken $token
                Write-DataToSQL -Data $data
            }
            catch {
                Write-Joblog -Message $_.Exception.Message
                $EXIT_CODE = 1
                continue
            }
        }
    }
    catch {
        Write-Joblog -Message $_.Exception.Message
        $EXIT_CODE = 1
    }
    finally {
        Write-Joblog -Completed -ProcessedDevices $(($Computer | Measure-Object).Count) -EXIT_CODE $EXIT_CODE
        exit $EXIT_CODE
    }
}

function Get-AccessToken {
    param(
        $SecretsEntry
    )
    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $session.UserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36 Edg/121.0.0.0"
    $AuthResponse = Invoke-WebRequest -Uri $($API_URL_LOGIN.Replace("DNS_HOST_NAME_TO_REPLACE", $SecretsEntry.DNSHostName))  `
        -Method "POST" `
        -WebSession $session `
        -Headers $(Get-LoginHeaders -DNSHostName $SecretsEntry.DNSHostName) `
        -Body $($API_LOGIN_PAYLOAD.Replace("PASSWORD_TO_REPLACE", $SecretsEntry.PassPhrase)) `
        -UseBasicParsing

    $token = ($AuthResponse.Content | ConvertFrom-Json).access_token
    return @{
        "session" = $session
        "token"   = $token
    }
}
function Get-CurrentValues {
    param (
        $SecretsEntry,
        $SessionAndToken
    )
    $ValueResponse = Invoke-WebRequest -Uri $API_URL_GET_STATUS.Replace("DNS_HOST_NAME_TO_REPLACE", $SecretsEntry.DNSHostName) `
        -WebSession $SessionAndToken.session `
        -Headers  $(Get-ValuesHeaders -DNSHostName $SecretsEntry.DNSHostName -Token $SessionAndToken.token) `
        -UseBasicParsing
    $Result = $($ValueResponse.Content | ConvertFrom-Json | Select-Object $COLUMNS_TO_DB)
    $Result | Add-Member -MemberType NoteProperty -Name "DNSHostName" -Value $SecretsEntry.DNSHostName
    $Result | Add-Member -MemberType NoteProperty -Name "TimeStamp" -Value (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
    return [pscustomobject]$Result
}

function Get-LoginHeaders {
    param (
        $DNSHostName
    )
    $headers = @{
        "Accept"          = "application/json, text/plain, */*"
        "Accept-Encoding" = "gzip, deflate"
        "Accept-Language" = "pl,en;q=0.9,en-GB;q=0.8,en-US;q=0.7"
        "Content-Type"    = "application/json"
        "Origin"          = "http://$($DNSHostName):8080"
        "Referer"         = "http://$($DNSHostName):8080/pl"
    }
    return $headers
}
function Get-ValuesHeaders {
    param (
        $DNSHostName,
        $Token
    )
    $headers = @{
        "Accept"          = "application/json, text/plain, */*"
        "Accept-Encoding" = "gzip, deflate"
        "Accept-Language" = "pl,en;q=0.9,en-GB;q=0.8,en-US;q=0.7"
        "Content-Type"    = "application/json"
        "Authorization"   = "Bearer $Token"
        "If-None-Match"   = "W/`"25d-WR2RTCR32Uxj9XQSZ6y263cfdSU`""
        "Referer"         = "http://$($DNSHostName):8080/pl"
    }
    return $headers
}
function Write-DataToSQL {
    param(
        $Data
    )
    If ($DEBUG) {
        $Data | Format-List
    }
    else {
        $insertQuery = Get-SQLinsertSection -Entry $Data -TableName $SQL_TABLE_TO_UPDATE
        try {
            Invoke-SQLquery -Query $insertQuery 
        }
        catch {
            throw "Write-DataToSQL: $_"
        }
    }
}

Invoke-Main