function Invoke-SQLquery {
    param (
        $Query,
        $FileQuery
    )
    if ($FileQuery) {
        $Output = Invoke-Sqlcmd `
            -ServerInstance $SQL_SERVER `
            -Database $SQL_DATABASE `
            -InputFile $FileQuery `
            -ErrorAction Stop
    }
    elseif ($Query) {
        $Output = Invoke-Sqlcmd `
            -ServerInstance $SQL_SERVER `
            -Database $SQL_DATABASE `
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
    $SQL_Update_Query = "UPDATE $TableName"
    $columnsToUpdate = ($Entry | Get-Member -Type NoteProperty).Name
    $columnsToUpdate = @($columnsToUpdate | Where-Object { $_ -ne $sqlPrimaryKey })
    $columnsToUpdate = @($columnsToUpdate | Where-Object { $null -ne $Entry.$_ })
    
    $setSection = "SET "
    $setSection += "$($columnsToUpdate[0]) = '$($Entry.$($columnsToUpdate[0]))'"
    for ($i = 1; $i -lt $columnsToUpdate.Count; $i++) {
        $setSection += ", $($columnsToUpdate[$i]) = '$($Entry.$($columnsToUpdate[$i]))'"
    }
    $whereSection = "WHERE $sqlPrimaryKey = '$($Entry.$sqlPrimaryKey)'"
    $SQL_Update_Query = "$SQL_Update_Query`n$setSection`n$whereSection"
    return $SQL_Update_Query
}
function Get-SQLinsertSection {
    param (
        $Entry,
        $TableName,
        $sqlPrimaryKey = $SQL_PRIMARY_KEY
    )
    $columnsToInsert = ($Entry | Get-Member -Type NoteProperty).Name

    $columnsToInsert = @($columnsToInsert | Where-Object { $_ -ne $sqlPrimaryKey })
    $columnsToInsert = @($columnsToInsert | Where-Object { $null -ne $Entry.$_ })

    $SQL_Insert_Query = "INSERT INTO $TableName ($sqlPrimaryKey"
    $valuesSection = "VALUES ('$($Entry.$sqlPrimaryKey)'"

    for ($i = 0; $i -lt $columnsToInsert.Count; $i++) {
        $SQL_Insert_Query += ", $($columnsToInsert[$i])"
        $valuesSection += ", '$($Entry.$($columnsToInsert[$i]))'"
    }
    $SQL_Insert_Query += ")"
    $valuesSection += ")"
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