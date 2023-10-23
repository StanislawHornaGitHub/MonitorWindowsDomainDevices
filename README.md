# MonitorWindowsDomainDevices

Open Monitoring system gathering data from Windows Domain joined devices.

Technologies used:

- **Windows Powershell** (PS Remoting for collecting data)
- **Microsoft SQL** (Collected data storage)
- **Windows Task Scheduler** (Responsible for keeping main process running)
- **Active Directory** (Access authorization to collect data)

## The main advantage of designed model is scalability and clientless.

**Scalability** - Each Powershell script can be invoked on a different Process Server which will connect to the active end-points, gather data and push it to the common for each Process Server SQL Database.

**Clientless** - You do not have to install any client or additional software on the end-point which you would like to monitor. Everything is covered by built in Windows Operating System functionalities (Some of them are disabled by default, however when it comes to the Active Directory we can use Group Policies to enable them)

```mermaid
    graph
    AD_Domain_Controller <-->|LDAP| SQL_Server;
    AD_Domain_Controller <-->|LDAP| Process_Server;
    AD_Domain_Controller <-->|LDAP| Group_of_end_point_devices;
    SQL_Server <-->|SQL| Process_Server;
    Process_Server <--> |Powershell| Group_of_end_point_devices;
```

End points do not require access to the SQL Server itself, so it can be hidden under separate Network / Access layer for security purposes.

# How it works

On each Process Server there is Powershell script running constantly (Process_Coordinator) (kept up by Task Scheduler), which is invoking appropriate scripts in Background jobs, according to the refresh interval defined in Config.json file and information about last execution time for particular script stored in SQL dedicated table.

In most cases when script is run as a Background job it will create next child background jobs, one for each device to take the advantage of multi cores systems and reduce execution time as well.

When all jobs which should be run at current loop iteration were started the Process_Coordinator is starting the sleep until any script requires new invocation.

For more details about Process_Coordinator.ps1 operations read [Description](/Docs/Process_Coordinator.md).

# Data model

There are 2 main categories of collected data:

- **Objects** - for example list of devices, where each device has own properties such like Device model, CPU model, amount of RAM memory. When the information is updated in these tables, it is also verified if anything changed comparing to previous update. If there are some differences, old set of values is inserted to the corresponding table with prefix "ChangeLog_". 
- **Events** - for example CPU Temperature measurement. Each execution will produce new entries to the database which will tell us about the value recorded at a given time.
