<#
    .DESCRIPTION
    Script to get Boot details
#>
Import-Module "./Core/Import-AllModules.psm1"
New-Variable -Name "EXIT_CODE" -Value 0 -Force -Scope Script


New-Variable -Name "REMOTE_CONNECTION_TIMEOUT_SECONDS" -Value 40 -Force -Scope Script -Option ReadOnly
New-Variable -Name "CREDENTIAL" -Value $(Get-CredentialFromJenkins) -Force -Scope Script -Option ReadOnly
New-Variable -Name 'INPUT_HASH' -Value  @{
    "CPU" = @{
        "CLASS_Name" = 'Win32_Processor'
        "Property"   = @("LoadPercentage")
        "Filter"     = ""
    }
    "RAM" = @{
        "CLASS_Name" = 'Win32_OperatingSystem'
        "Property"   = @("TotalVisibleMemorySize", "FreePhysicalMemory")
        "Filter"     = ""
    }
} -Force -Scope Script -Option ReadOnly

function Invoke-Main {
    try {
        Get-WMIDataAsJob -Credentials $CREDENTIAL -InputHash $INPUT_HASH
        Get-RecourceConsumption
    }
    catch {
        Write-Error -Message $_.Exception.Message
        $EXIT_CODE = 1
    }
    finally {
        exit $EXIT_CODE
    }
}

function Get-RecourceConsumption {
    $Timer = [System.Diagnostics.Stopwatch]::StartNew()
    while ($null -ne (Get-Job) -and ($Timer.ElapsedMilliseconds -le ($REMOTE_CONNECTION_TIMEOUT_SECONDS * 1000))) {
        $jobName = $null
        $jobName = (Get-Job | Where-Object { $_.State -ne "Running" } | Select-Object -First 1).Name
        if ($null -ne $jobName) {
            Write-Host "Operations during timeout - $jobname"
            $Entry = [pscustomobject] @{
                'DNSHostName'          = $($jobName.split(";")[1])
                'TimeStamp'            = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                'CPU_Load_Percentage'  = 0
                'RAM_Usage_Percentage' = 0
            }
            $success = $false
            try {
                $Output = Receive-Job -Name $jobName -ErrorAction Stop
                $success = $true
            }
            catch {
                Write-Host "$jobname - $($_.Exception.Message)"
                $Script:EXIT_CODE = 1 
            }
            finally {
                if ($success) {
                    $Entry.RAM_Usage_Percentage = ($($Output.'RAM'.TotalVisibleMemorySize) - $($Output.'RAM'.FreePhysicalMemory))
                    $Entry.RAM_Usage_Percentage /= $($Output.'RAM'.TotalVisibleMemorySize)
                    $Entry.RAM_Usage_Percentage *= 100
                    $Entry.RAM_Usage_Percentage = [math]::Round($($Entry.RAM_Usage_Percentage), 0)
                    if($($Output.'CPU'.LoadPercentage).count -gt 1){
                        $Avg = 0
                        $Output.'CPU'.LoadPercentage | ForEach-Object {$Avg += $_}
                        $Avg /= $($Output.'CPU'.LoadPercentage).Count
                        $Entry.CPU_Load_Percentage = [math]::Round($Avg,0)
                    }else {
                        $Entry.CPU_Load_Percentage = $Output.'CPU'.LoadPercentage
                    }
                    
                }
            }
            $insertQuery = Get-SQLinsertSection -Entry $Entry -TableName "ResourceConsumption_OLD"
            Invoke-SQLquery -Query $insertQuery -Credential $CREDENTIAL   
            Remove-Job -Name $jobName
        }
    }
    $remainingJobs = Get-Job
    if ($null -ne $remainingJobs) {
        Get-Job | Remove-Job -Force
        $remainingJobs
        throw "Background jobs were running longer than REMOTE_CONNECTION_TIMEOUT_SECONDS ($REMOTE_CONNECTION_TIMEOUT_SECONDS)"
    }
    
}

Invoke-Main
