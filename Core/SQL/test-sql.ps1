
Import-Module "./Core/Import-AllModules.psm1"
$Query = "SELECT
DNSHostName,
IPaddress 
FROM Inventory
WHERE isActive=1"
$Credentials = Get-CredentialFromJenkins
Invoke-SQLquery -Query $Query -credential $Credentials

# $INSER_QUERY = "INSERT INTO Inventory (DNSHostName, Error, IPaddress, isActiveWinRM, isActiveTCP, isActive, LastUpdate, LastSeen)
# VALUES ('Lian6700.Horna.local', 'TEST INSERT', '2.2.2.2', 'FALSE', 'FALSE', 'FALSE', '', '')"
$Entry = [PSCustomObject]@{
    'DNSHostName'   = "testowy komp"
    'IPaddress'     = "1.1.1.1"
    'isActiveWinRM' = $false
    'isActiveTCP'   = $false
    'isActive'      = $false
    'LastUpdate'    = ""
    'LastSeen'      = ""
    'Error'         = "Wczoraj"
}
# try {
#     Invoke-SQLquery -Query $INSER_QUERY -credential $Credentials
# }
# catch {
#     <#Do this if a terminating exception happens#>
# }

$q = Get-SQLdataUpdateQuery -Entry $Entry -TableName "Inventory"
$q
#Invoke-SQLquery -Query $q -credential $Credentials
# $SQLServ = "Server-Automation" 
# $DB = "Device_Monitoring"
# Invoke-Sqlcmd `
# -Username $env:jenkinsuser `
# -Password $env:jenkinspass `
# -ServerInstance $SQLServ `
# -Database $DB `
# -InputFile .\Core\SQL\ActiveDevices.sql 