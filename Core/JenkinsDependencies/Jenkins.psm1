function Get-CredentialFromJenkins {
<#
    .DESCRIPTION
    Script to create PSCredential object from Jenkins environmental variables.    
    It can be used in other scripts to get particular user to authenticate

#>
    $pass = $env:jenkinspass | ConvertTo-SecureString -AsPlainText -Force
    $Credentials = New-Object System.Management.Automation.PSCredential($env:jenkinsuser, $pass)
    return $Credentials
}
