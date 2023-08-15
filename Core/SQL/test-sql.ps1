$SQLServ = "Server-Automation" 
$DB = "Device_Monitoring"
Invoke-Sqlcmd -Username $env:jenkinsuser -Password $env:jenkinspass -ServerInstance $SQLServ -Database $DB -InputFile .\Core\SQL\ActiveDevices.sql 