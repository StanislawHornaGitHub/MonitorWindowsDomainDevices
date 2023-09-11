<#
.SYNOPSIS
    Module with functions related to the communication with SQL Server

.DESCRIPTION
    Module consists of functions to check the availability of Server,
    invoke SQL queries and build them in adequate manner.
    Some of them are created only to simplify the code inside of this module and they are not used anywhere else.

    It contain following functions:
        - Invoke-SQLquery - Basic function to invoke query passed as a string or read out from file
        - Get-SQLdataUpdateQuery - Complex function responsible for creating SQL queries,
                                   mostly related to the object tables in the Database.
        - Get-SQLupdateSection - used to create simple UPDATE query to specified table and entry,
                                 which is passed as PSCustomObject
        - Get-SQLinsertSection - used to create simple INSERT query to specified table and entry,
                                 whcih is passed as PSCustomObject, mostly used for Event tables.
        - Test-SQLserverAvailability - function dedicated for Process Coordinator to check if the SQL Server is running
                                       and ready to execute queries.

.NOTES

    Version:            1.0
    Author:             Stanisław Horna
    Mail:               stanislawhorna@outlook.com
    GitHub Repository:  https://github.com/StanislawHornaGitHub/MonitorWindowsDomainDevices
    Creation Date:      16-Aug-2023
    ChangeLog:

    Date            Who                     What

#>
function Invoke-SQLquery {
    param (
        $Query,
        $FileQuery,
        $SQLDBName = $SQL_DATABASE
    )
    if ($FileQuery) {
        $Output = Invoke-Sqlcmd `
            -ServerInstance $SQL_SERVER `
            -Database $SQLDBName `
            -InputFile $FileQuery `
            -ErrorAction Stop
    }
    elseif ($Query) {
        $Output = Invoke-Sqlcmd `
            -ServerInstance $SQL_SERVER `
            -Database $SQLDBName `
            -Query $Query `
            -ErrorAction Stop
    }
    else {
        Write-Error -Message "No SQL query to proceed"
        return $null
    }
    return $Output
}
function Get-SQLdataUpdateQuery {
    param (
        $Entry,
        $TableName,
        $sqlPrimaryKey = $SQL_PRIMARY_KEY
    )

    # Create UPDATE row SQL Query
    $SQL_Update_Query = Get-SQLupdateSection -Entry $Entry `
        -TableName $TableName `
        -sqlPrimaryKey $sqlPrimaryKey
    # Create INSERT row SQL Query
    $SQL_Insert_Query = Get-SQLinsertSection -Entry $Entry `
        -TableName $TableName `
        -sqlPrimaryKey $sqlPrimaryKey
    # Different approach depending on whether the Object table has corresponding Change Log table or not 
    if ($TableName -notin $SQL_OBJECT_TABLES_WITHOUT_CHANGE_LOG) {
        # Create INSERT CHANGE LOG SQL Query
        $SQL_Insert_Log_Query = Get-SQLinsertSection -Entry $Entry `
            -TableName "$($SQL_LOG_TABLE_PREFIX)$TableName" `
            -sqlPrimaryKey $sqlPrimaryKey
        # Exclude defined columns from comparison
        $ColumnsToCompare = $Entry.PSObject.Properties.Name | Where-Object { $_ -notin $COLUMNS_EXCLUDED_FROM_COMPARISON }
        $ColumnsToCompare = $ColumnsToCompare -join ", "
        # Load Object Data SQL Query template
        $SQL_Query_Template = Get-Content -Path $SQL_WRITE_TABLE_DATA_WITH_CHANGE_LOG_TEMPLATE -Raw
        # Put columns to compare to the template
        $SQL_Query_Template = $SQL_Query_Template.Replace("COLUMNS_TO_COMPARE_DURING_UPDATE_VARIABLE", $ColumnsToCompare)
        # Put INSERT CHANGE LOG sub query to the template
        $SQL_Query_Template = $SQL_Query_Template.Replace("INSERT_LOG_QUERY_BLOCK_VARIABLE", $SQL_Insert_Log_Query)
        if($TableName -in $TABLES_WHERE_TEMP_NAME_USE_DNSHOSTNAME){
            $tempTableName = "$($TableName)_$($Entry.'DNSHostName')"
        }else{
            $tempTableName = "$($TableName)_$($Entry.$sqlPrimaryKey)"
        }
        $tempTableName = $tempTableName.Replace("-", "_")
        $tempTableName = $tempTableName.Replace(".", "_")
        # Trim tempTableName to 109, because the lenght limit is 116, but each name starts with "#Temp_"
        $tempTableName = $tempTableName[0..109] -join "" 
        $SQL_Query_Template = $SQL_Query_Template.Replace("TABLE_TEMPORARY_NAME_VARIABLE", $tempTableName)
    }
    else {
        # Load Object Data SQL Query template
        $SQL_Query_Template = Get-Content -Path $SQL_WRITE_TABLE_DATA_TEMPLATE -Raw
    }
    # Put entry identity column name to the template
    $SQL_Query_Template = $SQL_Query_Template.Replace("PRIMARY_KEY_VARIABLE", $sqlPrimaryKey)
    # Put table name to the template
    $SQL_Query_Template = $SQL_Query_Template.Replace("TABLE_NAME_VARIABLE", $TableName)
    # Put entry identity value to the template
    $SQL_Query_Template = $SQL_Query_Template.Replace("COMPUTER_DNS_HOSTNAME_VARIABLE", $($Entry.$sqlPrimaryKey))
    # Put UPDATE sub query to the template
    $SQL_Query_Template = $SQL_Query_Template.Replace("UPDATE_QUERY_BLOCK_VARIABLE", $SQL_Update_Query)
    # Put INSERT sub query to the template
    $SQL_Query_Template = $SQL_Query_Template.Replace("INSERT_QUERY_BLOCK_VARIABLE", $SQL_Insert_Query)

    return $SQL_Query_Template
}
function Get-SQLupdateSection {
    param (
        $Entry,
        $TableName,
        $sqlPrimaryKey = $SQL_PRIMARY_KEY
    )
    # Provide UPDATE statement
    $SQL_Update_Query = "UPDATE $TableName"
    # Get Column names to update
    $columnsToUpdate = ($Entry | Get-Member -Type NoteProperty).Name
    # Exclude Primary Key from coulms to update set
    $columnsToUpdate = @($columnsToUpdate | Where-Object { $_ -ne $sqlPrimaryKey })
    # Exclude columns which are nulls from update
    $columnsToUpdate = @($columnsToUpdate | Where-Object { $null -ne $Entry.$_ })
    # Provide SET statement
    $setSection = "SET "
    # Write each column name with value to push
    $setSection += "$($columnsToUpdate[0]) = '$($Entry.$($columnsToUpdate[0]))'"
    for ($i = 1; $i -lt $columnsToUpdate.Count; $i++) {
        $setSection += ", $($columnsToUpdate[$i]) = '$($Entry.$($columnsToUpdate[$i]))'"
    }
    # Provide condition which row will be updated
    $whereSection = "WHERE $sqlPrimaryKey = '$($Entry.$sqlPrimaryKey)'"
    # Merge all sections into one query
    $SQL_Update_Query = "$SQL_Update_Query`n$setSection`n$whereSection"
    return $SQL_Update_Query
}
function Get-SQLinsertSection {
    param (
        $Entry,
        $TableName,
        $sqlPrimaryKey = $SQL_PRIMARY_KEY
    )
    # Get columns to insert
    $columnsToInsert = ($Entry | Get-Member -Type NoteProperty).Name
    # Exclude Primary Key from coulms to insert set
    $columnsToInsert = @($columnsToInsert | Where-Object { $_ -ne $sqlPrimaryKey })
    # Exclude columns which are nulls from insert
    $columnsToInsert = @($columnsToInsert | Where-Object { $null -ne $Entry.$_ })
    # Provide INSERT INTO statement
    $SQL_Insert_Query = "INSERT INTO $TableName ($sqlPrimaryKey"
    # Write each column name and value to insert in a correct order
    $valuesSection = "VALUES ('$($Entry.$sqlPrimaryKey)'"
    for ($i = 0; $i -lt $columnsToInsert.Count; $i++) {
        $SQL_Insert_Query += ", $($columnsToInsert[$i])"
        $valuesSection += ", '$($Entry.$($columnsToInsert[$i]))'"
    }
    # Close statement brackets
    $SQL_Insert_Query += ")"
    $valuesSection += ")"
    # Merge all sections into one query
    $SQL_Insert_Query = "$SQL_Insert_Query`n$valuesSection"
    return $SQL_Insert_Query
}
function Test-SQLserverAvailability {
    param(
        [bool]$BypassEmptyInventory = $false
    )
    try {
        $Output = Invoke-SQLquery -Query "SELECT * FROM $SQL_INVENTORY_TABLE_NAME"
    }
    catch {
        Write-Log -Message $_ -Type "error" -Path $PROCESS_COORDINATOR_LOG_PATH
        return $false
    }
    if (($null -eq $Output) -and ($BypassEmptyInventory -eq $false)) {
        Write-Log -Message "Inventory is empty" -Type "error" -Path $PROCESS_COORDINATOR_LOG_PATH
        return $false
    }
    return $true
}