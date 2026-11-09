#Requires -Version 5.1
$ErrorActionPreference='Stop'
Add-Type -Path (Join-Path $PSScriptRoot '..\src\native\NetBoost.NvidiaDrs.cs')
[NetBoost.NvidiaDrs]::ValidateApplicationNames([string[]]@('cs2.exe','csgos2.exe'))
$assertions=1
foreach($applications in @(@('cs2.exe','other-game.exe'),@('discord.exe'),@())){
    $rejected=$false
    try{[NetBoost.NvidiaDrs]::ValidateApplicationNames([string[]]$applications)}catch{$rejected=$true}
    if(-not $rejected){throw 'Shared or empty NVIDIA profiles must be refused.'};$assertions++
}
@{ok=$true;assertions=$assertions;driverChanges=$false}|ConvertTo-Json
