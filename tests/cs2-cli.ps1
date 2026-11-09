#Requires -Version 5.1
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$entry=Join-Path $repo 'src\powershell\NetBoost_Command_Center.ps1'
. $entry --help|Out-Null
$script:assertions=0
function Assert {param([bool]$Condition,[string]$Message) if(-not $Condition){throw $Message};$script:assertions++}
foreach($flag in @('--cs2','--cs2-status','--cs2-plan','--cs2-optimize','--cs2-restore','--cs2-priority','--cs2-priority-plan','--cs2-priority-restore')){
    $RawArgs=@($flag);$parsed=Parse-Args
    Assert ($parsed.Mode -ne 'Invalid' -and $parsed.Mode -ne 'Menu') "Unrecognized CS2 flag: $flag"
}
$RawArgs=@('--cs2-plan','--cs2-exe','D:\Games with spaces\game\bin\win64\cs2.exe');$parsed=Parse-Args
Assert ($parsed.CS2Exe -ceq $RawArgs[2]) 'CS2 executable with spaces must survive parsing.'
$RawArgs=@('--cs2-plan','--cs2-exe');$parsed=Parse-Args
Assert ($parsed.Mode -eq 'Invalid') 'Missing executable argument must be rejected.'
$RawArgs=@('--cs2-audit-profile');$parsed=Parse-Args
Assert ($parsed.Mode -eq 'Invalid') 'Missing NIP path must be rejected.'
$RawArgs=@('--cs2-plan','--cs2-optimize');$parsed=Parse-Args
Assert ($parsed.Mode -eq 'Invalid') 'Conflicting read-only and mutating CS2 actions must be rejected.'
$RawArgs=@('--cs2-plan','--google');$parsed=Parse-Args
Assert ($parsed.Mode -eq 'Invalid') 'A read-only CS2 request must not accidentally dispatch a DNS change.'
Assert ($T.ContainsKey('Menu21')) 'Both languages need a CS2 menu label.'
function Ensure-Admin {}
$script:routed=$false;$script:answers=[Collections.Generic.Queue[string]]::new();$script:answers.Enqueue('21');$script:answers.Enqueue('0')
Show-Menu -InputReader {$script:answers.Dequeue()} -CS2Center {$script:routed=$true}
Assert $script:routed 'Main menu 21 must route to the CS2 center.'
$script:priorityCalls=0;$script:priorityRestores=0
function Get-NetBoostCS2PriorityPlan {param($ExePath,[switch]$IncludeDiscord) return [pscustomobject]@{Context=[pscustomobject]@{ExePath='fixture';CPU='fixture';GPU='fixture';DriverVersion='fixture';ACPower=$true};Scope='ProcessPriority';Steps=@()}}
function Set-NetBoostCS2ProcessPriority {param($ExePath,[switch]$IncludeDiscord) if(-not $IncludeDiscord){throw 'Voice-only Discord rule missing.'};$script:priorityCalls++;return [pscustomobject]@{Success=$true;Errors=@();BackupPath='fixture'}}
function Restore-NetBoostCS2Priority {$script:priorityRestores++;return [pscustomobject]@{Success=$true;Errors=@();BackupPath='fixture'}}
$script:answers=[Collections.Generic.Queue[string]]::new();foreach($answer in @('4','CANCEL','0')){$script:answers.Enqueue($answer)}
Show-NetBoostCS2Center -InputReader {$script:answers.Dequeue()}
Assert ($script:priorityCalls -eq 0) 'Persistent priority must require APPLY confirmation before mutations.'
$script:answers=[Collections.Generic.Queue[string]]::new();foreach($answer in @('4','APPLY','7','0')){$script:answers.Enqueue($answer)}
Show-NetBoostCS2Center -InputReader {$script:answers.Dequeue()}
Assert ($script:priorityCalls -eq 1 -and $script:priorityRestores -eq 1) 'Menu 4 must enable launch rules and menu 7 must independently restore them.'
@{ok=$true;assertions=$script:assertions;systemChanges=$false}|ConvertTo-Json
