<#
.SYNOPSIS
    Script to measure network bandwith with WAN.

.DESCRIPTION
    Script to trigger Speedtest® by Ookla® (https://www.speedtest.net/pl/apps/cli)
    Measurement is triggered on Process Server only.
    Test is perform sequentially.
    No connection with end-point device is established.
    Results should be understanded as Site network speed.

.INPUTS
    DEBUG - switch - If it is set than no data will be pushed to the SQL server,
                    everything will be displayed in the console.

.OUTPUTS
    Based on input DEBUG setting data is displayed in the console or pushed to the SQL Server
        TimeStamp - Time when test was performed                 
        DNSHostName - Hostname of a Process Server which run the mesurement
        Internal_IP - NIC IP through which test was done
        MAC_Address - NIC MAC address through which test was done
        Site_External_IP - Site public IP address
        Site_ISP - ISP name
        SpeedTest_Server_Name - Destination test server name  
        SpeedTest_Server_Hostname - Destination test server hostname
        SpeedTest_Server_ID - Destination test server ID
        SpeedTest_Server_IP - Destination test server IP address
        SpeedTest_Server_Location - Destination test server location (usually city)
        SpeedTest_Server_Country - Destination test server country
        PacketLoss_Percentage - packets loss in percents
        Ping_Latency_ms - Ping delay
        Ping_jitter_ms - The variation of ping delay
        Download_Speed_Mbps - Download speed in MegaBits per second
        Download_Latency_Low_ms - Lowest measuered latency during download
        Download_Latency_High_ms - Highest measuered latency during download
        Upload_Speed_Mbps - Upload speed in MegaBits per second
        Upload_Latency_Low_ms - Lowest measuered latency during upload
        Upload_Latency_High_ms - Highest measuered latency during upload 
        URL - URL to display summary webpage

.NOTES

    Version:            1.0
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      09-Oct-2023
    ChangeLog:

    Date            Who                     What

#>
param(
    [switch]$DEBUG
)
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "SCRIPT_NAME" -Value "Get-NetworkSpeedTest.ps1" -Force -Scope Global -Option ReadOnly

New-Variable -Name "TIMER" -Value $([System.Diagnostics.Stopwatch]::StartNew()) -Force -Scope Global

New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script
New-Variable -Name "SQL_TABLE_TO_UPDATE" -Value "Event_SpeedTest" -Force -Scope Script -Option ReadOnly

function Invoke-Main {
    Write-Joblog
    try {
        Invoke-SpeedTest
        Get-SpeedTestResults
        Write-DataToSQL
    }
    catch {
        Write-Joblog -Message $_.Exception.Message
        $EXIT_CODE = 1
    }
    finally {
        Write-Joblog -Completed -ProcessedDevices $PROCESSED_DEVICES -EXIT_CODE $EXIT_CODE
        exit $EXIT_CODE
    }
}
function Invoke-SpeedTest {
    try {
        $Test = & $OOKLA_SPEEDTEST_EXE --accept-license --accept-gdpr --format=json 
    }
    catch {
        throw "Invoke-SpeedTest: $_"
    }
    $Test = $Test | ConvertFrom-Json
    New-Variable -Name "SPEEDTEST_RESULT" -Value $Test -Scope Script -Force
}
function Get-SpeedTestResults {
    try {
        $Hostname = Get-ComputerInfo -Property CsDNSHostName, CsDomain
        $Hostname = "$($Hostname.CsDNSHostName).$($Hostname.CsDomain)"
        $Result = [pscustomobject]@{
            'TimeStamp' = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
            'DNSHostName' = $Hostname
            'Internal_IP' = $SPEEDTEST_RESULT.interface.internalIp
            'MAC_Address' = $SPEEDTEST_RESULT.interface.macAddr 
            'Site_External_IP' = $SPEEDTEST_RESULT.interface.externalIp
            'Site_ISP' = $SPEEDTEST_RESULT.isp
            'SpeedTest_Server_Name' = $SPEEDTEST_RESULT.server.name
            'SpeedTest_Server_Hostname' = $SPEEDTEST_RESULT.server.host
            'SpeedTest_Server_ID' = $SPEEDTEST_RESULT.server.id
            'SpeedTest_Server_IP' = $SPEEDTEST_RESULT.server.ip
            'SpeedTest_Server_Location' = $SPEEDTEST_RESULT.server.location
            'SpeedTest_Server_Country' = $SPEEDTEST_RESULT.server.country
            'PacketLoss_Percentage' = $SPEEDTEST_RESULT.packetLoss
            'Ping_Latency_ms' = $SPEEDTEST_RESULT.ping.latency
            'Ping_jitter_ms' = $SPEEDTEST_RESULT.ping.jitter
            'Download_Speed_Mbps' = $(ConvertTo-Mbps $($SPEEDTEST_RESULT.download.bandwidth))
            'Download_Latency_Low_ms' = $SPEEDTEST_RESULT.download.latency.low
            'Download_Latency_High_ms' = $SPEEDTEST_RESULT.download.latency.high
            'Upload_Speed_Mbps' = $(ConvertTo-Mbps $($SPEEDTEST_RESULT.Upload.bandwidth))
            'Upload_Latency_Low_ms' = $SPEEDTEST_RESULT.Upload.latency.low
            'Upload_Latency_High_ms' = $SPEEDTEST_RESULT.Upload.latency.high
            'URL' = $SPEEDTEST_RESULT.result.url
        }
    }
    catch {
        throw "Get-SpeedTestResults: $_"
    }
    New-Variable -Name "SPEEDTEST_RESULT" -Value $Result -Scope Script -Force
}
function Write-DataToSQL {
    If($DEBUG){
        $SPEEDTEST_RESULT | Format-List
    } else {
        $insertQuery = Get-SQLinsertSection -Entry $SPEEDTEST_RESULT -TableName $SQL_TABLE_TO_UPDATE
        try {
            Invoke-SQLquery -Query $insertQuery 
        }
        catch {
            throw "Write-DataToSQL: $_"
        }
    }
}
function ConvertTo-Mbps {
    param (
        $Value
    )
    return $($Value * 8 / ([math]::Pow(1000,2)))
}

Invoke-Main