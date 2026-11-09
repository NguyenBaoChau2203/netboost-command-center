#Requires -Version 5.1
# Launch rules only. No process watcher, service, task or Anti-Cheat changes.
function Get-NetBoostCS2PriorityDefinitions {
    $prefix='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\'
    return @(
        [pscustomobject]@{Target='CS2LaunchPriority';Path=$prefix+'cs2.exe\PerfOptions';Name='CpuPriorityClass';Value=6;Kind='DWord'},
        [pscustomobject]@{Target='DiscordLaunchPriority';Path=$prefix+'Discord.exe\PerfOptions';Name='CpuPriorityClass';Value=5;Kind='DWord'}
    )
}
function Get-NetBoostCS2ManifestDefinitions {
    param($Manifest)
    if($Manifest.Scope -eq 'ProcessPriority'){return @(Get-NetBoostCS2PriorityDefinitions)}
    if($Manifest.PSObject.Properties.Name -contains 'Scope'){throw 'Unknown CS2 backup scope.'}
    return @(Get-NetBoostCS2Definitions $Manifest.Context)
}
function Test-NetBoostCS2MachinePriorityPath {
    param([string]$Path,[string]$Name,[switch]$AllowFilterRead)
    foreach($definition in Get-NetBoostCS2PriorityDefinitions){
        if($Path -eq $definition.Path -and $Name -eq 'CpuPriorityClass'){return}
        if($AllowFilterRead -and $Path -eq $definition.Path.Substring(0,$definition.Path.Length-12) -and $Name -eq 'UseFilter'){return}
    }
    throw 'Only the cs2.exe/Discord.exe CpuPriorityClass values are supported; FACEIT and other IFEO options are excluded.'
}
function Get-NetBoostCS2MachinePriorityValue {
    param([string]$Path,[string]$Name)
    Test-NetBoostCS2MachinePriorityPath $Path $Name -AllowFilterRead
    $view=if([Environment]::Is64BitOperatingSystem){[Microsoft.Win32.RegistryView]::Registry64}else{[Microsoft.Win32.RegistryView]::Registry32}
    $base=[Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,$view);$key=$null
    try {
        $key=$base.OpenSubKey($Path.Substring(6),$false)
        if(-not $key -or $key.GetValueNames() -notcontains $Name){return [pscustomobject]@{Exists=$false;Kind='';Value=$null}}
        return [pscustomobject]@{Exists=$true;Kind=[string]$key.GetValueKind($Name);Value=$key.GetValue($Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}
    } finally {if($key){$key.Dispose()};$base.Dispose()}
}
function Set-NetBoostCS2MachinePriorityValue {
    param([string]$Path,[string]$Name,$State)
    Test-NetBoostCS2MachinePriorityPath $Path $Name
    Test-NetBoostCS2RegistrySnapshot $State
    if($State.Exists -and ($State.Kind -ne 'DWord' -or [long]$State.Value -notin @(1,2,3,4,5,6))){throw 'Unsupported priority value.'}
    $view=if([Environment]::Is64BitOperatingSystem){[Microsoft.Win32.RegistryView]::Registry64}else{[Microsoft.Win32.RegistryView]::Registry32}
    $base=[Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,$view);$key=$null
    try {
        if($State.Exists){$key=$base.CreateSubKey($Path.Substring(6));$key.SetValue($Name,[int]$State.Value,[Microsoft.Win32.RegistryValueKind]::DWord)}
        else {$key=$base.OpenSubKey($Path.Substring(6),$true);if($key){$key.DeleteValue($Name,$false)}}
        if($key){$key.Flush()}
    } finally {if($key){$key.Dispose()};$base.Dispose()}
}
function Get-NetBoostCS2PriorityRoot {
    param([string]$BackupRoot)
    if($BackupRoot){return [IO.Path]::GetFullPath($BackupRoot)}
    return (Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'NetBoost\cs2-priority')
}
function Test-NetBoostCS2PriorityFilters {
    param($Definitions,[hashtable]$System)
    foreach($definition in $Definitions){
        $path=$definition.Path.Substring(0,$definition.Path.Length-12)
        $filter=& $System.RegistryRead $path 'UseFilter'
        if($filter.Exists -and ($filter.Kind -ne 'DWord' -or $filter.Value -ne 0)){throw "Existing IFEO UseFilter configuration for $($definition.Target). No launch rules changed."}
    }
}
function Get-NetBoostCS2PriorityPlan {
    param([string]$ExePath,[hashtable]$System,[switch]$IncludeDiscord)
    if(-not $System){$System=Get-NetBoostCS2System}
    $context=& $System.Context $ExePath
    $definitions=@(Get-NetBoostCS2PriorityDefinitions|Where-Object{$IncludeDiscord -or $_.Target -eq 'CS2LaunchPriority'})
    Test-NetBoostCS2PriorityFilters $definitions $System
    $steps=@(foreach($definition in $definitions){
        $before=& $System.RegistryRead $definition.Path $definition.Name
        Test-NetBoostCS2RegistrySnapshot $before
        if($before.Exists -and ($before.Kind -ne 'DWord' -or [long]$before.Value -notin @(1,2,3,4,5,6))){throw "Unsupported existing priority for $($definition.Target)."}
        [pscustomobject]@{Kind='Registry';Target=$definition.Target;Before=$before;After=[pscustomobject]@{Exists=$true;Kind='DWord';Value=$definition.Value};Stage='Captured'}
    })
    return [pscustomobject]@{Context=$context;Steps=$steps;Scope='ProcessPriority';Persistent=$true;BackgroundProcess=$false;Effective='Next application launch';MachineWide=$true}
}
function Set-NetBoostCS2ProcessPriority {
    param([string]$ExePath,[string]$BackupRoot,[hashtable]$System,[switch]$IncludeDiscord)
    if(-not $System){$System=Get-NetBoostCS2System}
    $root=Get-NetBoostCS2PriorityRoot $BackupRoot;$lock=$null;$manifest=$null;$mutationStarted=$false
    try {
        [void][IO.Directory]::CreateDirectory($root)
        $lock=[IO.File]::Open((Join-Path $root 'transaction.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
        $existing=Read-NetBoostCS2Manifest $root $System
        if($existing -and $existing.Scope -ne 'ProcessPriority'){throw 'Not a process-priority journal.'}
        if($existing -and $existing.Phase -ne 'Restored'){
            if($existing.Phase -ne 'Applied'){throw 'An interrupted priority operation requires priority Restore first.'}
            if($ExePath -and [IO.Path]::GetFullPath($ExePath) -ne $existing.Context.ExePath){throw 'Another CS2 installation has an active priority baseline.'}
            $hasDiscord=@($existing.Steps|Where-Object Target -eq 'DiscordLaunchPriority').Count -gt 0
            if($hasDiscord -ne [bool]$IncludeDiscord){throw 'The active priority target set differs. Restore priorities before selecting another set.'}
            Test-NetBoostCS2PriorityFilters @(Get-NetBoostCS2PriorityDefinitions|Where-Object{$IncludeDiscord -or $_.Target -eq 'CS2LaunchPriority'}) $System
            foreach($step in $existing.Steps){if(-not(Test-NetBoostCS2Equal $step (Get-NetBoostCS2StepState $existing $step $System) $step.After)){throw "Priority changed outside NetBoost: $($step.Target). Original baseline preserved."}}
            return [pscustomobject]@{Success=$true;Errors=@();AlreadyApplied=$true;Persistent=$true;BackupPath=(Get-NetBoostCS2BackupPath $root $existing);Effective='Next application launch'}
        }
        $plan=Get-NetBoostCS2PriorityPlan -ExePath $ExePath -System $System -IncludeDiscord:$IncludeDiscord
        $manifest=[pscustomobject]@{Schema=1;Scope='ProcessPriority';Id=[guid]::NewGuid().ToString('N');Created=(Get-Date).ToUniversalTime().ToString('o');Updated='';Phase='Captured';Context=$plan.Context;Steps=@($plan.Steps)}
        Test-NetBoostCS2Manifest $manifest $plan.Context
        Save-NetBoostCS2Manifest $root $manifest
        foreach($step in $manifest.Steps){
            if(-not(Test-NetBoostCS2Equal $step (Get-NetBoostCS2StepState $manifest $step $System) $step.Before)){throw "Priority changed during preview: $($step.Target)."}
            $step.Stage='Pending';$manifest.Phase='Applying';Save-NetBoostCS2Manifest $root $manifest;$mutationStarted=$true
            Set-NetBoostCS2StepState $manifest $step $step.After $System
            if(-not(Test-NetBoostCS2Equal $step (Get-NetBoostCS2StepState $manifest $step $System) $step.After)){throw "Launch priority verification failed: $($step.Target)."}
            $step.Stage='Applied';Save-NetBoostCS2Manifest $root $manifest
        }
        $manifest.Phase='Applied';Save-NetBoostCS2Manifest $root $manifest
        return [pscustomobject]@{Success=$true;Errors=@();AlreadyApplied=$false;Persistent=$true;BackupPath=(Get-NetBoostCS2BackupPath $root $manifest);Effective='Next application launch'}
    } catch {
        $errors=@($_.Exception.Message)
        if($manifest -and $mutationStarted){try{$errors+=@(Restore-NetBoostCS2Steps $root $manifest $System)}catch{$errors+="Priority rollback: $($_.Exception.Message)"}}
        return [pscustomobject]@{Success=$false;Errors=$errors;BackupPath=if($manifest){Get-NetBoostCS2BackupPath $root $manifest}else{''}}
    } finally {if($lock){$lock.Dispose()}}
}
function Restore-NetBoostCS2Priority {
    param([string]$BackupRoot,[hashtable]$System)
    if(-not $System){$System=Get-NetBoostCS2System}
    return (Restore-NetBoostCS2 -BackupRoot (Get-NetBoostCS2PriorityRoot $BackupRoot) -System $System -ExpectedScope 'ProcessPriority')
}
function Get-NetBoostCS2PriorityStatus {
    param([string]$BackupRoot,[hashtable]$System,[switch]$ObserveProcesses)
    if(-not $System){$System=Get-NetBoostCS2System}
    $root=Get-NetBoostCS2PriorityRoot $BackupRoot
    $manifest=Read-NetBoostCS2Manifest $root $System
    if($manifest -and $manifest.Scope -ne 'ProcessPriority'){throw 'Not a process-priority journal.'}
    $observed=@()
    if($ObserveProcesses){foreach($name in @('cs2','Discord')){try{$observed+=@(& $System.ProcessRead $name|Select-Object Name,Id,Priority)}catch{$observed+=[pscustomobject]@{Name=$name;Id=$null;Priority='Unavailable'}}}}
    return [pscustomobject]@{Phase=if($manifest){$manifest.Phase}else{'NotApplied'};BackupPath=if($manifest){Get-NetBoostCS2BackupPath $root $manifest}else{''};Persistent=$true;MachineWide=$true;BackgroundProcess=$false;Effective='Next application launch';Observed=$observed}
}
function Restore-NetBoostCS2All {
    param([string]$BackupRoot,[string]$PriorityBackupRoot,[hashtable]$System)
    if(-not $System){$System=Get-NetBoostCS2System}
    $priority=Restore-NetBoostCS2Priority -BackupRoot $PriorityBackupRoot -System $System
    $preset=Restore-NetBoostCS2 -BackupRoot $BackupRoot -System $System
    return [pscustomobject]@{Success=($priority.Success -and $preset.Success);Errors=@($priority.Errors)+@($preset.Errors);BackupPath=(@($preset.BackupPath,$priority.BackupPath)|Where-Object{$_}) -join '; ';Priority=$priority;Preparation=$preset;Effective='Restart CS2 and Discord for restored launch priorities'}
}
