[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $repoRoot 'src\powershell\NetBoost_Command_Center.ps1'

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

. $scriptPath '--help' | Out-Null

Assert-True ($null -ne (Get-Command Test-SafeCleanupRoot -ErrorAction SilentlyContinue)) 'Test-SafeCleanupRoot is not implemented.'
Assert-True ($null -ne (Get-Command Test-CleanupCandidatePath -ErrorAction SilentlyContinue)) 'Test-CleanupCandidatePath is not implemented.'
Assert-True ($null -ne (Get-Command Test-CleanupFileEligible -ErrorAction SilentlyContinue)) 'Test-CleanupFileEligible is not implemented.'
Assert-True ($null -ne (Get-Command Invoke-WithTemporarilyStoppedServices -ErrorAction SilentlyContinue)) 'Invoke-WithTemporarilyStoppedServices is not implemented.'

$serviceStates = @{
    wuauserv = 'Running'
    BITS = 'Stopped'
}
$serviceEvents = [Collections.Generic.List[string]]::new()
$serviceStateReader = {
    param([string]$Name)
    $serviceEvents.Add("get:$Name") | Out-Null
    return [pscustomobject]@{ Name = $Name; Status = $serviceStates[$Name] }
}
$serviceStopper = {
    param([string]$Name)
    $serviceEvents.Add("stop:$Name") | Out-Null
    $serviceStates[$Name] = 'Stopped'
}
$serviceStarter = {
    param([string]$Name)
    $serviceEvents.Add("start:$Name") | Out-Null
    $serviceStates[$Name] = 'Running'
}

Invoke-WithTemporarilyStoppedServices -ServiceNames @('wuauserv', 'BITS') -Action {
    $serviceEvents.Add('action') | Out-Null
} -GetServiceState $serviceStateReader -StopService $serviceStopper -StartService $serviceStarter
Assert-True (($serviceEvents -join ',') -eq 'get:wuauserv,get:BITS,stop:wuauserv,get:wuauserv,action,get:wuauserv,start:wuauserv,get:wuauserv') 'All original states must be captured before any service is stopped, and stop/start states must be verified.'
Assert-True ($serviceStates.wuauserv -eq 'Running' -and $serviceStates.BITS -eq 'Stopped') 'The original running/stopped service states must be restored exactly.'

$failureEvents = [Collections.Generic.List[string]]::new()
$failureStates = @{ wuauserv = 'Running' }
$actionFailureRethrown = $false
try {
    Invoke-WithTemporarilyStoppedServices -ServiceNames @('wuauserv') -Action {
        $failureEvents.Add('action') | Out-Null
        throw 'simulated cleanup failure'
    } -GetServiceState {
        param([string]$Name)
        $failureEvents.Add("get:$Name") | Out-Null
        return [pscustomobject]@{ Name = $Name; Status = $failureStates[$Name] }
    } -StopService {
        param([string]$Name)
        $failureEvents.Add("stop:$Name") | Out-Null
        $failureStates[$Name] = 'Stopped'
    } -StartService {
        param([string]$Name)
        $failureEvents.Add("start:$Name") | Out-Null
        $failureStates[$Name] = 'Running'
    }
} catch {
    $actionFailureRethrown = $_.Exception.Message -eq 'simulated cleanup failure'
}
Assert-True $actionFailureRethrown 'A cleanup action failure must be rethrown after service restoration.'
Assert-True ($failureStates.wuauserv -eq 'Running') 'An originally running service must be restored when cleanup fails.'

$stopFailureEvents = [Collections.Generic.List[string]]::new()
$stopFailureStates = @{ wuauserv = 'Running'; BITS = 'Running' }
$stopFailureRethrown = $false
try {
    Invoke-WithTemporarilyStoppedServices -ServiceNames @('wuauserv', 'BITS') -Action {
        $stopFailureEvents.Add('action') | Out-Null
    } -GetServiceState {
        param([string]$Name)
        $stopFailureEvents.Add("get:$Name") | Out-Null
        return [pscustomobject]@{ Name = $Name; Status = $stopFailureStates[$Name] }
    } -StopService {
        param([string]$Name)
        $stopFailureEvents.Add("stop:$Name") | Out-Null
        if ($Name -eq 'BITS') {
            throw 'simulated stop failure'
        }
        $stopFailureStates[$Name] = 'Stopped'
    } -StartService {
        param([string]$Name)
        $stopFailureEvents.Add("start:$Name") | Out-Null
        $stopFailureStates[$Name] = 'Running'
    }
} catch {
    $stopFailureRethrown = $_.Exception.Message -eq 'simulated stop failure'
}
Assert-True $stopFailureRethrown 'A service stop failure must abort and be rethrown.'
Assert-True (-not ($stopFailureEvents -contains 'action')) 'A stop failure must abort before cleanup starts.'
Assert-True ($stopFailureStates.wuauserv -eq 'Running' -and $stopFailureStates.BITS -eq 'Running') 'A stop failure must restore the original states without restarting a service that never stopped.'

$stuckStopState = @{ wuauserv = 'Running' }
$stuckStopActionRan = $false
$stuckStopRejected = $false
try {
    Invoke-WithTemporarilyStoppedServices -ServiceNames @('wuauserv') -Action {
        $stuckStopActionRan = $true
    } -GetServiceState {
        param([string]$Name)
        return [pscustomobject]@{ Name = $Name; Status = $stuckStopState[$Name] }
    } -StopService {
        param([string]$Name)
        # Simulate Stop-Service returning while the service is still running.
    } -StartService {
        param([string]$Name)
        $stuckStopState[$Name] = 'Running'
    }
} catch {
    $stuckStopRejected = $_.Exception.Message -like '*did not reach Stopped*'
}
Assert-True $stuckStopRejected 'Cleanup must abort when a required service does not reach Stopped.'
Assert-True (-not $stuckStopActionRan) 'Cleanup must not run while a required service is still running.'

$stuckRestoreState = @{ wuauserv = 'Running' }
$stuckRestoreRejected = $false
try {
    Invoke-WithTemporarilyStoppedServices -ServiceNames @('wuauserv') -Action { } -GetServiceState {
        param([string]$Name)
        return [pscustomobject]@{ Name = $Name; Status = $stuckRestoreState[$Name] }
    } -StopService {
        param([string]$Name)
        $stuckRestoreState[$Name] = 'Stopped'
    } -StartService {
        param([string]$Name)
        # Simulate Start-Service returning while the service remains stopped.
    }
} catch {
    $stuckRestoreRejected = $_.Exception.Message -like 'Failed to restore Windows service state*'
}
Assert-True $stuckRestoreRejected 'A service that does not return to Running must fail the transaction.'

$sandboxRoot = Join-Path ([IO.Path]::GetTempPath()) ("NetBoost-Cleanup-Safety-{0}" -f [guid]::NewGuid().ToString('N'))
$siblingRoot = "$sandboxRoot-sibling"

try {
    $null = New-Item -ItemType Directory -Path $sandboxRoot -Force
    $null = New-Item -ItemType Directory -Path $siblingRoot -Force
    $childPath = Join-Path $sandboxRoot 'nested\old.pf'
    $recentPath = Join-Path $sandboxRoot 'nested\recent.pf'
    $layoutPath = Join-Path $sandboxRoot 'nested\Layout.ini'
    $readyBootPath = Join-Path $sandboxRoot 'ReadyBoot\old.pf'
    $siblingPath = Join-Path $siblingRoot 'outside.pf'
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $childPath) -Force
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $readyBootPath) -Force
    $null = New-Item -ItemType File -Path $childPath -Force
    $null = New-Item -ItemType File -Path $recentPath -Force
    $null = New-Item -ItemType File -Path $layoutPath -Force
    $null = New-Item -ItemType File -Path $readyBootPath -Force
    $null = New-Item -ItemType File -Path $siblingPath -Force

    (Get-Item -LiteralPath $childPath).LastWriteTime = (Get-Date).AddDays(-31)
    (Get-Item -LiteralPath $recentPath).LastWriteTime = (Get-Date).AddDays(-1)
    (Get-Item -LiteralPath $layoutPath).LastWriteTime = (Get-Date).AddDays(-31)
    (Get-Item -LiteralPath $readyBootPath).LastWriteTime = (Get-Date).AddDays(-31)

    Assert-True (Test-SafeCleanupRoot -Path $sandboxRoot) 'A dedicated cleanup sandbox should be accepted as a safe root.'
    Assert-True (-not (Test-SafeCleanupRoot -Path ([IO.Path]::GetPathRoot($sandboxRoot)))) 'A drive root must never be accepted as a cleanup root.'
    Assert-True (-not (Test-SafeCleanupRoot -Path $env:USERPROFILE)) 'The user profile root must never be accepted as a cleanup root.'
    Assert-True (-not (Test-SafeCleanupRoot -Path $env:WINDIR)) 'The Windows root must never be accepted as a cleanup root.'

    Assert-True (Test-CleanupCandidatePath -Root $sandboxRoot -Candidate $childPath) 'A child file should stay within its cleanup root.'
    Assert-True (-not (Test-CleanupCandidatePath -Root $sandboxRoot -Candidate $siblingPath)) 'A sibling path must not pass the cleanup root boundary check.'

    Assert-True (Test-CleanupFileEligible -FileInfo (Get-Item -LiteralPath $childPath) -Root $sandboxRoot -MinAgeMinutes 43200 -IncludePatterns @('*.pf')) 'An old .pf file should be eligible for deep Prefetch cleanup.'
    Assert-True (-not (Test-CleanupFileEligible -FileInfo (Get-Item -LiteralPath $recentPath) -Root $sandboxRoot -MinAgeMinutes 43200 -IncludePatterns @('*.pf'))) 'A recent .pf file must be preserved.'
    Assert-True (-not (Test-CleanupFileEligible -FileInfo (Get-Item -LiteralPath $layoutPath) -Root $sandboxRoot -MinAgeMinutes 43200 -IncludePatterns @('*.pf'))) 'Layout.ini must not match the Prefetch cleanup pattern.'
    Assert-True (-not (Test-CleanupFileEligible -FileInfo (Get-Item -LiteralPath $readyBootPath) -Root $sandboxRoot -MinAgeMinutes 43200 -IncludePatterns @('*.pf') -ExcludePathSegments @('ReadyBoot'))) 'ReadyBoot must always be excluded from Prefetch cleanup.'

    $prefetchSafeModeRejected = $false
    try {
        Start-WebCleanupJob -TargetIds @('windows-prefetch') -Deep $false -Confirmed $true | Out-Null
    } catch {
        $prefetchSafeModeRejected = $_.Exception.Message -like 'Deep mode is required*'
    }
    Assert-True $prefetchSafeModeRejected 'A deep-only target must be rejected in safe mode.'

    $windowsUpdateSafeModeRejected = $false
    try {
        Start-WebCleanupJob -TargetIds @('windows-update-downloads') -Deep $false -Confirmed $true | Out-Null
    } catch {
        $windowsUpdateSafeModeRejected = $_.Exception.Message -like 'Deep mode is required*'
    }
    Assert-True $windowsUpdateSafeModeRejected 'Windows Update downloads must be rejected in safe mode.'

    $unsupportedTargetRejected = $false
    try {
        Start-WebCleanupJob -TargetIds @('not-a-cleanup-target') -Deep $false -Confirmed $true | Out-Null
    } catch {
        $unsupportedTargetRejected = $_.Exception.Message -like '*supported cleanup targets*'
    }
    Assert-True $unsupportedTargetRejected 'An unsupported cleanup target must be rejected before a job starts.'

    [pscustomobject]@{
        ok = $true
        rootGuard = 'verified'
        candidateBoundary = 'verified'
        prefetchPolicy = 'verified'
        deepOnlyGuard = 'verified'
        windowsUpdateServiceTransaction = 'verified'
        supportedTargetGuard = 'verified'
    } | ConvertTo-Json
} finally {
    Remove-Item -LiteralPath $sandboxRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $siblingRoot -Recurse -Force -ErrorAction SilentlyContinue
}
