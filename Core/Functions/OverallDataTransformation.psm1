function Export-HashTableToCsv {
	<#
.SYNOPSIS
Converts Hashtable to csv

.DESCRIPTION
Converts hashtable to csv format, works with hash where value is 1 dimmension array,
result can be saved to file or variable

.PARAMETER Hashtable
Hashtable which will be converted

.PARAMETER Headers
Array of headers in an specified order

.PARAMETER Path
Specify only if result should be save to file

.EXAMPLE
$csv = Export-HashTableToCsv -Hashtable $hash `
	-Headers @("Device name", "Average process count", "CPU time") | ConvertFrom-Csv


.INPUTS
Hashtable
Array

.OUTPUTS
PSCustomObject

.NOTES
    Author:  Stanislaw Horna
#>
	param (
		[Parameter(Mandatory = $true)]
		[System.Collections.Hashtable]$Hashtable,
		[Parameter(Mandatory = $true)]
		$Headers,
		[Parameter(Mandatory = $false)]
		[String]$Path
	)

	$out = "`"" + $Headers[0] + "`","
	for ($i = 1; $i -lt $Headers.Count - 1; $i++) {
		$out = $out + "`"" + $Headers[$i] + "`"," 
	}
	$out = $out + "`"" + $Headers[($Headers.Count) - 1] + "`""
	if ($Path) {
		Set-Content -Path $Path -Value $out
		foreach ($item in $Hashtable.Keys) {
			$out = "`"" + $item + "`","
			for ($i = 0; $i -lt (($Hashtable.$item.Count) - 1); $i++) {
				$out = $out + "`"" + $Hashtable.$item[$i] + "`","
			}
			$out = $out + "`"" + $Hashtable.$item[($Hashtable.$item.Count) - 1] + "`""
			Add-content $Path $out
			# $out
		}
	}
	else {
		$out = $out + "`n"
		foreach ($item in $Hashtable.Keys) {
			$out = $out + "`"" + $item + "`","
			for ($i = 0; $i -lt (($Hashtable.$item.Count) - 1); $i++) {
				$out = $out + "`"" + $Hashtable.$item[$i] + "`","
			}
			$out = $out + "`"" + $Hashtable.$item[($Hashtable.$item.Count) - 1] + "`"`n"
			# Add-content $Path $out

		}
		$out | ConvertFrom-Csv
	}

}
function Invoke-HashTableSort {
	<#
.SYNOPSIS
Returns sorted hashtable.

.DESCRIPTION
Sorts hash table that contains array in value and returns new one.

.PARAMETER Hashtable
Hastable to sort

.PARAMETER Value_index
Index of value located in array by which entries will be sorted

.PARAMETER Descending
If included values will be sorted descending otherwise ascending

.EXAMPLE


.OUTPUTS
Hashtable

.NOTES
    Author:  Stanislaw Horna
#>
	param (
		[Parameter(Mandatory = $true)]
		[System.Collections.Hashtable]$Hashtable,
		[Parameter(Mandatory = $false)]
		[int]$Value_index,
		[Parameter(Mandatory = $false)]
		[switch]$Descending
	)
	if ($Value_index) {
		if ($Descending) {
			$hashSorted = [ordered] @{}
			$Hashtable.GetEnumerator() | Sort-Object { $_.Value[$Value_index] } -Descending | ForEach-Object { $hashSorted[$_.Key] = $_.Value }
		}
		else {
			$hashSorted = [ordered] @{}
			$Hashtable.GetEnumerator() | Sort-Object { $_.Value[$Value_index] } | ForEach-Object { $hashSorted[$_.Key] = $_.Value }
		}
	}
	else {
		if ($Descending) {
			$hashSorted = [ordered] @{}
			$Hashtable.GetEnumerator() | Sort-Object { $_.Value } -Descending | ForEach-Object { $hashSorted[$_.Key] = $_.Value }
		}
		else {
			$hashSorted = [ordered] @{}
			$Hashtable.GetEnumerator() | Sort-Object { $_.Value } | ForEach-Object { $hashSorted[$_.Key] = $_.Value }
		}
	}
	$hashSorted
}
function Remove-Duplicates {
	<#
.SYNOPSIS
Remove duplicates - work the same as Excel function

.DESCRIPTION
Group entries by given column, sort by given column and select first result from sorting

.PARAMETER SourceTable
Csv imported table

.PARAMETER ColumnNameGroup
Column name where only unique values should remain

.PARAMETER ColumnNameSort
Column name by which values should be sorted befor removing duplicated vaules
Can be empty

.PARAMETER DateTime
Select if ColumnNameSort should be sorted as date time

.EXAMPLE



.INPUTS


.OUTPUTS
PSCustomObject

.NOTES
    Author:  Stanislaw Horna
			 Pawel Bielinski
#>
	param (
		[Parameter(Mandatory = $true)]
		$SourceTable,
		[Parameter(Mandatory = $true)]
		[String]$ColumnNameGroup,
		[Parameter(Mandatory = $false)]
		[String]$ColumnNameSort,
		[Parameter(Mandatory = $false)]
		[switch]$Descending,
		[Parameter(Mandatory = $false)]
		[switch]$DateTime,
		[Parameter(Mandatory = $false)]
		[switch]$HashTable
	)
	$Hash = @{}
	$ErrorActionPreference = 'SilentlyContinue'
	Switch ($true) {
		($ColumnNameSort -and $DateTime -and $Descending) {
			$SourceTable | Sort-Object -property { [System.DateTime]::ParseExact($_.$ColumnNameSort, "yyyy-MM-dd'T'HH:mm:ss", $null) } -Descending `
			| ForEach-Object {
				if (-not($Hash.ContainsKey($_.$ColumnNameGroup))) {
					$Hash.Add($_.$ColumnNameGroup, $_)
				}
			}
		}
		($ColumnNameSort -and $DateTime) {
			$SourceTable | Sort-Object -property { [System.DateTime]::ParseExact($_.$ColumnNameSort, "yyyy-MM-dd'T'HH:mm:ss", $null) } `
			| ForEach-Object {
				if (-not($Hash.ContainsKey($_.$ColumnNameGroup))) {
					$Hash.Add($_.$ColumnNameGroup, $_)
				}
			}
		}
		($ColumnNameSort -and $Descending) {
			$SourceTable | Sort-Object -property $ColumnNameSort -Descending `
			| ForEach-Object {
				if (-not($Hash.ContainsKey($_.$ColumnNameGroup))) {
					$Hash.Add($_.$ColumnNameGroup, $_)
				}
			}
		}
		($ColumnNameSort) {
			$SourceTable | Sort-Object -property $ColumnNameSort -Descending `
			| ForEach-Object {
				if (-not($Hash.ContainsKey($_.$ColumnNameGroup))) {
					$Hash.Add($_.$ColumnNameGroup, $_)
				}
			}
		}
		Default {
			$SourceTable  `
			| ForEach-Object {
				if (-not($Hash.ContainsKey($_.$ColumnNameGroup))) {
					$Hash.Add($_.$ColumnNameGroup, $_)
				}
			}
		}

	}
	$ErrorActionPreference = 'Continue'
	if ($HashTable) {
		$Hash
	}
	else {
		$Hash.Values
	}
}
function New-SummaryAverage {
	<#
.SYNOPSIS
Creates data summary in Hashtable

.DESCRIPTION
Creates summary like Excel pivot table, based on table provided and selected columns

.PARAMETER SourceTable
Source data table

.PARAMETER RowsColumn
Simmilar to Excel PivotTable column, on which rows are created 

.PARAMETER AverageColumn
Vaule which is needed as a average for each unique value from RowsColumn

.INPUTS
Table
String

.OUTPUTS
Hashtable

.NOTES
    Author:  Stanislaw Horna
#>
	param (
		[Parameter(Mandatory = $true)]
		$SourceTable,
		[Parameter(Mandatory = $true)]
		[String]$RowsColumn,
		[Parameter(Mandatory = $true)]
		[String]$AverageColumn,
		[Parameter(Mandatory = $false)]
		[switch]$CsvFormat,
		[Parameter(Mandatory = $false)]
		$Headers
	)
	$hash_all = @{}
	for ($j = 0; $j -lt $SourceTable.Count; $j++) {
		# Get category name and extract stats as array (miliseconds)
		$RowName = $SourceTable[$j].$RowsColumn
		if (($RowName -ne "-") -and ($RowName.length -gt 2)) {
		
			$RowStats = $SourceTable[$j].$AverageColumn
			# If category was listed multiple times on one device sum time but do not increment number of devices
			if ($RowName -in $hash_all.Keys) {
				$hash_all.$RowName[0] += [int]$RowStats
				$hash_all.$RowName[1]++
			}
			else {
				$hash_all.Add($RowName, @([int]$RowStats, 1))
			}
		}
	}
	foreach ($Item in $hash_all.Keys) {
		$hash_all.$Item[0] = [math]::Round((($hash_all.$Item[0] / $hash_all.$Item[1])), 3)
	}
	if ($CsvFormat) {
		if ($null -eq $Headers) {
			$Count = "Average of " + $RowsColumn
			$Headers = @($RowsColumn, $Count, 'Count')
		}
		if ($ReferenceTable) {
			Export-HashTableToCsv -Hashtable $hash_all -Headers $Headers | `
				Sort-Object { [double]$_.($Headers[2]) } -Descending
		}
		else {
			Export-HashTableToCsv -Hashtable $hash_all -Headers $Headers | `
				Sort-Object { [int]$_.($Headers[1]) } -Descending
		}
	}
	else {
		$hash_all
	}
}
function New-SummaryCount {
	<#
.SYNOPSIS
Creates data summary in Hashtable

.DESCRIPTION
Creates summary like Excel pivot table, based on table provided and selected columns

.PARAMETER SourceTable
Source data table

.PARAMETER RowsColumn
Simmilar to Excel PivotTable column, on which rows are created 

.PARAMETER AverageColumn
Vaule which is needed as a average for each unique value from RowsColumn

.INPUTS
Table
String

.OUTPUTS
Hashtable

.NOTES
    Author:  Stanislaw Horna
#>
	param (
		[Parameter(Mandatory = $true)]
		$SourceTable,
		[Parameter(Mandatory = $true)]
		[String]$RowsColumn,
		[Parameter(Mandatory = $false)]
		$ReferenceTable,
		[Parameter(Mandatory = $false)]
		[switch]$CsvFormat,
		[Parameter(Mandatory = $false)]
		$Headers,
		[Parameter(Mandatory = $false)]
		[switch]$GrandTotal
	)
	$hash_all = @{}
	for ($j = 0; $j -lt $SourceTable.Count; $j++) {
		# Get category name and extract stats as array (miliseconds)
		$RowName = $SourceTable[$j].$RowsColumn
		if (($RowName -ne "-") -and ($RowName.length -gt 0)) {
			# If category was listed multiple times on one device sum time but do not increment number of devices
			if ($RowName -in $hash_all.Keys) {
				$hash_all.$RowName[0]++
			}
			else {
				$hash_all.Add($RowName, @(1, 1))
			}
		}
	}
	$CountOfGrand = 0
	if ($ReferenceTable) {
		foreach ($Item in $hash_all.Keys) {
			[int]$CountOfGrand += $hash_all.$Item[0]
			$RefCounter = 0
			for ($i = 0; $i -lt $ReferenceTable.Count; $i++) {
				$RowName = $ReferenceTable[$i].$RowsColumn
				if ($RowName -eq $Item) {
					$RefCounter++
				}
			}
			$hash_all.$Item[1] = [math]::Round((($hash_all.$Item[0] / $RefCounter)), 4)
		}
		if ($GrandTotal) {
			$hash_all.Add("Grand Total", @($CountOfGrand , $CountOfGrand))
			$hash_all.'Grand Total'[1] = [math]::Round(($hash_all.'Grand Total'[1] / ($ReferenceTable.count)), 4)
		}
	}
	else {
		foreach ($Item in $hash_all.Keys) {
			$CountOfGrand += $hash_all.$Item[0]
			$hash_all.$Item[1] = [math]::Round((($hash_all.$Item[0] / $SourceTable.Count)), 4)
		}
		if ($GrandTotal) {
			$hash_all.Add("Grand Total", @($CountOfGrand , 1))
		}
	}

	if ($CsvFormat) {
		if ($null -eq $Headers) {
			$Count = "Count of " + $RowsColumn
			$Headers = @($RowsColumn, $Count, '%')
		}
		if ($ReferenceTable) {
			Export-HashTableToCsv -Hashtable $hash_all -Headers $Headers | `
				Sort-Object { [double]$_.($Headers[2]) } -Descending
		}
		else {
			Export-HashTableToCsv -Hashtable $hash_all -Headers $Headers | `
				Sort-Object { [int]$_.($Headers[1]) }
		}
	}
	else {
		$hash_all
	}
	
}
function Convert-CsvToHash {
	param (
		$SourceTable,
		$ColumnNameGroup
	)
	$Output = @{}
	$SourceTable | ForEach-Object {
		$thisLine = $_
        $Key = $_.$ColumnNameGroup
		try {
			$Output.$Key.Add($thisLine) | Out-Null
		}
		catch {
			$Output.Add($Key,(New-Object System.Collections.ArrayList))
            $Output.$Key.Add($thisLine) | Out-Null
		}
	}
	return $Output
}