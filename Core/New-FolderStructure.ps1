<#
    .DESCRIPTION
    Script to initialize folder structure required to categorize tables

#>
New-Variable -Name "ROOT_DIRECTORY" -Value "./DataBase" -Force -Scope Script -Option ReadOnly
New-Variable -Name "OBJECT_DIRECTORY" -Value "$ROOT_DIRECTORY/Object" -Force -Scope Script -Option ReadOnly
New-Variable -Name "EVENT_DIRECTORY" -Value "$ROOT_DIRECTORY/Event" -Force -Scope Script -Option ReadOnly
New-Variable -Name "TEMP_DIRECTORY" -Value "$ROOT_DIRECTORY/Temp" -Force -Scope Script -Option ReadOnly
function Invoke-Main {
    New-DataBaseStructure
}

function New-DataBaseStructure {
    if(-not $(Test-Path -Path $ROOT_DIRECTORY)){
        New-Item -Type Directory -Path $ROOT_DIRECTORY | Out-Null
    }
    if(-not $(Test-Path -Path $OBJECT_DIRECTORY)){
        New-Item -Type Directory -Path $OBJECT_DIRECTORY | Out-Null
    }
    if(-not $(Test-Path -Path $EVENT_DIRECTORY)){
        New-Item -Type Directory -Path $EVENT_DIRECTORY | Out-Null
    }
    if(-not $(Test-Path -Path $TEMP_DIRECTORY)){
        New-Item -Type Directory -Path $TEMP_DIRECTORY | Out-Null
    }
}

Invoke-Main