#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$entrypoint = Join-Path $repoRoot 'src\powershell\NetBoost_Command_Center.ps1'
$throttleModule = Join-Path $repoRoot 'src\powershell\NetBoost.NetworkThrottle.ps1'

$script:assertions = 0
function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "Assertion failed: $Message" }
    $script:assertions++
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Message)
    if ($Expected -cne $Actual) {
        throw "Assertion failed: $Message. Expected '$Expected', got '$Actual'."
    }
    $script:assertions++
}

# 1. Module file must exist and be loadable
Assert-True (Test-Path -LiteralPath $throttleModule -PathType Leaf) "NetBoost.NetworkThrottle.ps1 must exist at $throttleModule"

. $throttleModule

# 2. Check essential exported functions
foreach ($cmd in @('Get-NetworkThrottleDefinitions', 'Get-NetworkThrottleStatus', 'Optimize-NetworkThrottle', 'Restore-NetworkThrottle', 'Show-NetworkThrottleCenter')) {
    Assert-True ($null -ne (Get-Command $cmd -ErrorAction SilentlyContinue)) "Function $cmd must be defined."
}

# 3. Test Definitions
$defs = @(Get-NetworkThrottleDefinitions)
Assert-True ($defs.Count -ge 6) "Definitions must have at least 6 audit items."
$defIds = $defs.Id
Assert-True ($defIds -contains 'network-throttling-index') "Definitions must contain network-throttling-index"
Assert-True ($defIds -contains 'system-responsiveness') "Definitions must contain system-responsiveness"
Assert-True ($defIds -contains 'tcp-autotuning') "Definitions must contain tcp-autotuning"
Assert-True ($defIds -contains 'receive-side-scaling') "Definitions must contain receive-side-scaling"
Assert-True ($defIds -contains 'qos-limit') "Definitions must contain qos-limit"
Assert-True ($defIds -contains 'delivery-optimization') "Definitions must contain delivery-optimization"

# 4. Test In-Memory / Mock Registry & State Diagnostic
$mockState = @{
    NetworkThrottlingIndex = 10
    SystemResponsiveness = 20
    AutoTuningLevel = 'Disabled'
    RSS = 'Disabled'
    NonBestEffortLimit = 20
    DODownloadMode = 3
    LinkSpeed = '100 Mbps'
}

$status = Get-NetworkThrottleStatus -StateOverride $mockState
Assert-True ($null -ne $status) "Status object must not be null"
Assert-True ($status.Items.Count -ge 6) "Status must contain evaluated items"

$throttlingItem = $status.Items | Where-Object Id -eq 'network-throttling-index'
Assert-Equal 'Throttled' $throttlingItem.Status "NetworkThrottlingIndex=10 must be marked as Throttled"

$autoTuningItem = $status.Items | Where-Object Id -eq 'tcp-autotuning'
Assert-Equal 'Throttled' $autoTuningItem.Status "AutoTuningLevel=Disabled must be marked as Throttled"

$rssItem = $status.Items | Where-Object Id -eq 'receive-side-scaling'
Assert-Equal 'Warning' $rssItem.Status "RSS=Disabled must be marked as Warning"

$doItem = $status.Items | Where-Object Id -eq 'delivery-optimization'
Assert-Equal 'Warning' $doItem.Status "DODownloadMode=3 (Internet P2P) must be marked as Warning"

$linkItem = $status.Items | Where-Object Id -eq 'link-speed'
Assert-Equal 'Warning' $linkItem.Status "LinkSpeed=100 Mbps must be marked as Warning"
Assert-True ($status.IssuesCount -gt 0) "IssuesCount must include warnings such as 100 Mbps link speed"

# 4b. Test Healthy Summary accounting
$healthyState = @{
    NetworkThrottlingIndex = [uint32]::MaxValue
    SystemResponsiveness = 10
    AutoTuningLevel = 'Normal'
    RSS = 'Enabled'
    NonBestEffortLimit = $null
    DODownloadMode = 0
    LinkSpeed = '1 Gbps'
}
$healthyStatus = Get-NetworkThrottleStatus -StateOverride $healthyState
Assert-Equal 0 $healthyStatus.IssuesCount "All optimal state must report 0 issues"

# 5. Test Backup, Baseline Preservation, and Optimization (Isolated with Mock State)
$tempBackupDir = Join-Path ([System.IO.Path]::GetTempPath()) ("netboost-throttle-test-" + [System.Guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($tempBackupDir) | Out-Null
$testBackupPath = Join-Path $tempBackupDir 'test-backup.json'

try {
    $appliedState = $mockState.Clone()
    $optResult = Optimize-NetworkThrottle -StateOverride $appliedState -BackupFilePath $testBackupPath -ApplyChanges $true

    Assert-True ($optResult.Success) "Optimize should return success"
    Assert-True (Test-Path -LiteralPath $testBackupPath -PathType Leaf) "Backup file must be created before optimizing"

    # Verify state values were modified to optimal
    Assert-Equal ([uint32]::MaxValue) $appliedState.NetworkThrottlingIndex "NetworkThrottlingIndex must be set to [uint32]::MaxValue"
    Assert-Equal 10 $appliedState.SystemResponsiveness "SystemResponsiveness must be set to valid minimum (10)"
    Assert-Equal 'Normal' $appliedState.AutoTuningLevel "AutoTuningLevel must be set to Normal"
    Assert-Equal 'Enabled' $appliedState.RSS "RSS must be set to Enabled"
    Assert-Equal 20 $appliedState.NonBestEffortLimit "Existing QoS policy must be preserved"
    Assert-Equal 0 $appliedState.DODownloadMode "DODownloadMode must be set to 0"

    # Second optimize call MUST NOT overwrite the baseline backup
    $firstBackupContent = [IO.File]::ReadAllText($testBackupPath)
    $null = Optimize-NetworkThrottle -StateOverride $appliedState -BackupFilePath $testBackupPath -ApplyChanges $true
    $secondBackupContent = [IO.File]::ReadAllText($testBackupPath)
    Assert-Equal $firstBackupContent $secondBackupContent "Repeated optimize calls must preserve the original baseline backup"

    # Verify Revert restores old state from backup
    $restoreResult = Restore-NetworkThrottle -StateOverride $appliedState -BackupFilePath $testBackupPath -ApplyChanges $true
    Assert-True ($restoreResult.Success) "Restore should return success"
    Assert-Equal 10 $appliedState.NetworkThrottlingIndex "NetworkThrottlingIndex must be restored to 10"
    Assert-Equal 20 $appliedState.SystemResponsiveness "SystemResponsiveness must be restored to 20"
    Assert-Equal 'Disabled' $appliedState.AutoTuningLevel "AutoTuningLevel must be restored to Disabled"
    Assert-Equal 'Disabled' $appliedState.RSS "RSS must be restored to Disabled"
    Assert-Equal 20 $appliedState.NonBestEffortLimit "NonBestEffortLimit must be restored to 20"
    Assert-Equal 3 $appliedState.DODownloadMode "DODownloadMode must be restored to 3"

    # Verify absent property restore ($null properties)
    $absentState = @{
        NetworkThrottlingIndex = $null
        SystemResponsiveness = $null
        AutoTuningLevel = 'Normal'
        RSS = 'Enabled'
        NonBestEffortLimit = $null
        DODownloadMode = $null
        LinkSpeed = '1 Gbps'
    }
    $absentBackupPath = Join-Path $tempBackupDir 'absent-backup.json'
    Backup-NetworkThrottleState -State $absentState -Path $absentBackupPath
    $modState = @{
        NetworkThrottlingIndex = [uint32]::MaxValue
        SystemResponsiveness = 10
        AutoTuningLevel = 'Normal'
        RSS = 'Enabled'
        NonBestEffortLimit = 0
        DODownloadMode = 0
    }
    $restoreAbsent = Restore-NetworkThrottle -StateOverride $modState -BackupFilePath $absentBackupPath -ApplyChanges $true
    Assert-True ($restoreAbsent.Success) "Restore absent properties must succeed"
    Assert-True ($null -eq $modState.NetworkThrottlingIndex) "Absent NetworkThrottlingIndex must be restored to null"
    Assert-True ($null -eq $modState.SystemResponsiveness) "Absent SystemResponsiveness must be restored to null"
    Assert-True ($null -eq $modState.DODownloadMode) "Absent DODownloadMode must be restored to null"

    # Verify Restore without backup does not set DODownloadMode to 3
    $nonExistentBackupPath = Join-Path $tempBackupDir 'does-not-exist.json'
    $noBackupState = @{
        DODownloadMode = 0
    }
    $restoreNoBackup = Restore-NetworkThrottle -StateOverride $noBackupState -BackupFilePath $nonExistentBackupPath -ApplyChanges $true
    Assert-True (-not $restoreNoBackup.Success -and $noBackupState.DODownloadMode -eq 0) "Restore without backup must refuse to reset configuration"

    # Verify corrupt backup rejection
    $corruptPath = Join-Path $tempBackupDir 'corrupt.json'
    [System.IO.File]::WriteAllText($corruptPath, '{')
    $corruptOpt = Optimize-NetworkThrottle -StateOverride $appliedState -BackupFilePath $corruptPath -ApplyChanges $true
    Assert-True (-not $corruptOpt.Success) "Optimize must reject corrupt existing backup"
    $corruptRes = Restore-NetworkThrottle -StateOverride $appliedState -BackupFilePath $corruptPath -ApplyChanges $true
    Assert-True (-not $corruptRes.Success) "Restore must reject corrupt backup"

    # Verify unwritable backup path stops optimization
    $blockedFile = Join-Path $tempBackupDir 'parent-file'
    [System.IO.File]::WriteAllText($blockedFile, 'x')
    $unwritablePath = Join-Path $blockedFile 'backup.json'
    $unwritableOpt = Optimize-NetworkThrottle -StateOverride $appliedState -BackupFilePath $unwritablePath -ApplyChanges $true
    Assert-True (-not $unwritableOpt.Success) "Optimize must fail when backup cannot be written"

    # Verify multi-cycle baseline capture
    $cyclePath = Join-Path $tempBackupDir 'cycle.json'
    $cycleState = @{
        NetworkThrottlingIndex = 10
        SystemResponsiveness = 20
        AutoTuningLevel = 'Disabled'
        RSS = 'Disabled'
        NonBestEffortLimit = $null
        DODownloadMode = $null
        LinkSpeed = '1 Gbps'
    }
    $null = Optimize-NetworkThrottle -StateOverride $cycleState -BackupFilePath $cyclePath -ApplyChanges $true
    $null = Restore-NetworkThrottle -StateOverride $cycleState -BackupFilePath $cyclePath -ApplyChanges $true
    # User modifies settings before cycle 2
    $cycleState.SystemResponsiveness = 40
    $cycleState.AutoTuningLevel = 'HighlyRestricted'
    $cycleState.DODownloadMode = 1
    $null = Optimize-NetworkThrottle -StateOverride $cycleState -BackupFilePath $cyclePath -ApplyChanges $true
    $cycle2Restore = Restore-NetworkThrottle -StateOverride $cycleState -BackupFilePath $cyclePath -ApplyChanges $true
    Assert-True ($cycle2Restore.Success) "Second cycle restore should succeed"
    Assert-Equal 40 $cycleState.SystemResponsiveness "New cycle must capture new baseline SystemResponsiveness"
    Assert-Equal 'HighlyRestricted' $cycleState.AutoTuningLevel "New cycle must capture new baseline AutoTuningLevel"
    Assert-Equal 1 $cycleState.DODownloadMode "New cycle must capture new baseline DODownloadMode"

    # Verify repeated restore is idempotent
    $repeatRestore = Restore-NetworkThrottle -StateOverride $cycleState -BackupFilePath $cyclePath -ApplyChanges $true
    Assert-True ($repeatRestore.Success) "Repeated restore should be idempotent"

} finally {
    if (Test-Path -LiteralPath $tempBackupDir) {
        Remove-Item -LiteralPath $tempBackupDir -Recurse -Force
    }
}

# 6. Test Main Script Integration (CLI & Localization)
. $entrypoint --help | Out-Null
Assert-True ($T.ContainsKey('Menu20')) "Main script must define Menu20 label for language: $Language"
Assert-True ($T.Menu20 -match 'bóp nghẽn|Throttling|bop nghen|throttl') "Menu20 label should mention network throttling"

# Test CLI Argument Parsing via Parse-Args
$script:RawArgs = @('--check-throttle')
$parsedResult = Parse-Args
Assert-Equal 'CheckThrottle' $parsedResult.Mode "CLI flag --check-throttle must be recognized"

$script:RawArgs = @('--optimize-throttle')
$parsedResult = Parse-Args
Assert-Equal 'OptimizeThrottle' $parsedResult.Mode "CLI flag --optimize-throttle must be recognized"

$script:RawArgs = @('--revert-throttle')
$parsedResult = Parse-Args
Assert-Equal 'RevertThrottle' $parsedResult.Mode "CLI flag --revert-throttle must be recognized"

# Test CLI Check-Throttle execution
$cliOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $entrypoint --check-throttle | Out-String
Assert-True ($cliOutput.Contains('network-throttling-index')) "CLI execution of --check-throttle must print diagnostic"

[pscustomobject]@{
    ok = $true
    assertions = $script:assertions
    module = 'NetBoost.NetworkThrottle'
    diagnosticsVerified = $true
    baselineBackupPreserved = $true
    absentPropertiesRestored = $true
} | ConvertTo-Json
