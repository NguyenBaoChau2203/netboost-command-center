#Requires -Version 5.1
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$root=Join-Path $repo ('build\cs2-tests-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($root)
$module=Join-Path $repo 'src\powershell\NetBoost.CS2.ps1'
if(-not(Test-Path -LiteralPath $module)){throw 'CS2 preparation module is not implemented.'}
. $module
$script:assertions=0
function Assert {param([bool]$Condition,[string]$Message) if(-not $Condition){throw $Message};$script:assertions++}
function Reset-Fake {
    $script:store=@{}
    $script:driver=[pscustomobject]@{ProfileName='Counter-strike 2';Settings=@([pscustomobject]@{Id=274197361;Value=5;UserOverride=$false},[pscustomobject]@{Id=6600001;Value=0;UserOverride=$true})}
    $script:writes=0;$script:failTarget='';$script:processes=@();$script:partialDriver=$false;$script:denyDiscord=$false;$script:lockOnWrite=$false;$script:ioLock=$null
}
Reset-Fake
$exe=Join-Path $root 'Steam\steamapps\common\Counter-Strike Global Offensive\game\bin\win64\cs2.exe'
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($exe));[IO.File]::WriteAllText($exe,'fixture')
$context=[pscustomobject]@{Machine='fixture-machine';Sid='S-1-5-21-fixture';ExePath=$exe;HasNvidia=$true;HasIntegratedGpu=$true;ACPower=$true;CPU='fixture';GPU='NVIDIA fixture';DriverVersion='fixture'}
$system=@{
    Context={param($Path) return $context}
    RegistryRead={param($Path,$Name) $key=$Path+'|'+$Name;if($script:store.ContainsKey($key)){return $script:store[$key]};return [pscustomobject]@{Exists=$false;Kind='';Value=$null}}
    RegistryWrite={param($Path,$Name,$State) $script:writes++;if($Name -eq $script:failTarget){throw 'Injected registry failure'};$script:store[$Path+'|'+$Name]=[pscustomobject]@{Exists=$State.Exists;Kind=$State.Kind;Value=$State.Value};if($script:lockOnWrite){$script:lockOnWrite=$false;$script:ioLock=[IO.File]::Open((Join-Path $script:lockRoot 'active.json'),[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)}}
    DriverRead={param($Path) return $script:driver}
    DriverWrite={param($Path,$State) $script:writes++;if($script:partialDriver){$script:partialDriver=$false;$script:driver=[pscustomobject]@{ProfileName=$State.ProfileName;Settings=@($State.Settings[0],$script:driver.Settings[1])};throw 'Injected partial driver failure'};if($script:failTarget -eq 'Driver'){throw 'Injected driver failure'};$script:driver=$State}
    ProcessRead={param($Name) return @($script:processes|Where-Object Name -eq $Name)}
    ProcessWrite={param($Record,$Priority) if($script:denyDiscord -and $Record.Name -eq 'Discord'){throw 'Injected Discord priority denial'};$p=$script:processes|Where-Object{ $_.Id -eq $Record.Id -and $_.StartTime -eq $Record.StartTime -and $_.ExePath -eq $Record.ExePath };if($p){$p.Priority=$Priority;return $true};return $false}
}
try {
    $plan=Get-NetBoostCS2Plan -ExePath $exe -System $system
    Assert ($plan.Steps.Count -eq 4) 'Plan must contain three Windows settings and one scoped driver step.'
    Assert ($script:writes -eq 0) 'Read-only preview must not mutate configuration.'
    Assert (@($plan.Steps|Where-Object Kind -eq 'Driver').Count -eq 1) 'Plan must include a per-CS2 driver step.'
    $stateRoot=Join-Path $root 'roundtrip'
    $result=Invoke-NetBoostCS2Optimize -ExePath $exe -BackupRoot $stateRoot -System $system
    Assert $result.Success ('Apply must succeed: '+($result.Errors -join '; '))
    Assert (Test-Path -LiteralPath $result.BackupPath) 'Durable baseline must exist.'
    $manifest=Get-Content -LiteralPath $result.BackupPath -Raw|ConvertFrom-Json
    Assert ($manifest.Phase -eq 'Applied') 'Applied settings must have durable completion metadata.'
    Assert ($script:driver.Settings[0].Value -eq 1) 'CS2 must prefer maximum performance.'
    $repeat=Invoke-NetBoostCS2Optimize -ExePath $exe -BackupRoot $stateRoot -System $system
    Assert ($repeat.Success -and $repeat.BackupPath -eq $result.BackupPath) 'Repeat apply must retain the original baseline.'
    $restored=Restore-NetBoostCS2 -BackupRoot $stateRoot -System $system
    Assert $restored.Success 'Restore must succeed.'
    Assert (-not $script:driver.Settings[0].UserOverride -and $script:driver.Settings[0].Value -eq 5) 'Restore must preserve inheritance, not pin a new default.'
    Assert ($script:driver.Settings[1].UserOverride -and $script:driver.Settings[1].Value -eq 0) 'Restore must retain original explicit overrides.'
    Assert (@($script:store.Values|Where-Object Exists).Count -eq 0) 'Originally absent registry values must remain absent after restore.'
    Assert ((Restore-NetBoostCS2 -BackupRoot $stateRoot -System $system).Success) 'Repeated restore must be idempotent.'
    $cycle=Invoke-NetBoostCS2Optimize -ExePath $exe -BackupRoot $stateRoot -System $system
    Assert ($cycle.Success -and $cycle.BackupPath -ne $result.BackupPath) 'A new cycle must capture a new baseline.'
    $null=Restore-NetBoostCS2 -BackupRoot $stateRoot -System $system

    Reset-Fake
    $script:failTarget='HistoricalCaptureEnabled'
    $failure=Invoke-NetBoostCS2Optimize -ExePath $exe -BackupRoot (Join-Path $root 'rollback') -System $system
    Assert (-not $failure.Success) 'A failed step must not report success.'
    Assert (@($script:store.Values|Where-Object Exists).Count -eq 0) 'Earlier changes must roll back after a later failure.'
    $script:failTarget=''

    Reset-Fake
    $script:partialDriver=$true
    $partial=Invoke-NetBoostCS2Optimize -ExePath $exe -BackupRoot (Join-Path $root 'partial-driver') -System $system
    Assert (-not $partial.Success -and -not $script:driver.Settings[0].UserOverride) 'A partially committed driver change must roll back both known settings.'
    Assert (@($script:store.Values|Where-Object Exists).Count -eq 0) 'Driver failure must also restore earlier Windows changes.'

    Reset-Fake
    $blocked=Join-Path $root 'not-directory';[IO.File]::WriteAllText($blocked,'fixture')
    $priorPreference=$ErrorActionPreference
    try {$ErrorActionPreference='Continue';$failure=Invoke-NetBoostCS2Optimize -ExePath $exe -BackupRoot (Join-Path $blocked 'backups') -System $system} finally {$ErrorActionPreference=$priorPreference}
    Assert (-not $failure.Success -and $script:writes -eq 0) 'Unwritable backup must block all mutations.'

    Reset-Fake
    $conflictRoot=Join-Path $root 'conflict'
    $applied=Invoke-NetBoostCS2Optimize -ExePath $exe -BackupRoot $conflictRoot -System $system
    $key='HKCU:\Software\Microsoft\GameBar|AutoGameModeEnabled'
    $script:store[$key]=[pscustomobject]@{Exists=$true;Kind='DWord';Value=77}
    $writeCount=$script:writes
    $restore=Restore-NetBoostCS2 -BackupRoot $conflictRoot -System $system
    Assert (-not $restore.Success -and $script:writes -eq $writeCount) 'External-setting conflict must stop restore before any write.'
    $script:store[$key]=[pscustomobject]@{Exists=$true;Kind='DWord';Value=1}
    $context.Sid='another-user'
    Assert (-not (Restore-NetBoostCS2 -BackupRoot $conflictRoot -System $system).Success) 'Different Windows account must not restore another account baseline.'
    $context.Sid='S-1-5-21-fixture'

    $nip=Join-Path $root 'global.nip'
    [IO.File]::WriteAllText($nip,'<ArrayOfProfile><Profile><ProfileName>Base Profile</ProfileName><Executeables/><Settings><ProfileSetting><SettingID>274197361</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting></Settings></Profile></ArrayOfProfile>')
    $audit=Get-NetBoostNipAudit -Path $nip
    Assert (-not $audit.SafeToApply -and $audit.Profiles[0].Global) 'Global profiles must never be approved for CS2 import.'
    [IO.File]::WriteAllText($nip,'<?xml version="1.0" encoding="utf-16"?><ArrayOfProfile><Profile><ProfileName>Base Profile</ProfileName><Executeables/><Settings/></Profile></ArrayOfProfile>',[Text.UTF8Encoding]::new($true))
    Assert ((Get-NetBoostNipAudit -Path $nip).Profiles[0].Global) 'UTF-8 NIP files with a legacy UTF-16 declaration must remain auditable.'
    [IO.File]::WriteAllText($nip,'<!DOCTYPE x [<!ENTITY external SYSTEM "file:///C:/Windows/win.ini">]><ArrayOfProfile>&external;</ArrayOfProfile>')
    $rejected=$false;try{$null=Get-NetBoostNipAudit -Path $nip}catch{$rejected=$true}
    Assert $rejected 'External XML entities must be rejected.'

    Reset-Fake
    $processRoot=Join-Path $root 'priority'
    $null=Invoke-NetBoostCS2Optimize -ExePath $exe -BackupRoot $processRoot -System $system
    $script:processes=@([pscustomobject]@{Name='cs2';Id=1234;StartTime='2026-11-09T00:00:00Z';ExePath=$exe;Priority='Normal'},[pscustomobject]@{Name='Discord';Id=2345;StartTime='2026-11-09T00:01:00Z';ExePath='C:\Discord\Discord.exe';Priority='Normal'})
    $priority=Set-NetBoostCS2SessionPriority -BackupRoot $processRoot -System $system -IncludeDiscord
    Assert $priority.Success 'Explicit runtime priority action must work without a watcher.'
    Assert ($script:processes[0].Priority -eq 'AboveNormal' -and $script:processes[1].Priority -eq 'BelowNormal') 'Voice-only Discord priority must yield CPU to CS2.'
    $script:processes[1].StartTime='2026-11-09T01:00:00Z'
    $script:processes[1].Priority='High'
    $restored=Restore-NetBoostCS2 -BackupRoot $processRoot -System $system
    Assert ($restored.Success -and $script:processes[0].Priority -eq 'Normal') 'Original CS2 priority must be restored.'
    Assert ($script:processes[1].Priority -eq 'High') 'Reused PID must never change a new process.'

    Reset-Fake
    $denialRoot=Join-Path $root 'priority-denied'
    $null=Invoke-NetBoostCS2Optimize -ExePath $exe -BackupRoot $denialRoot -System $system
    $script:processes=@([pscustomobject]@{Name='cs2';Id=3456;StartTime='2026-11-09T00:00:00Z';ExePath=$exe;Priority='Normal'},[pscustomobject]@{Name='Discord';Id=4567;StartTime='2026-11-09T00:01:00Z';ExePath='C:\Discord\Discord.exe';Priority='Normal'})
    $script:denyDiscord=$true
    $priority=Set-NetBoostCS2SessionPriority -BackupRoot $denialRoot -System $system -IncludeDiscord
    Assert (-not $priority.Success -and $script:processes[0].Priority -eq 'Normal') 'Failure to prioritize Discord must undo the new CS2 priority change.'
    Assert ($script:driver.Settings[0].Value -eq 1) 'Runtime failure must leave the persistent preset applied.'
    $script:denyDiscord=$false

    Reset-Fake
    $script:driver.ProfileName='Base Profile'
    $unsafe=Invoke-NetBoostCS2Optimize -ExePath $exe -BackupRoot (Join-Path $root 'global-driver') -System $system
    Assert (-not $unsafe.Success -and $script:writes -eq 0) 'Base driver profile must be refused before all writes.'

    Reset-Fake
    $context.HasNvidia=$false
    $windowsOnly=Invoke-NetBoostCS2Optimize -ExePath $exe -BackupRoot (Join-Path $root 'no-nvidia') -System $system
    Assert $windowsOnly.Success 'Non-NVIDIA machines must still support the Windows preset.'
    Assert ((Restore-NetBoostCS2 -BackupRoot (Join-Path $root 'no-nvidia') -System $system).Success) 'Windows-only restore must work.'
    $context.HasNvidia=$true

    Reset-Fake
    $gpuKey='HKCU:\Software\Microsoft\DirectX\UserGpuPreferences|'+$exe
    $script:store[$gpuKey]=[pscustomobject]@{Exists=$true;Kind='String';Value='AppStatus=4096;GpuPreference=1;GpuPreference=0;CustomFlag=7;'}
    $gpuPlan=Get-NetBoostCS2Plan -ExePath $exe -System $system
    $gpuAfter=($gpuPlan.Steps|Where-Object Target -eq 'GpuPreference').After.Value
    Assert ($gpuAfter -match 'AppStatus=4096;' -and $gpuAfter -match 'CustomFlag=7;' -and $gpuAfter -match 'GpuPreference=2;' -and $gpuAfter -notmatch 'GpuPreference=1;') 'GPU preference must preserve unrelated flags.'
    Assert ([regex]::Matches($gpuAfter,'GpuPreference=').Count -eq 1) 'GPU preference must not retain duplicate conflicting values.'

    Reset-Fake
    $script:lockRoot=Join-Path $root 'bookkeeping-locked';$script:lockOnWrite=$true
    try {
        $failed=Invoke-NetBoostCS2Optimize -ExePath $exe -BackupRoot $script:lockRoot -System $system
        Assert (-not $failed.Success -and @($script:store.Values|Where-Object Exists).Count -eq 0) 'Failed completion journal must still attempt rollback using the durable baseline.'
    } finally {if($script:ioLock){$script:ioLock.Dispose();$script:ioLock=$null}}
    Assert ((Restore-NetBoostCS2 -BackupRoot $script:lockRoot -System $system).Success) 'Recovery must complete after the journal becomes writable.'

    Reset-Fake
    $corruptRoot=Join-Path $root 'typed-driver'
    $null=Invoke-NetBoostCS2Optimize -ExePath $exe -BackupRoot $corruptRoot -System $system
    $bad=Get-Content -LiteralPath (Join-Path $corruptRoot 'active.json') -Raw|ConvertFrom-Json
    ($bad.Steps|Where-Object Kind -eq 'Driver').Before.Settings[0].Value=1.5
    Write-NetBoostJsonFile -Path (Join-Path $corruptRoot 'active.json') -Value $bad
    $writesBefore=$script:writes
    Assert (-not (Restore-NetBoostCS2 -BackupRoot $corruptRoot -System $system).Success -and $script:writes -eq $writesBefore) 'Non-integral driver backups must be rejected before restore.'

    Reset-Fake
    $lockedRoot=Join-Path $root 'exclusive-lock';[void][IO.Directory]::CreateDirectory($lockedRoot)
    $lock=[IO.File]::Open((Join-Path $lockedRoot 'transaction.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    try { Assert (-not (Invoke-NetBoostCS2Optimize -ExePath $exe -BackupRoot $lockedRoot -System $system).Success -and $script:writes -eq 0) 'Concurrent operation must not mutate state.' } finally {$lock.Dispose()}
} finally {
    $resolved=[IO.Path]::GetFullPath($root)
    if(-not $resolved.StartsWith($repo+'\build\cs2-tests-',[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe fixture cleanup'}
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
@{ok=$true;assertions=$script:assertions;systemChanges=$false}|ConvertTo-Json
