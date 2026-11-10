#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$entrypoint = Join-Path $repoRoot 'src\powershell\NetBoost_Command_Center.ps1'
. $entrypoint --help | Out-Null
$ErrorActionPreference = 'Stop'
$script:assertions = 0
function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
    $script:assertions++
}

foreach ($path in @('src\web','src\backend','.pnpm-store','.playwright-cli','tests\backend-smoke.ps1','tests\package-manager-policy.ps1')) {
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $repoRoot $path))) "Removed component remains: $path"
}
foreach ($command in @('Start-NetBoostWebBackend','Start-NetBoostTcpBackend','Invoke-NetBoostApiRequest','Get-WebCleanupTargets','Start-WebCleanupJob')) {
    Assert-True ($null -eq (Get-Command $command -ErrorAction SilentlyContinue)) "HTTP-only function must not load: $command"
}
Assert-True ((Get-Command Get-CleanupTargetDefinitions).ScriptBlock.File -eq (Join-Path $repoRoot 'src\powershell\NetBoost.Cleanup.ps1')) 'Cleanup policies must load from the terminal core.'
$targets = @(Get-CleanupTargetDefinitions)
Assert-True ($targets.Count -eq 15) 'Terminal cleanup must retain all 15 supported targets.'
Assert-True (($targets | Where-Object id -eq 'windows-update-downloads').deepOnly) 'Windows Update cleanup must retain its advanced-only policy.'

foreach ($lang in @('en','vi')) {
    $help = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $entrypoint --lang $lang --help | Out-String
    Assert-True ($LASTEXITCODE -eq 0) "Help failed for $lang."
    Assert-True ($help.Contains('NetBoost Command Center v1.2.1')) 'Terminal help must identify the published application version.'
    Assert-True ($help -notmatch '--web|--port|47812|Web UI') 'Help must describe terminal commands only.'
    Assert-True ($help.Contains('--mole') -and $help.Contains('--win11debloat') -and $help.Contains('--dashboard')) 'Help must retain the existing tool and terminal dashboard commands.'
}
foreach ($arguments in @(@('--web'), @('-web'), @('--port','47812'), @('-port','47812'), @('--web','--mole'), @('--not-supported'))) {
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $entrypoint @arguments 2>&1 | Out-String
    Assert-True ($LASTEXITCODE -eq 2) "Unsupported arguments must exit 2 instead of opening the menu: $($arguments -join ' ')"
    Assert-True ($output -match 'Tham so khong duoc ho tro') 'Unsupported arguments must produce a clear message.'
}

$privatePath = 'C:\Users\Private\Documents\file.tmp'
Assert-True ((Format-CleanupLogPath $privatePath) -eq '...\file.tmp') 'Default cleanup logs must keep parent paths private.'
. $entrypoint --detailed-cleanup-logs --help | Out-Null
$ErrorActionPreference = 'Stop'
Assert-True ((Format-CleanupLogPath $privatePath) -eq $privatePath) 'Detailed cleanup logs must be explicitly enabled from the CLI.'
. $entrypoint --help | Out-Null
$ErrorActionPreference = 'Stop'
Assert-True (-not $script:DetailedCleanupLogs) 'Default launch must reset detailed cleanup logging.'

$script:choices = [Collections.Generic.Queue[string]]::new()
foreach ($choice in @('17','18','19','0')) { $script:choices.Enqueue($choice) }
$script:moleOpened = 0; $script:debloatOpened = 0
function Ensure-Admin { }
function Start-Process { throw 'The terminal menu must not launch a browser or server.' }
Show-Menu -InputReader { $script:choices.Dequeue() } -MoleCenter { $script:moleOpened++ } -DebloatCenter { $script:debloatOpened++ }
Assert-True ($script:moleOpened -eq 1 -and $script:debloatOpened -eq 1) 'Mole and Win11Debloat must retain menu numbers 18 and 19.'
Assert-True (-not $T.ContainsKey('Menu17')) 'Removed Web entry 17 must not have a label.'

[pscustomobject]@{ok=$true;assertions=$script:assertions;mode='terminal-only';cleanupTargets=$targets.Count;legacyWebFlags='rejected';systemChanges=$false} | ConvertTo-Json
