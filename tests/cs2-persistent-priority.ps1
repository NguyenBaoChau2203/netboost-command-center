#Requires -Version 5.1
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\src\powershell\NetBoost.CS2.ps1')
$root=Join-Path ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\build'))) ('cs2-priority-tests-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($root)
$context=[pscustomobject]@{Machine='fixture';Sid='S-1-fixture';ExePath='D:\Steam\game\bin\win64\cs2.exe';HasNvidia=$false}
$prefix='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\'
$cs2=$prefix+'cs2.exe\PerfOptions';$discord=$prefix+'Discord.exe\PerfOptions'
$script:assertions=0
function Assert {param([bool]$Condition,[string]$Message) if(-not $Condition){throw $Message};$script:assertions++}
function Reset-Fake {
    $script:store=@{};$script:writes=[Collections.Generic.List[string]]::new();$script:failPath='';$script:failReadback=$false;$script:activeRoot='';$script:preparationRoot='';$script:lockOnWrite=$false;$script:ioLock=$null
}
Reset-Fake
$system=@{
    Context={param($Path,$ForRestore=$false) return $context}
    RegistryRead={param($Path,$Name)
        $key=$Path+'|'+$Name
        if($script:store.ContainsKey($key)){return $script:store[$key]}
        return [pscustomobject]@{Exists=$false;Kind='';Value=$null}
    }
    RegistryWrite={param($Path,$Name,$State)
        $script:writes.Add($Path+'|'+$Name)
        $journalRoot=if($Path.StartsWith('HKCU:\') -and $script:preparationRoot){$script:preparationRoot}else{$script:activeRoot}
        $journal=Read-NetBoostCS2Manifest $journalRoot $system
        Assert ($null -ne $journal -and @($journal.Steps|Where-Object Stage -eq 'Pending').Count -gt 0 -or $journal.Phase -eq 'Restoring') 'Every write must follow a durable journal entry.'
        $script:store[$Path+'|'+$Name]=[pscustomobject]@{Exists=$State.Exists;Kind=$State.Kind;Value=$State.Value}
        if($Path -eq $script:failPath){$script:failPath='';throw 'Injected failure after registry write.'}
        if($script:failReadback){$script:failReadback=$false;$script:store[$Path+'|'+$Name]=[pscustomobject]@{Exists=$false;Kind='';Value=$null}}
        if($script:lockOnWrite){$script:lockOnWrite=$false;$script:ioLock=[IO.File]::Open((Join-Path $script:activeRoot 'active.json'),[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)}
    }
    ProcessRead={throw 'Persistent priority must not require a running game or open protected processes.'}
    ProcessWrite={throw 'Persistent priority must never change a live process.'}
    DriverRead={throw 'Priority must be independent of NVIDIA.'}
    DriverWrite={throw 'Priority must leave the working driver preset unchanged.'}
}
$plan=Get-NetBoostCS2PriorityPlan -ExePath $context.ExePath -System $system -IncludeDiscord
Assert ($plan.Persistent -and -not $plan.BackgroundProcess -and $plan.Steps.Count -eq 2) 'Preview must describe two launch rules without a helper.'
Assert ($script:writes.Count -eq 0) 'Preview must be read only.'
Assert ($plan.Steps[0].After.Value -eq 6 -and $plan.Steps[1].After.Value -eq 5) 'CS2 must use AboveNormal and voice Discord BelowNormal.'
$script:activeRoot=Join-Path $root 'roundtrip'
$first=Set-NetBoostCS2ProcessPriority -BackupRoot $script:activeRoot -ExePath $context.ExePath -System $system -IncludeDiscord
Assert $first.Success ('Persistent priority must work with no running apps or preparation baseline: '+($first.Errors -join '; '))
$manifest=Read-NetBoostCS2Manifest $script:activeRoot $system
Assert ($manifest.Scope -eq 'ProcessPriority' -and $manifest.Phase -eq 'Applied') 'Priority must use its own typed journal.'
Assert (@($script:writes|Where-Object{$_ -notin @(($cs2+'|CpuPriorityClass'),($discord+'|CpuPriorityClass'))}).Count -eq 0) 'Only the two executable priority values may be changed; FACEIT/AC are excluded.'
$count=$script:writes.Count
$again=Set-NetBoostCS2ProcessPriority -BackupRoot $script:activeRoot -System $system -IncludeDiscord
Assert ($again.Success -and $again.AlreadyApplied -and $again.BackupPath -eq $first.BackupPath -and $script:writes.Count -eq $count) 'Repeated apply must preserve the baseline and avoid writes.'
$status=Get-NetBoostCS2PriorityStatus -BackupRoot $script:activeRoot -System $system
Assert ($status.Phase -eq 'Applied' -and $status.Persistent -and -not $status.BackgroundProcess) 'Status must identify persistent priority.'
$restored=Restore-NetBoostCS2Priority -BackupRoot $script:activeRoot -System $system
Assert $restored.Success ('Priority restore must succeed: '+($restored.Errors -join '; '))
Assert (@($script:store.Values|Where-Object Exists).Count -eq 0) 'Originally absent values must be removed.'
Assert ((Restore-NetBoostCS2Priority -BackupRoot $script:activeRoot -System $system).Success) 'Repeated restore must be idempotent.'
$next=Set-NetBoostCS2ProcessPriority -BackupRoot $script:activeRoot -System $system -IncludeDiscord
Assert ($next.Success -and $next.BackupPath -ne $first.BackupPath -and (Test-Path -LiteralPath $first.BackupPath)) 'New cycles must retain old history and capture a new baseline.'

Reset-Fake
$script:store[$cs2+'|CpuPriorityClass']=[pscustomobject]@{Exists=$true;Kind='DWord';Value=3}
$script:store[$discord+'|CpuPriorityClass']=[pscustomobject]@{Exists=$true;Kind='DWord';Value=2}
$script:activeRoot=Join-Path $root 'existing'
$result=Set-NetBoostCS2ProcessPriority -BackupRoot $script:activeRoot -System $system -IncludeDiscord
Assert $result.Success 'Existing priority settings must be backed up.'
$result=Restore-NetBoostCS2Priority -BackupRoot $script:activeRoot -System $system
Assert ($result.Success -and $script:store[$cs2+'|CpuPriorityClass'].Value -eq 3 -and $script:store[$discord+'|CpuPriorityClass'].Value -eq 2) 'Restore must return exact prior priorities, including prior High.'

Reset-Fake
$script:activeRoot=Join-Path $root 'partial';$script:failPath=$discord
$result=Set-NetBoostCS2ProcessPriority -BackupRoot $script:activeRoot -System $system -IncludeDiscord
Assert (-not $result.Success -and @($script:store.Values|Where-Object Exists).Count -eq 0) 'Failure after the second write must roll back both values.'
Reset-Fake
$script:activeRoot=Join-Path $root 'readback';$script:failReadback=$true
$result=Set-NetBoostCS2ProcessPriority -BackupRoot $script:activeRoot -System $system -IncludeDiscord
Assert (-not $result.Success -and @($script:store.Values|Where-Object Exists).Count -eq 0) 'A write without the intended readback must fail and roll back.'

Reset-Fake
$script:activeRoot=Join-Path $root 'unwritable';[void][IO.Directory]::CreateDirectory($script:activeRoot)
[IO.File]::WriteAllText((Join-Path $script:activeRoot 'backups'),'block directory creation')
$result=Set-NetBoostCS2ProcessPriority -BackupRoot $script:activeRoot -System $system -IncludeDiscord
Assert (-not $result.Success -and $script:writes.Count -eq 0) 'An unwritable baseline must prevent all changes.'

Reset-Fake
$script:activeRoot=Join-Path $root 'conflict'
$null=Set-NetBoostCS2ProcessPriority -BackupRoot $script:activeRoot -System $system -IncludeDiscord
$script:store[$discord+'|CpuPriorityClass']=[pscustomobject]@{Exists=$true;Kind='DWord';Value=2};$count=$script:writes.Count
$result=Restore-NetBoostCS2Priority -BackupRoot $script:activeRoot -System $system
Assert (-not $result.Success -and $script:writes.Count -eq $count) 'An external priority change must block restoration before any writes.'
$result=Set-NetBoostCS2ProcessPriority -BackupRoot $script:activeRoot -System $system -IncludeDiscord
Assert (-not $result.Success -and $script:writes.Count -eq $count) 'Repeat apply must not replace a conflicting original baseline.'
$script:store[$discord+'|CpuPriorityClass']=[pscustomobject]@{Exists=$true;Kind='DWord';Value=5}
$context.Sid='different-account';$result=Restore-NetBoostCS2Priority -BackupRoot $script:activeRoot -System $system
Assert (-not $result.Success -and $script:writes.Count -eq $count) 'Another account cannot supersede the shared machine-wide baseline.'
$context.Sid='S-1-fixture'

Reset-Fake
$script:activeRoot=Join-Path $root 'filtered'
$script:store[$prefix+'cs2.exe|UseFilter']=[pscustomobject]@{Exists=$true;Kind='DWord';Value=1}
$result=Set-NetBoostCS2ProcessPriority -BackupRoot $script:activeRoot -System $system -IncludeDiscord
Assert (-not $result.Success -and $script:writes.Count -eq 0) 'Existing IFEO path filtering must be refused without changing it.'
Reset-Fake
$script:activeRoot=Join-Path $root 'unexpected-kind'
$script:store[$cs2+'|CpuPriorityClass']=[pscustomobject]@{Exists=$true;Kind='String';Value='6'}
$result=Set-NetBoostCS2ProcessPriority -BackupRoot $script:activeRoot -System $system -IncludeDiscord
Assert (-not $result.Success -and $script:writes.Count -eq 0) 'Unknown existing priority data must be refused.'

Reset-Fake
$script:activeRoot=Join-Path $root 'single'
$result=Set-NetBoostCS2ProcessPriority -BackupRoot $script:activeRoot -System $system
Assert ($result.Success -and $script:writes.Count -eq 1) 'CS2-only priority must be possible without a Discord rule.'
$count=$script:writes.Count
$result=Set-NetBoostCS2ProcessPriority -BackupRoot $script:activeRoot -System $system -IncludeDiscord
Assert (-not $result.Success -and $script:writes.Count -eq $count) 'A changed target set must not silently replace an active baseline.'
$manifest=Read-NetBoostCS2Manifest $script:activeRoot $system
foreach($case in @('target','scope','value','kind')){
    $bad=$manifest|ConvertTo-Json -Depth 20|ConvertFrom-Json
    switch($case){'target'{$bad.Steps[0].Target='FACEITService'};'scope'{$bad.Scope='Anything'};'value'{$bad.Steps[0].After.Value=4};'kind'{$bad.Steps[0].Kind='Process'}}
    $rejected=$false;try{Test-NetBoostCS2Manifest $bad $context}catch{$rejected=$true}
    Assert $rejected ('Unsafe priority manifest must be refused: '+$case)
}
$manifest.Phase='Applying';$manifest.Steps[0].Stage='Pending';Save-NetBoostCS2Manifest $script:activeRoot $manifest
$result=Restore-NetBoostCS2Priority -BackupRoot $script:activeRoot -System $system
Assert ($result.Success -and -not $script:store[$cs2+'|CpuPriorityClass'].Exists) 'An interrupted pending step must be recoverable.'

Reset-Fake
$script:activeRoot=Join-Path $root 'journal-locked';$script:lockOnWrite=$true
try {
    $result=Set-NetBoostCS2ProcessPriority -BackupRoot $script:activeRoot -System $system -IncludeDiscord
    Assert (-not $result.Success -and @($script:store.Values|Where-Object Exists).Count -eq 0) 'Journal failure after a registry write must still attempt rollback from the original durable baseline.'
} finally {if($script:ioLock){$script:ioLock.Dispose();$script:ioLock=$null}}
Assert ((Restore-NetBoostCS2Priority -BackupRoot $script:activeRoot -System $system).Success) 'Recovery after the journal unlocks must finish safely.'

Reset-Fake
$script:activeRoot=Join-Path $root 'combined-priority';$script:preparationRoot=Join-Path $root 'combined-preparation'
$preparationSystem=$system.Clone();$preparationSystem.ProcessRead={param($Name) return @()}
$result=Invoke-NetBoostCS2Optimize -BackupRoot $script:preparationRoot -System $preparationSystem
Assert $result.Success 'Existing preparation must apply with its own baseline.'
$result=Set-NetBoostCS2ProcessPriority -BackupRoot $script:activeRoot -System $system -IncludeDiscord
Assert $result.Success 'Priority must coexist with an applied preparation baseline.'
$result=Restore-NetBoostCS2Priority -BackupRoot $script:activeRoot -System $system
Assert ($result.Success -and @($script:store.GetEnumerator()|Where-Object{$_.Key.StartsWith('HKCU:\') -and $_.Value.Exists}).Count -eq 3) 'Priority-only restore must preserve all applied Windows settings.'
$null=Set-NetBoostCS2ProcessPriority -BackupRoot $script:activeRoot -System $system -IncludeDiscord
$result=Restore-NetBoostCS2All -BackupRoot $script:preparationRoot -PriorityBackupRoot $script:activeRoot -System $system
Assert ($result.Success -and @($script:store.Values|Where-Object Exists).Count -eq 0) 'Combined restore must process both independent baselines.'

$rejected=$false;try{Set-NetBoostCS2MachinePriorityValue ($prefix+'FACEITService.exe\PerfOptions') 'CpuPriorityClass' ([pscustomobject]@{Exists=$true;Kind='DWord';Value=6})}catch{$rejected=$true}
Assert $rejected 'The production HKLM adapter must reject Anti-Cheat and unknown executables before writes.'
$rejected=$false;try{Set-NetBoostCS2MachinePriorityValue $cs2 'Debugger' ([pscustomobject]@{Exists=$true;Kind='String';Value='anything'})}catch{$rejected=$true}
Assert $rejected 'The production HKLM adapter must reject unrelated IFEO values.'
$live=Get-NetBoostCS2MachinePriorityValue $cs2 'CpuPriorityClass'
Assert ($live.Exists -is [bool]) 'Native-view priority adapter must support read-only access without elevation.'
@{ok=$true;assertions=$script:assertions;liveGameChanges=$false;faceitChanges=$false;backgroundProcess=$false}|ConvertTo-Json
