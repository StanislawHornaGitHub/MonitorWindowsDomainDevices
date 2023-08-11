function Get-CredentialFromJenkins {
    <#
    .DESCRIPTION
    Function to create PSCredential object from Jenkins environmental variables.    
    It can be used in other scripts to get particular user to authenticate

#>
    try {
        $pass = $env:jenkinspass | ConvertTo-SecureString -AsPlainText -Force -ErrorAction Stop
        $Credentials = New-Object System.Management.Automation.PSCredential($env:jenkinsuser, $pass) -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    return $Credentials
}

function Get-ComputerListToProcess {
    <#
    .DESCRIPTION
    Function to get the list of devices which are active at the moment.

#>
    try {
        $Result = Import-Csv -Path $AVAILABLE_DEVICES_TABLE -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    if ($null -eq $Result) {
        throw "There are no devices to process."
    }
    return $Result
}
function Export-ObjectTable {
    <#
    .DESCRIPTION
    Function to Export result object table

#>    
    param(
        $OutputTable,
        $Result

    )

    $Result = Invoke-Compare -TablePath $OutputTable -Result $Result
    
    if ($(Test-Path -Path $OutputTable)) {
        Remove-Item -Path $OutputTable -Force -Confirm:$false | Out-Null
    }
    $Result | Export-Csv -Path $OutputTable -NoTypeInformation
}
function Invoke-Compare {
    <#
    .DESCRIPTION
    Function to rewrite old data for unActive devices

#>    
    param(
        $TablePath,
        $Result
    )
    # If the table does not exist there is nothing to compare
    if (-not $(Test-Path -Path $TablePath)) {
        return $Result
    }
    [System.Collections.ArrayList]$oldResult = Import-Csv -Path $TablePath
    for ($i = 0; $i -lt $Result.Count; $i++) {
        $oldResult.Add($oldResult[$i]) | Out-Null
    }
    $Result = Remove-Duplicates -SourceTable $Result `
        -ColumnNameGroup "DNSHostName" `
        -ColumnNameSort 'LastUpdate' `
        -Descending -DateTime
    return $Result
}