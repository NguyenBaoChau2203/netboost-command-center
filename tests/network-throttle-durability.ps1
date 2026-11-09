#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $repoRoot 'src\powershell\NetBoost.NetworkThrottle.ps1')
$fixtureRoot = Join-Path $repoRoot ('build\throttle-durability-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixtureRoot)
$results = [Collections.Generic.List[object]]::new()
function New-TestState { return @{ NetworkThrottlingIndex=10; SystemResponsiveness=20; AutoTuningLevel='Normal'; RSS='Enabled'; NonBestEffortLimit=$null; DODownloadMode=$null; LinkSpeed='1 Gbps' } }
function Check { param([string]$Name,[scriptblock]$Action) try { & $Action; $results.Add(@{name=$Name;ok=$true}) } catch { $results.Add(@{name=$Name;ok=$false;error=$_.Exception.Message}) } }
function Require { param([bool]$Condition,[string]$Message) if(-not $Condition){ throw $Message } }
try {
    Check 'restore without baseline refuses to reset unknown configuration' {
        $state=New-TestState;$state.NetworkThrottlingIndex=50;$state.SystemResponsiveness=40;$state.NonBestEffortLimit=20
        $result=Restore-NetworkThrottle -StateOverride $state -BackupFilePath (Join-Path $fixtureRoot 'missing-baseline.json')
        Require (-not $result.Success -and $state.NetworkThrottlingIndex -eq 50 -and $state.SystemResponsiveness -eq 40 -and $state.NonBestEffortLimit -eq 20) 'Restore without a backup must not apply guessed Windows defaults.'
    }
    Check 'network optimize preserves existing QoS voice policy' {
        $state=New-TestState;$state.NonBestEffortLimit=20
        $status=Get-NetworkThrottleStatus -StateOverride $state
        Require (($status.Items|Where-Object Id -eq 'qos-limit').Status -eq 'Optimal') 'A valid QoS reservation ceiling is not evidence of a fixed bandwidth loss.'
        $result=Optimize-NetworkThrottle -StateOverride $state -BackupFilePath (Join-Path $fixtureRoot 'qos.json')
        Require ($result.Success -and $state.NonBestEffortLimit -eq 20) 'Network optimize must not disable existing QoS guarantees used by voice/media.'
    }
    Check 'reject typed-invalid and unknown backups before any change' {
        foreach($badValue in @('Unknown',@('Enabled','Disabled'))) {
            $state = New-TestState
            $state.RSS = $badValue
            $path = Join-Path $fixtureRoot ('invalid-' + [guid]::NewGuid().ToString('N') + '.json')
            [IO.File]::WriteAllText($path,(@{Timestamp=(Get-Date -Format o);Restored=$false;State=$state}|ConvertTo-Json -Depth 5))
            Require (-not (Test-NetworkThrottleBackupFile $path).Valid) 'Malformed RSS must not be accepted as a restorable baseline.'
        }
    }
    Check 'unknown live state blocks optimize' {
        $state=New-TestState; $state.AutoTuningLevel='Unknown'
        $result=Optimize-NetworkThrottle -StateOverride $state -BackupFilePath (Join-Path $fixtureRoot 'unknown.json')
        Require (-not $result.Success -and $state.NetworkThrottlingIndex -eq 10) 'Unknown original TCP state must not authorize an irreversible apply.'
    }
    Check 'completion persistence failure is reported and baseline stays valid' {
        $state=New-TestState; $path=Join-Path $fixtureRoot 'locked.json'
        $null=Optimize-NetworkThrottle -StateOverride $state -BackupFilePath $path
        $original=[IO.File]::ReadAllText($path)
        $lock=[IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
        try {
            $result=Restore-NetworkThrottle -StateOverride $state -BackupFilePath $path
            Require (-not $result.Success) 'Failed backup bookkeeping must be visible to the user.'
            Require ($original -ceq [IO.File]::ReadAllText($path)) 'Locked baseline must not be truncated.'
        } finally { $lock.Dispose() }
    }
    Check 'dry-run optimize has no file or state mutation' {
        $state=New-TestState; $path=Join-Path $fixtureRoot 'dry-optimize.json'
        $null=Optimize-NetworkThrottle -StateOverride $state -BackupFilePath $path -ApplyChanges $false
        Require ($state.NetworkThrottlingIndex -eq 10 -and -not (Test-Path -LiteralPath $path)) 'ApplyChanges=false must not write backup or alter overrides.'
    }
    Check 'dry-run restore does not consume baseline' {
        $state=New-TestState; $path=Join-Path $fixtureRoot 'dry-restore.json'
        $null=Optimize-NetworkThrottle -StateOverride $state -BackupFilePath $path
        $original=[IO.File]::ReadAllText($path)
        $null=Restore-NetworkThrottle -StateOverride $state -BackupFilePath $path -ApplyChanges $false
        Require ($state.NetworkThrottlingIndex -eq [uint32]::MaxValue -and $original -ceq [IO.File]::ReadAllText($path)) 'Dry restore must not change settings or mark baseline completed.'
    }
} finally {
    $resolved=[IO.Path]::GetFullPath($fixtureRoot)
    if(-not $resolved.StartsWith($repoRoot+'\build\throttle-durability-',[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe test cleanup path'}
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
$failed=@($results|Where-Object{-not $_.ok}).Count
@{ok=($failed -eq 0);checks=$results.Count;failed=$failed;results=@($results)}|ConvertTo-Json -Depth 6
if($failed){exit 1}
