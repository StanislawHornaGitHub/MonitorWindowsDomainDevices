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
        $Result = Import-Csv -Path "./DataBase/Temp/AvailableDevices.csv" -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    if($null -eq $Result){
        throw "There are no devices to process."
    }
    return $Result
}