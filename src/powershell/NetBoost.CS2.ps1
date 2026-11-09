#Requires -Version 5.1
. (Join-Path $PSScriptRoot 'NetBoost.State.ps1')
. (Join-Path $PSScriptRoot 'NetBoost.CS2Priority.ps1')

function Get-NetBoostCS2Executable {
    param([string]$Path)
    $candidates=[Collections.Generic.List[string]]::new()
    if($Path){$candidates.Add($Path)} else {
        $steam=Get-ItemPropertyValue -LiteralPath 'HKCU:\Software\Valve\Steam' -Name SteamPath -ErrorAction SilentlyContinue
        $libraries=@($steam)
        if($steam -and (Test-Path -LiteralPath (Join-Path $steam 'steamapps\libraryfolders.vdf'))){
            $text=Get-Content -LiteralPath (Join-Path $steam 'steamapps\libraryfolders.vdf') -Raw -ErrorAction Stop
            foreach($m in [regex]::Matches($text,'"path"\s+"([^"]+)"')){$libraries+=$m.Groups[1].Value.Replace('\\','\')}
        }
        foreach($library in @($libraries|Where-Object{$_}|Select-Object -Unique)){
            $candidates.Add((Join-Path $library 'steamapps\common\Counter-Strike Global Offensive\game\bin\win64\cs2.exe'))
        }
    }
    $unique=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $found=@($candidates|Where-Object{Test-Path -LiteralPath $_ -PathType Leaf}|ForEach-Object{[IO.Path]::GetFullPath((Get-Item -LiteralPath $_).FullName)}|Where-Object{$unique.Add($_)})
    if($found.Count -ne 1){throw 'CS2 was not uniquely located. Use --cs2-exe with the full game\bin\win64\cs2.exe path.'}
    if($found[0] -notmatch '[\\/]game[\\/]bin[\\/]win64[\\/]cs2\.exe$'){throw 'Expected the installed CS2 game\bin\win64\cs2.exe executable.'}
    return $found[0]
}

function Get-NetBoostNipAudit {
    param([Parameter(Mandatory)][string]$Path)
    $file=Get-Item -LiteralPath $Path -ErrorAction Stop
    if($file.Length -gt 4MB){throw 'NIP file exceeds the audit size limit.'}
    $settings=[Xml.XmlReaderSettings]::new();$settings.DtdProcessing=[Xml.DtdProcessing]::Prohibit;$settings.XmlResolver=$null;$settings.MaxCharactersInDocument=4MB
    # NPI exports may retain a StringWriter UTF-16 declaration inside UTF-8 files.
    # Decode the BOM first; a TextReader avoids trusting that stale declaration.
    $textReader=[IO.StringReader]::new([IO.File]::ReadAllText($file.FullName,[Text.Encoding]::UTF8))
    $reader=[Xml.XmlReader]::Create($textReader,$settings)
    try{$doc=[Xml.XmlDocument]::new();$doc.XmlResolver=$null;$doc.Load($reader)}finally{$reader.Dispose();$textReader.Dispose()}
    if($doc.DocumentElement.Name -ne 'ArrayOfProfile'){throw 'Not an NVIDIA NIP profile document.'}
    $profiles=@($doc.SelectNodes('/ArrayOfProfile/Profile'))
    if($profiles.Count -lt 1 -or $profiles.Count -gt 100){throw 'Invalid NIP profile count.'}
    $audit=@(foreach($profile in $profiles){
        $executables=@($profile.SelectNodes('Executeables/string')|ForEach-Object{$_.InnerText})
        $global=$profile.ProfileName -match '(?i)base\s*profile|global' -or $executables.Count -eq 0
        $items=@(foreach($setting in $profile.SelectNodes('Settings/ProfileSetting')){
            [uint32]$id=0
            if(-not [uint32]::TryParse([string]$setting.SettingID,[ref]$id)){throw 'Invalid numeric setting ID in NIP.'}
            $reason='Excluded: undocumented, driver-specific or not required by the reviewed CS2 preset.'
            $approved=$false
            if($id -in @(274197361,6600001) -and [string]$setting.SettingValue -eq '1' -and [string]$setting.ValueType -eq 'Dword'){$approved=-not $global;$reason='Reviewed per-CS2 setting; applied through the installed driver API with exact backup.'}
            elseif($id -eq 550564838){$reason='Excluded: device-specific OpenGL GPU identifier from another machine.'}
            elseif($id -eq 549528094){$reason='Excluded: OpenGL threaded setting; CS2 uses Direct3D/Vulkan.'}
            elseif($id -eq 8102046){$reason='Excluded: legacy pre-render limit is not the in-game NVIDIA Reflex control.'}
            elseif($id -in @(11041231,5912412,278196567,278196727,279476652,279476686,279476687,294973784)){$reason='Preserved: V-Sync/VRR/G-SYNC depends on the display and user preference.'}
            if($global){$reason='Global driver setting; outside this reviewed CS2-scoped preset. Whole-profile import is not performed.'}
            [pscustomobject]@{Id=$id;Name=([string]$setting.SettingNameInfo -replace '[\x00-\x1f\x7f]','');Value=[string]$setting.SettingValue;Type=[string]$setting.ValueType;Approved=$approved;Reason=$reason}
        })
        if($items.Count -gt 1000){throw 'Too many settings in NIP.'}
        [pscustomobject]@{Name=([string]$profile.ProfileName -replace '[\x00-\x1f\x7f]','');Global=$global;Executables=$executables;Settings=$items}
    })
    return [pscustomobject]@{Path=$file.FullName;Sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash;SafeToApply=$false;Explanation='Reference audit only. Whole-profile import is intentionally unavailable.';Profiles=$audit}
}

function Get-NetBoostCS2RegistryValue {
    param([string]$Path,[string]$Name)
    if(-not(Test-Path -LiteralPath $Path -ErrorAction Stop)){return [pscustomobject]@{Exists=$false;Kind='';Value=$null}}
    $key=Get-Item -LiteralPath $Path -ErrorAction Stop
    try {
        if($key.GetValueNames() -notcontains $Name){return [pscustomobject]@{Exists=$false;Kind='';Value=$null}}
        return [pscustomobject]@{Exists=$true;Kind=[string]$key.GetValueKind($Name);Value=$key.GetValue($Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}
    } finally {$key.Close()}
}
function Set-NetBoostCS2RegistryValue {
    param([string]$Path,[string]$Name,$State)
    if(-not $State.Exists){
        if((Get-NetBoostCS2RegistryValue $Path $Name).Exists){Remove-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop}
        return
    }
    if(-not $Path.StartsWith('HKCU:\',[StringComparison]::OrdinalIgnoreCase)){throw 'CS2 registry adapter only writes current-user settings.'}
    $key=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($Path.Substring(6))
    try {
        $value=$State.Value
        switch([string]$State.Kind){'DWord'{$number=[long]$value;if($number -gt [int]::MaxValue){$number-=4294967296};$value=[int]$number};'QWord'{$value=[long]$value};'Binary'{$value=[byte[]]$value};'MultiString'{$value=[string[]]$value};default{$value=[string]$value}}
        $key.SetValue($Name,$value,[Microsoft.Win32.RegistryValueKind]::$($State.Kind));$key.Flush()
    } finally {$key.Close()}
}
function Open-NetBoostCS2Driver {
    param([string]$ExePath)
    if(-not ('NetBoost.NvidiaDrs' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot '..\native\NetBoost.NvidiaDrs.cs') -ErrorAction Stop}
    return [NetBoost.NvidiaDrs]::new($ExePath)
}
function Get-NetBoostCS2System {
    return @{
        Context={param($Path,$ForRestore=$false)
            $exe=if($ForRestore -and $Path -match '[\\/]game[\\/]bin[\\/]win64[\\/]cs2\.exe$'){[IO.Path]::GetFullPath($Path)}else{Get-NetBoostCS2Executable $Path}
            $gpus=@(Get-CimInstance Win32_VideoController -ErrorAction Stop)
            $battery=Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
            [pscustomobject]@{Machine=$env:COMPUTERNAME;Sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;ExePath=$exe;HasNvidia=(@($gpus|Where-Object Name -match 'NVIDIA').Count -gt 0);HasIntegratedGpu=(@($gpus|Where-Object Name -match 'Intel|Radeon.*Graphics').Count -gt 0);ACPower=($null -eq $battery -or $battery.BatteryStatus -in @(2,3,6,7,8,9));CPU=[string](Get-CimInstance Win32_Processor|Select-Object -First 1).Name;GPU=($gpus.Name -join ', ');DriverVersion=($gpus|Where-Object Name -match 'NVIDIA'|Select-Object -First 1).DriverVersion}
        }
        RegistryRead={param($Path,$Name) if($Path.StartsWith('HKLM:\',[StringComparison]::OrdinalIgnoreCase)){Get-NetBoostCS2MachinePriorityValue $Path $Name}else{Get-NetBoostCS2RegistryValue $Path $Name}}
        RegistryWrite={param($Path,$Name,$State) if($Path.StartsWith('HKLM:\',[StringComparison]::OrdinalIgnoreCase)){Set-NetBoostCS2MachinePriorityValue $Path $Name $State}else{Set-NetBoostCS2RegistryValue $Path $Name $State}}
        DriverRead={param($Path) $drs=Open-NetBoostCS2Driver $Path;try{$drs.Capture()}finally{$drs.Dispose()}}
        DriverWrite={param($Path,$State)
            $typed=[NetBoost.DriverSnapshot]::new();$typed.ProfileName=$State.ProfileName
            $typed.Settings=@(foreach($item in $State.Settings){$entry=[NetBoost.DriverSetting]::new();$entry.Id=$item.Id;$entry.Value=$item.Value;$entry.UserOverride=$item.UserOverride;$entry})
            $drs=Open-NetBoostCS2Driver $Path;try{$drs.Apply($typed)}finally{$drs.Dispose()}
        }
        ProcessRead={param($Name)
            @(Get-Process -Name $Name -ErrorAction SilentlyContinue|ForEach-Object{try{[pscustomobject]@{Name=$_.ProcessName;Id=$_.Id;StartTime=$_.StartTime.ToUniversalTime().ToString('o');ExePath=$_.Path;Priority=[string]$_.PriorityClass}}catch{}})
        }
        ProcessWrite={param($Record,$Priority)
            $process=Get-Process -Id $Record.Id -ErrorAction SilentlyContinue
            if(-not $process){return $false}
            if($process.StartTime.ToUniversalTime().ToString('o') -ne $Record.StartTime -or $process.Path -ne $Record.ExePath){return $false}
            $process.PriorityClass=[Diagnostics.ProcessPriorityClass]::$Priority
            $process.Refresh();if([string]$process.PriorityClass -ne $Priority){throw 'Process priority verification failed.'};return $true
        }
    }
}

function Get-NetBoostCS2Definitions {
    param($Context)
    return @(
        [pscustomobject]@{Target='GameMode';Path='HKCU:\Software\Microsoft\GameBar';Name='AutoGameModeEnabled';Value=1;Kind='DWord'},
        [pscustomobject]@{Target='BackgroundCapture';Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR';Name='HistoricalCaptureEnabled';Value=0;Kind='DWord'},
        [pscustomobject]@{Target='GpuPreference';Path='HKCU:\Software\Microsoft\DirectX\UserGpuPreferences';Name=$Context.ExePath;Value='GpuPreference=2;';Kind='String'}
    )
}
function Get-NetBoostCS2Plan {
    param([string]$ExePath,[hashtable]$System)
    if(-not $System){$System=Get-NetBoostCS2System}
    $context=& $System.Context $ExePath
    $steps=@(foreach($definition in Get-NetBoostCS2Definitions $context){
        $before=& $System.RegistryRead $definition.Path $definition.Name
        $value=$definition.Value
        if($definition.Target -eq 'GpuPreference' -and $before.Exists){$tokens=@(([string]$before.Value -split ';')|Where-Object{$_ -and $_ -notmatch '^GpuPreference='});$value=(($tokens+@('GpuPreference=2')) -join ';')+';'}
        [pscustomobject]@{Kind='Registry';Target=$definition.Target;Before=$before;After=[pscustomobject]@{Exists=$true;Kind=$definition.Kind;Value=$value};Stage='Captured'}
    })
    if($context.HasNvidia){
        $snapshot=& $System.DriverRead $context.ExePath
        $steps+=[pscustomobject]@{Kind='Driver';Target='NvidiaCS2';Before=$snapshot;After=[pscustomobject]@{ProfileName=$snapshot.ProfileName;Settings=@([pscustomobject]@{Id=274197361;Value=1;UserOverride=$true},[pscustomobject]@{Id=6600001;Value=1;UserOverride=$true})};Stage='Captured'}
    }
    return [pscustomobject]@{Context=$context;Steps=$steps;BackgroundProcess=$false;Persistent=$true}
}

function Get-NetBoostCS2Root { param([string]$BackupRoot) if($BackupRoot){return [IO.Path]::GetFullPath($BackupRoot)};return (Join-Path $env:LOCALAPPDATA 'NetBoost\cs2') }
function Get-NetBoostCS2BackupPath { param([string]$Root,$Manifest) return (Join-Path $Root ('backups\'+$Manifest.Id+'.json')) }
function Save-NetBoostCS2Manifest {
    param([string]$Root,$Manifest)
    $Manifest.Updated=(Get-Date).ToUniversalTime().ToString('o')
    Write-NetBoostJsonFile -Path (Get-NetBoostCS2BackupPath $Root $Manifest) -Value $Manifest
    Write-NetBoostJsonFile -Path (Join-Path $Root 'active.json') -Value $Manifest
}
function Test-NetBoostCS2RegistrySnapshot {
    param($Snapshot)
    if($null -eq $Snapshot -or $Snapshot.Exists -isnot [bool]){throw 'Invalid registry snapshot.'}
    if($Snapshot.Exists -and $Snapshot.Kind -notin @('String','ExpandString','DWord','QWord','MultiString','Binary')){throw 'Unsupported registry snapshot type.'}
    if($Snapshot.Exists -and $Snapshot.Kind -in @('String','ExpandString') -and $Snapshot.Value -isnot [string]){throw 'Invalid registry string.'}
    if($Snapshot.Exists -and $Snapshot.Kind -in @('DWord','QWord') -and ($Snapshot.Value -isnot [int] -and $Snapshot.Value -isnot [long] -and $Snapshot.Value -isnot [uint32])){throw 'Invalid registry number.'}
    if($Snapshot.Exists -and $Snapshot.Kind -eq 'DWord' -and ([long]$Snapshot.Value -lt [int]::MinValue -or [long]$Snapshot.Value -gt [uint32]::MaxValue)){throw 'Registry DWORD is outside the supported range.'}
    if($Snapshot.Exists -and $Snapshot.Kind -eq 'Binary'){foreach($item in $Snapshot.Value){if($item -isnot [ValueType] -or [int]$item -lt 0 -or [int]$item -gt 255){throw 'Invalid binary registry backup.'}}}
    if($Snapshot.Exists -and $Snapshot.Kind -eq 'MultiString'){foreach($item in $Snapshot.Value){if($item -isnot [string]){throw 'Invalid registry multi-string backup.'}}}
}
function Test-NetBoostCS2Manifest {
    param($Manifest,$Context)
    if($Manifest.Schema -ne 1 -or [string]$Manifest.Id -notmatch '^[a-f0-9]{32}$' -or $Manifest.Phase -notin @('Captured','Applying','Applied','Restoring','Restored','RecoveryRequired')){throw 'Unsupported or corrupt CS2 manifest.'}
    if($Manifest.Context.Machine -ne $Context.Machine -or $Manifest.Context.Sid -ne $Context.Sid -or $Manifest.Context.ExePath -ne $Context.ExePath){throw 'Backup belongs to another computer, Windows account or CS2 installation.'}
    $priorityScope=($Manifest.Scope -eq 'ProcessPriority')
    if($Manifest.PSObject.Properties.Name -contains 'Scope' -and -not $priorityScope){throw 'Unknown CS2 backup scope.'}
    $minimum=if($priorityScope){1}else{3};$maximum=if($priorityScope){2}else{100}
    if($Manifest.Steps.Count -lt $minimum -or $Manifest.Steps.Count -gt $maximum){throw 'Invalid backup step count.'}
    $definitions=@(Get-NetBoostCS2ManifestDefinitions $Manifest);$seen=@{}
    foreach($step in $Manifest.Steps){
        if($step.Stage -notin @('Captured','Pending','Applied','Restored')){throw 'Invalid step journal state.'}
        if($step.Kind -eq 'Registry'){
            $def=$definitions|Where-Object Target -eq $step.Target
            if(-not $def -or $seen.ContainsKey($step.Target)){throw 'Unexpected or duplicated registry target.'};$seen[$step.Target]=$true
            Test-NetBoostCS2RegistrySnapshot $step.Before;Test-NetBoostCS2RegistrySnapshot $step.After
            if($priorityScope -and $step.Before.Exists -and ($step.Before.Kind -ne 'DWord' -or [long]$step.Before.Value -notin @(1,2,3,4,5,6))){throw 'Unsupported original priority value.'}
            if(-not $step.After.Exists -or $step.After.Kind -ne $def.Kind){throw 'Invalid intended registry state.'}
            if($step.Target -ne 'GpuPreference' -and $step.After.Value -ne $def.Value){throw 'Unexpected intended setting value.'}
            if($step.Target -eq 'GpuPreference' -and $step.After.Value -notmatch '(^|;)GpuPreference=2;'){throw 'Invalid GPU preference plan.'}
        } elseif($step.Kind -eq 'Driver'){
            if($priorityScope){throw 'Driver changes are not allowed in a priority backup.'}
            if($step.Target -ne 'NvidiaCS2' -or $seen.ContainsKey('NvidiaCS2')){throw 'Unexpected NVIDIA target.'};$seen.NvidiaCS2=$true
            foreach($snapshot in @($step.Before,$step.After)){
                if([string]::IsNullOrWhiteSpace($snapshot.ProfileName) -or $snapshot.ProfileName -match '(?i)base\s*profile|global' -or $snapshot.Settings.Count -ne 2){throw 'Unsafe driver profile backup.'}
                $ids=@()
                foreach($item in $snapshot.Settings){
                    $integer=($item.Value -is [int] -or $item.Value -is [long] -or $item.Value -is [uint32])
                    if($item.Id -notin @(274197361,6600001) -or $ids -contains $item.Id -or $item.UserOverride -isnot [bool] -or -not $integer -or [decimal]$item.Value -lt 0 -or [decimal]$item.Value -gt [uint32]::MaxValue){throw 'Invalid driver setting backup.'};$ids+=$item.Id
                }
            }
            if($step.Before.ProfileName -ne $step.After.ProfileName -or @($step.After.Settings|Where-Object{$_.Value -ne 1 -or -not $_.UserOverride}).Count){throw 'Unreviewed driver setting plan.'}
        } elseif($step.Kind -eq 'Process'){
            if($priorityScope){throw 'Live process changes are not allowed in a priority backup.'}
            if($step.Target -notin @('CS2Process','DiscordProcess') -or $step.Before.Id -isnot [ValueType] -or [int]$step.Before.Id -le 0 -or [string]::IsNullOrWhiteSpace($step.Before.StartTime)){throw 'Invalid process backup.'}
            $expected=if($step.Target -eq 'CS2Process'){'AboveNormal'}else{'BelowNormal'}
            if($step.After.Priority -ne $expected -or $step.Before.Priority -notin @('Normal','AboveNormal','BelowNormal','Idle','High','RealTime')){throw 'Unsafe process priority request.'}
            if($step.Target -eq 'CS2Process' -and $step.Before.ExePath -ne $Context.ExePath){throw 'Unexpected CS2 process path.'}
            if($step.Target -eq 'DiscordProcess' -and [IO.Path]::GetFileName($step.Before.ExePath) -ne 'Discord.exe'){throw 'Unexpected Discord process path.'}
        } else {throw 'Unknown backup target kind.'}
    }
    foreach($definition in $definitions){if($priorityScope -and $definition.Target -eq 'DiscordLaunchPriority'){continue};if(-not $seen.ContainsKey($definition.Target)){throw 'Required Windows baseline is missing.'}}
    if(-not $priorityScope -and $Manifest.Context.HasNvidia -and -not $seen.ContainsKey('NvidiaCS2')){throw 'Required driver baseline is missing.'}
}
function Read-NetBoostCS2Manifest {
    param([string]$Root,[hashtable]$System)
    $path=Join-Path $Root 'active.json'
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return $null}
    if((Get-Item -LiteralPath $path).Length -gt 2MB){throw 'CS2 backup is too large.'}
    $manifest=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($path)) -ErrorAction Stop
    $context=& $System.Context $manifest.Context.ExePath $true
    Test-NetBoostCS2Manifest $manifest $context
    return $manifest
}
function Test-NetBoostCS2Equal {
    param($Step,$Actual,$Expected)
    if($Step.Kind -eq 'Registry'){
        if($Actual.Exists -ne $Expected.Exists){return $false};if(-not $Expected.Exists){return $true}
        return ($Actual.Kind -eq $Expected.Kind -and (ConvertTo-Json -InputObject $Actual.Value -Compress) -ceq (ConvertTo-Json -InputObject $Expected.Value -Compress))
    }
    if($Step.Kind -eq 'Process'){return ($null -eq $Actual -or $Actual.Priority -eq $Expected.Priority)}
    if($Actual.ProfileName -ne $Expected.ProfileName){return $false}
    foreach($item in $Expected.Settings){$current=@($Actual.Settings|Where-Object Id -eq $item.Id);if($current.Count -ne 1 -or $current[0].UserOverride -ne $item.UserOverride -or ($item.UserOverride -and $current[0].Value -ne $item.Value)){return $false}}
    return $true
}
function Get-NetBoostCS2StepState {
    param($Manifest,$Step,[hashtable]$System)
    if($Step.Kind -eq 'Driver'){return (& $System.DriverRead $Manifest.Context.ExePath)}
    if($Step.Kind -eq 'Registry'){$definition=Get-NetBoostCS2ManifestDefinitions $Manifest|Where-Object Target -eq $Step.Target;return (& $System.RegistryRead $definition.Path $definition.Name)}
    $name=if($Step.Target -eq 'CS2Process'){'cs2'}else{'Discord'}
    return @(& $System.ProcessRead $name|Where-Object{$_.Id -eq $Step.Before.Id -and $_.StartTime -eq $Step.Before.StartTime -and $_.ExePath -eq $Step.Before.ExePath})|Select-Object -First 1
}
function Set-NetBoostCS2StepState {
    param($Manifest,$Step,$State,[hashtable]$System)
    if($Step.Kind -eq 'Driver'){& $System.DriverWrite $Manifest.Context.ExePath $State;return}
    if($Step.Kind -eq 'Registry'){$definition=Get-NetBoostCS2ManifestDefinitions $Manifest|Where-Object Target -eq $Step.Target;& $System.RegistryWrite $definition.Path $definition.Name $State;return}
    $null=& $System.ProcessWrite $Step.Before $State.Priority
}
function Restore-NetBoostCS2Steps {
    param([string]$Root,$Manifest,[hashtable]$System)
    $errors=[Collections.Generic.List[string]]::new()
    # Preflight every touched item before any mutation, preserving external edits.
    foreach($step in $Manifest.Steps|Where-Object Stage -ne 'Captured'){
        $current=Get-NetBoostCS2StepState $Manifest $step $System
        $knownTransition=(Test-NetBoostCS2Equal $step $current $step.Before) -or (Test-NetBoostCS2Equal $step $current $step.After)
        if(-not $knownTransition -and $step.Kind -eq 'Driver' -and $current.ProfileName -eq $step.Before.ProfileName){
            # A native save may fail after only some known values reach the driver.
            $knownTransition=$true
            foreach($item in $current.Settings){
                $old=$step.Before.Settings|Where-Object Id -eq $item.Id;$new=$step.After.Settings|Where-Object Id -eq $item.Id
                if((-not $old -or $item.UserOverride -ne $old.UserOverride -or ($item.UserOverride -and $item.Value -ne $old.Value)) -and (-not $new -or $item.UserOverride -ne $new.UserOverride -or ($item.UserOverride -and $item.Value -ne $new.Value))){$knownTransition=$false}
            }
        }
        if(-not $knownTransition){$errors.Add("External change detected: $($step.Target). Restore was not applied.")}
    }
    if($errors.Count){return @($errors)}
    $Manifest.Phase='Restoring'
    # The original baseline already exists. A bookkeeping failure must not stop
    # restoration of known attempted changes; keep reporting journal errors.
    try{Save-NetBoostCS2Manifest $Root $Manifest}catch{$errors.Add("Restore journal: $($_.Exception.Message)")}
    for($index=$Manifest.Steps.Count-1;$index -ge 0;$index--){
        $step=$Manifest.Steps[$index];if($step.Stage -eq 'Captured'){continue}
        try {
            $current=Get-NetBoostCS2StepState $Manifest $step $System
            if(-not(Test-NetBoostCS2Equal $step $current $step.Before)){Set-NetBoostCS2StepState $Manifest $step $step.Before $System}
            if(-not(Test-NetBoostCS2Equal $step (Get-NetBoostCS2StepState $Manifest $step $System) $step.Before)){throw 'Restored state verification failed.'}
            $step.Stage='Restored';Save-NetBoostCS2Manifest $Root $Manifest
        } catch {$errors.Add("$($step.Target): $($_.Exception.Message)")}
    }
    $Manifest.Phase=if($errors.Count){'RecoveryRequired'}else{'Restored'}
    try{Save-NetBoostCS2Manifest $Root $Manifest}catch{$errors.Add("Recovery journal: $($_.Exception.Message)")}
    return @($errors)
}
function Invoke-NetBoostCS2Optimize {
    param([string]$ExePath,[string]$BackupRoot,[hashtable]$System)
    if(-not $System){$System=Get-NetBoostCS2System}
    $root=Get-NetBoostCS2Root $BackupRoot;$lock=$null;$manifest=$null;$mutationStarted=$false
    try {
        [void][IO.Directory]::CreateDirectory($root)
        $lock=[IO.File]::Open((Join-Path $root 'transaction.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
        $existing=Read-NetBoostCS2Manifest $root $System
        if($existing -and $existing.Scope){throw 'Not a Windows/NVIDIA preparation journal.'}
        if($existing -and $existing.Phase -ne 'Restored'){
            if($ExePath -and [IO.Path]::GetFullPath($ExePath) -ne $existing.Context.ExePath){throw 'Another CS2 installation has an active baseline.'}
            if($existing.Phase -ne 'Applied'){throw 'An interrupted operation requires Restore before applying again.'}
            foreach($step in $existing.Steps){if(-not(Test-NetBoostCS2Equal $step (Get-NetBoostCS2StepState $existing $step $System) $step.After)){throw "Settings changed outside NetBoost: $($step.Target). Baseline preserved."}}
            return [pscustomobject]@{Success=$true;Errors=@();AlreadyApplied=$true;BackupPath=(Get-NetBoostCS2BackupPath $root $existing)}
        }
        $plan=Get-NetBoostCS2Plan -ExePath $ExePath -System $System
        if(@(& $System.ProcessRead 'cs2'|Where-Object ExePath -eq $plan.Context.ExePath).Count){throw 'Close CS2 before applying persistent Windows/driver settings.'}
        $manifest=[pscustomobject]@{Schema=1;Id=[guid]::NewGuid().ToString('N');Created=(Get-Date).ToUniversalTime().ToString('o');Updated='';Phase='Captured';Context=$plan.Context;Steps=@($plan.Steps)}
        Test-NetBoostCS2Manifest $manifest $plan.Context
        Save-NetBoostCS2Manifest $root $manifest
        foreach($step in $manifest.Steps){
            $current=Get-NetBoostCS2StepState $manifest $step $System
            if(-not(Test-NetBoostCS2Equal $step $current $step.Before)){throw "Configuration changed during preview: $($step.Target)."}
            $step.Stage='Pending';$manifest.Phase='Applying';Save-NetBoostCS2Manifest $root $manifest;$mutationStarted=$true
            Set-NetBoostCS2StepState $manifest $step $step.After $System
            if(-not(Test-NetBoostCS2Equal $step (Get-NetBoostCS2StepState $manifest $step $System) $step.After)){throw "Apply verification failed: $($step.Target)."}
            $step.Stage='Applied';Save-NetBoostCS2Manifest $root $manifest
        }
        $manifest.Phase='Applied';Save-NetBoostCS2Manifest $root $manifest
        return [pscustomobject]@{Success=$true;Errors=@();AlreadyApplied=$false;BackupPath=(Get-NetBoostCS2BackupPath $root $manifest)}
    } catch {
        $errors=@($_.Exception.Message)
        if($manifest -and $mutationStarted){try{$errors+=@(Restore-NetBoostCS2Steps $root $manifest $System)}catch{$errors+="Rollback: $($_.Exception.Message)"}}
        return [pscustomobject]@{Success=$false;Errors=$errors;BackupPath=if($manifest){Get-NetBoostCS2BackupPath $root $manifest}else{''}}
    } finally {if($lock){$lock.Dispose()}}
}
function Restore-NetBoostCS2 {
    param([string]$BackupRoot,[hashtable]$System,[string]$ExpectedScope='Preparation')
    if(-not $System){$System=Get-NetBoostCS2System};$root=Get-NetBoostCS2Root $BackupRoot;$lock=$null
    try {
        if(-not(Test-Path -LiteralPath (Join-Path $root 'active.json'))){return [pscustomobject]@{Success=$true;Errors=@();Message='No active CS2 baseline; no settings changed.'}}
        $lock=[IO.File]::Open((Join-Path $root 'transaction.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
        $manifest=Read-NetBoostCS2Manifest $root $System
        $actualScope=if($manifest.Scope){$manifest.Scope}else{'Preparation'}
        if($actualScope -ne $ExpectedScope){throw 'CS2 restore journal has an unexpected scope.'}
        if($manifest.Phase -eq 'Restored'){return [pscustomobject]@{Success=$true;Errors=@();BackupPath=(Get-NetBoostCS2BackupPath $root $manifest)}}
        $errors=@(Restore-NetBoostCS2Steps $root $manifest $System)
        return [pscustomobject]@{Success=($errors.Count -eq 0);Errors=$errors;BackupPath=(Get-NetBoostCS2BackupPath $root $manifest)}
    } catch {return [pscustomobject]@{Success=$false;Errors=@($_.Exception.Message)}} finally {if($lock){$lock.Dispose()}}
}
function Get-NetBoostCS2Status {
    param([string]$ExePath,[string]$BackupRoot,[hashtable]$System)
    if(-not $System){$System=Get-NetBoostCS2System};$root=Get-NetBoostCS2Root $BackupRoot
    $plan=Get-NetBoostCS2Plan -ExePath $ExePath -System $System
    $manifest=Read-NetBoostCS2Manifest $root $System
    $priority=Get-NetBoostCS2PriorityStatus -System $System -ObserveProcesses
    return [pscustomobject]@{Context=$plan.Context;Phase=if($manifest){$manifest.Phase}else{'NotApplied'};BackupPath=if($manifest){Get-NetBoostCS2BackupPath $root $manifest}else{''};Plan=$plan;Priority=$priority;BackgroundProcess=$false}
}
function Set-NetBoostCS2SessionPriority {
    param([string]$BackupRoot,[hashtable]$System,[switch]$IncludeDiscord)
    if(-not $System){$System=Get-NetBoostCS2System};$root=Get-NetBoostCS2Root $BackupRoot;$lock=$null;$manifest=$null;$attempts=[Collections.Generic.List[object]]::new()
    try {
        $lock=[IO.File]::Open((Join-Path $root 'transaction.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
        $manifest=Read-NetBoostCS2Manifest $root $System
        if(-not $manifest -or $manifest.Phase -ne 'Applied'){throw 'Apply CS2 preparation first so runtime priority changes have a recovery baseline.'}
        $records=@(& $System.ProcessRead 'cs2'|Where-Object ExePath -eq $manifest.Context.ExePath)
        if(-not $records.Count){throw 'Start CS2 first. Runtime priority applies only to the current game process.'}
        if($IncludeDiscord){$records+=@(& $System.ProcessRead 'Discord'|Where-Object{[IO.Path]::GetFileName($_.ExePath) -eq 'Discord.exe'})}
        foreach($record in $records){
            $role=if($record.Name -eq 'cs2'){'CS2Process'}else{'DiscordProcess'};$priority=if($role -eq 'CS2Process'){'AboveNormal'}else{'BelowNormal'}
            $prior=@($manifest.Steps|Where-Object{$_.Kind -eq 'Process' -and $_.Before.Id -eq $record.Id -and $_.Before.StartTime -eq $record.StartTime})
            if($prior.Count){continue}
            $original=[pscustomobject]@{Name=$record.Name;Id=[int]$record.Id;StartTime=[string]$record.StartTime;ExePath=[string]$record.ExePath;Priority=[string]$record.Priority}
            $step=[pscustomobject]@{Kind='Process';Target=$role;Before=$original;After=[pscustomobject]@{Priority=$priority};Stage='Pending'}
            $manifest.Steps+=@($step);Test-NetBoostCS2Manifest $manifest $manifest.Context;Save-NetBoostCS2Manifest $root $manifest
            $attempts.Add($step)
            Set-NetBoostCS2StepState $manifest $step $step.After $System
            if(-not(Test-NetBoostCS2Equal $step (Get-NetBoostCS2StepState $manifest $step $System) $step.After)){throw 'Runtime priority verification failed.'}
            $step.Stage='Applied';Save-NetBoostCS2Manifest $root $manifest
        }
        return [pscustomobject]@{Success=$true;Errors=@();BackupPath=(Get-NetBoostCS2BackupPath $root $manifest)}
    } catch {
        $errors=@($_.Exception.Message)
        for($i=$attempts.Count-1;$i -ge 0;$i--){
            $step=$attempts[$i]
            try {
                $current=Get-NetBoostCS2StepState $manifest $step $System
                if(-not(Test-NetBoostCS2Equal $step $current $step.Before)){Set-NetBoostCS2StepState $manifest $step $step.Before $System}
                if(-not(Test-NetBoostCS2Equal $step (Get-NetBoostCS2StepState $manifest $step $System) $step.Before)){throw 'Priority rollback verification failed.'}
                $step.Stage='Restored'
            } catch {$errors+="Priority rollback: $($_.Exception.Message)"}
        }
        if($manifest -and $attempts.Count){try{$manifest.Phase=if($errors.Count -gt 1){'RecoveryRequired'}else{'Applied'};Save-NetBoostCS2Manifest $root $manifest}catch{$errors+="Priority journal: $($_.Exception.Message)"}}
        return [pscustomobject]@{Success=$false;Errors=$errors;BackupPath=if($manifest){Get-NetBoostCS2BackupPath $root $manifest}else{''}}
    } finally {if($lock){$lock.Dispose()}}
}

function Get-NetBoostCS2Text {
    if($Language -eq 'EN'){return @{
        Header='CS2 PREPARATION';Persistent='Persistent Windows / NVIDIA settings. You may close NetBoost after applying; no background helper is installed.'
        Preview='Preview hardware, settings and backup';Apply='Apply persistent CS2 preparation';Restore='Restore all CS2 preparation and launch priorities'
        Priority='Enable persistent CS2 + voice-only Discord launch priority';PriorityRestore='Restore launch priorities only (keep Windows/NVIDIA preparation)';Audit='Audit a community .nip file (read only)';Tips='CS2 / Discord / FACEIT measurement tips';Back='Back'
        Confirm='Type APPLY to save the baseline and apply these settings';Cancelled='Cancelled.';Saved='Completed. Backup: ';Failed='Operation failed: ';Choice='Choose [0-7]';Nip='Full path to .nip file'
        PriorityNotes=@('CS2: AboveNormal. Voice-only Discord: BelowNormal. Applies on future launches, for all Windows users, even without the other app.','Fully exit and reopen CS2 and Discord yourself after enabling or restoring these rules.','Optional launch configuration: verify on your Windows/FACEIT version. FACEIT client and Anti-Cheat remain unchanged.','No background helper enforces priority if a launcher, the game or Anti-Cheat changes it later. Restore only these rules with [7].')
        TipLines=@('Connect AC power and select the laptop manufacturer performance/fan mode yourself.','Keep NVIDIA Reflex enabled in CS2; choose sync settings for your display.','Voice-only Discord: compare overlay off/on; keep your existing hardware-acceleration choice.','[4] saves launch priority once; fully restart CS2/Discord afterward. NetBoost can remain closed.','[7] restores launch priority without undoing the Windows/NVIDIA preset; restart the apps afterward.','Leave FACEIT client/Anti-Cheat services and drivers unchanged. Test overlays off when using AC.','Compare the same benchmark 3 times: CS2 + Discord, then add FACEIT AC on a non-FACEIT server without queueing.','Launch priority is an opt-in Windows configuration, not a guarantee of FPS gains or FACEIT compatibility.')
    }}
    return @{
        Header='CHUAN BI CHOI CS2';Persistent='Cau hinh Windows / NVIDIA duoc giu lai. Co the dong NetBoost sau khi ap dung; khong cai tien trinh nen.'
        Preview='Xem phan cung, thiet lap va backup';Apply='Ap dung toi uu CS2 co dinh';Restore='Khoi phuc toan bo CS2 va uu tien co dinh'
        Priority='Bat uu tien CS2 + Discord chi thoai co dinh moi lan mo';PriorityRestore='Khoi phuc rieng uu tien (giu toi uu Windows/NVIDIA)';Audit='Kiem tra file .nip cong dong (chi doc)';Tips='Huong dan do CS2 / Discord / FACEIT';Back='Quay lai'
        Confirm='Nhap APPLY de sao luu va ap dung cac thiet lap nay';Cancelled='Da huy.';Saved='Hoan tat. Backup: ';Failed='Thao tac that bai: ';Choice='Chon [0-7]';Nip='Duong dan day du den file .nip'
        PriorityNotes=@('CS2: AboveNormal. Discord chi thoai: BelowNormal. Ap dung moi lan mo, moi tai khoan Windows, ke ca khi khong mo ung dung con lai.','Tu thoat hoan toan va mo lai CS2/Discord sau khi bat hoac khoi phuc uu tien.','Cau hinh tuy chon, can kiem tra voi ban Windows/FACEIT cua ban. Giu nguyen FACEIT client va Anti-Cheat.','Khong co helper nen ep lai neu game/launcher/Anti-Cheat doi uu tien. Chon [7] de khoi phuc rieng phan nay.')
        TipLines=@('Cam sac, tu chon che do hieu nang / quat cua hang laptop khi choi.','Bat NVIDIA Reflex trong CS2; chon V-Sync/G-SYNC theo man hinh cua ban.','Discord chi thoai: so sanh overlay tat/bat; giu lua chon tang toc phan cung ban da thu.','[4] luu uu tien moi lan mo; thoat han va mo lai CS2/Discord. Co the dong NetBoost.','[7] khoi phuc rieng uu tien, giu Windows/NVIDIA; mo lai ung dung sau do.','Giu nguyen FACEIT client, dich vu/driver Anti-Cheat; thu tat overlay khi bat AC.','Do cung benchmark 3 lan: CS2 + Discord, sau do them AC tren server thuong, chua queue FACEIT.','Uu tien khi mo la tuy chon Windows; khong bao dam tang FPS hay tuong thich FACEIT tren moi phien ban.')
    }
}
function Show-NetBoostCS2Plan {
    param($Plan)
    Write-Host ('CPU: '+$Plan.Context.CPU)
    Write-Host ('GPU: '+$Plan.Context.GPU)
    Write-Host ('Driver: '+$Plan.Context.DriverVersion+' | AC: '+$Plan.Context.ACPower)
    Write-Host ('CS2: '+$Plan.Context.ExePath)
    if($Plan.Scope -eq 'ProcessPriority'){
        $ui=Get-NetBoostCS2Text
        foreach($line in $ui.PriorityNotes){Write-Host ('  '+$line)}
    }
    foreach($step in $Plan.Steps){
        $after=if($step.Kind -eq 'Registry'){[string]$step.After.Value}else{'CS2 only: Prefer Maximum Performance + Highest Available Refresh Rate'}
        Write-Host ('  '+$step.Target+' -> '+$after)
    }
}
function Show-NetBoostCS2Center {
    param([string]$ExePath,[scriptblock]$InputReader)
    $ui=Get-NetBoostCS2Text
    while($true){
        if(Get-Command Write-UiHeader -ErrorAction SilentlyContinue){Write-UiHeader $ui.Header 'Tools'}else{Write-Host $ui.Header -ForegroundColor Cyan}
        Write-Host $ui.Persistent
        foreach($pair in @(@('1',$ui.Preview),@('2',$ui.Apply),@('3',$ui.Restore),@('4',$ui.Priority),@('5',$ui.Audit),@('6',$ui.Tips),@('7',$ui.PriorityRestore),@('0',$ui.Back))){Write-Host ('  ['+$pair[0]+'] '+$pair[1])}
        $choice=if($InputReader){[string](& $InputReader $ui.Choice)}else{Read-Host $ui.Choice}
        if($choice -eq '0'){return}
        try {
            $result=$null
            switch($choice){
                '1' {$status=Get-NetBoostCS2Status -ExePath $ExePath;Show-NetBoostCS2Plan $status.Plan;Write-Host ('State: '+$status.Phase+' | Backup: '+$status.BackupPath);Write-Host ('Launch priority: '+$status.Priority.Phase+' | Backup: '+$status.Priority.BackupPath);$status.Priority.Observed|Format-Table -AutoSize|Out-Host}
                '2' {$plan=Get-NetBoostCS2Plan -ExePath $ExePath;Show-NetBoostCS2Plan $plan;$confirmation=if($InputReader){[string](& $InputReader $ui.Confirm)}else{Read-Host $ui.Confirm};if($confirmation -ceq 'APPLY'){$result=Invoke-NetBoostCS2Optimize -ExePath $ExePath}else{Write-Host $ui.Cancelled}}
                '3' {$result=Restore-NetBoostCS2All}
                '4' {$plan=Get-NetBoostCS2PriorityPlan -ExePath $ExePath -IncludeDiscord;Show-NetBoostCS2Plan $plan;$confirmation=if($InputReader){[string](& $InputReader $ui.Confirm)}else{Read-Host $ui.Confirm};if($confirmation -ceq 'APPLY'){$result=Set-NetBoostCS2ProcessPriority -ExePath $ExePath -IncludeDiscord}else{Write-Host $ui.Cancelled}}
                '5' {$path=if($InputReader){[string](& $InputReader $ui.Nip)}else{Read-Host $ui.Nip};$audit=Get-NetBoostNipAudit -Path $path.Trim('"');$audit|ConvertTo-Json -Depth 8|Write-Host}
                '6' {foreach($line in $ui.TipLines){Write-Host ('  - '+$line)}}
                '7' {$result=Restore-NetBoostCS2Priority}
                default {Write-Host 'Invalid choice.'}
            }
            if($null -ne $result){if($result.Success){Write-Host ($ui.Saved+$result.BackupPath) -ForegroundColor Green;if($result.Effective){Write-Host $result.Effective}}else{Write-Host ($ui.Failed+($result.Errors -join '; ')) -ForegroundColor Red}}
        } catch {Write-Host ($ui.Failed+$_.Exception.Message) -ForegroundColor Red}
        if(-not $InputReader){[void](Read-Host 'Enter')}
    }
}
