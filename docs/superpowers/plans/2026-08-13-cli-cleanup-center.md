# CLI Cleanup Center Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a safe, fully featured PowerShell CLI Cleanup Center at option `[9]`, correct misleading menu text, and expose guarded advanced cleanup without changing version `1.0.1`.

**Architecture:** Extract cleanup selection validation and per-target dispatch into synchronous backend functions shared by the Web job worker and CLI. Represent CLI actions as declarative target-ID groups so menu rendering, confirmations, shortcuts, and tests use one source of truth. Test all CLI choices through injected input/dispatcher scriptblocks so automated tests never clean the real machine.

**Tech Stack:** Windows PowerShell 5.1, existing local PowerShell backend, custom PowerShell assertion scripts, React/TypeScript verification through pnpm.

## Global Constraints

- Keep the product version at `1.0.1`.
- Keep the current text-only CLI visual style and both Vietnamese-without-accents and English modes.
- Do not change the Web UI layout, cleanup HTTP API contract, or approved Mochi Cat assets.
- Never add a command that runs all advanced cleanup actions together.
- Component Store uses `/StartComponentCleanup` and never `ResetBase`.
- Prefetch deletes only `*.pf` older than 30 days and preserves `ReadyBoot` and `Layout.ini`.
- Windows Update cleanup deletes only contents below `%SystemRoot%\SoftwareDistribution\Download` and restores original `wuauserv` and `BITS` states.

---

## File map

- `src/backend/NetBoost.LocalWeb.ps1`: owns cleanup target definitions, selection validation, and shared synchronous target dispatch.
- `src/powershell/NetBoost_Command_Center.ps1`: owns localized CLI copy, Cleanup Center rendering, confirmation flow, shortcuts, and main-menu routing.
- `tests/cleanup-safety.ps1`: protects backend validation, deep-only gates, path policy, and service restoration.
- `tests/cli-cleanup-center.ps1`: exercises CLI mappings and confirmations with fakes; never invokes real cleanup.
- `tests/README.md`: documents the new safe test command.
- `README.md`: documents the corrected main menu and CLI Cleanup Center for users.

### Task 1: Extract the shared synchronous cleanup dispatcher

**Files:**
- Modify: `src/backend/NetBoost.LocalWeb.ps1:1096-1191`
- Modify: `tests/cleanup-safety.ps1:185-217`

**Interfaces:**
- Produces: `Resolve-CleanupTargetSelection -TargetIds [string[]] -Deep [bool] -Confirmed [bool]` returning validated target definition objects.
- Produces: `Invoke-CleanupTargetSet -TargetIds [string[]] -Deep [bool] -Confirmed [bool] [-JobId [string]] [-OnTargetStart [scriptblock]]` executing target definitions synchronously.
- Consumed by: `Start-WebCleanupJob`, `Invoke-WebCleanupJobWorker`, and Task 2 CLI actions.

- [ ] **Step 1: Write failing validation and wiring assertions**

Add assertions after the existing deep-only checks in `tests/cleanup-safety.ps1`:

```powershell
Assert-True ($null -ne (Get-Command Resolve-CleanupTargetSelection -ErrorAction SilentlyContinue)) 'Shared cleanup selection validation is missing.'
Assert-True ($null -ne (Get-Command Invoke-CleanupTargetSet -ErrorAction SilentlyContinue)) 'Shared synchronous cleanup dispatcher is missing.'

$safeTargets = @(Resolve-CleanupTargetSelection `
    -TargetIds @('user-temp', 'windows-temp') `
    -Deep $false `
    -Confirmed $false)
Assert-True (($safeTargets.id -join ',') -eq 'user-temp,windows-temp') 'Safe targets must resolve in canonical definition order.'

$confirmationRejected = $false
try {
    Resolve-CleanupTargetSelection -TargetIds @('recycle-bin') -Deep $false -Confirmed $false | Out-Null
} catch {
    $confirmationRejected = $_.Exception.Message -like 'Confirmation is required*'
}
Assert-True $confirmationRejected 'Confirmation-required targets must be rejected before dispatch.'

$backendSource = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'src\backend\NetBoost.LocalWeb.ps1')
Assert-True ($backendSource -match 'function\s+Invoke-WebCleanupJobWorker[\s\S]+Invoke-CleanupTargetSet') 'The Web worker must use the shared cleanup dispatcher.'
```

- [ ] **Step 2: Run the safety test and verify it fails**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\cleanup-safety.ps1
```

Expected: FAIL because `Resolve-CleanupTargetSelection` and `Invoke-CleanupTargetSet` do not exist.

- [ ] **Step 3: Implement selection validation once**

Move the validation currently inside `Start-WebCleanupJob` into this function immediately before `Invoke-WebCleanupJobWorker`:

```powershell
function Resolve-CleanupTargetSelection {
    param(
        [string[]]$TargetIds,
        [bool]$Deep,
        [bool]$Confirmed
    )

    $definitions = @(Get-CleanupTargetDefinitions)
    $requestedIds = @($TargetIds | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_)
    } | Sort-Object -Unique)
    $selected = @($definitions | Where-Object { $requestedIds -contains $_.id })

    if ($selected.Count -eq 0) {
        throw 'No supported cleanup targets selected.'
    }
    if ($selected.Count -ne $requestedIds.Count) {
        throw 'One or more cleanup targets are unsupported.'
    }

    $deepOnlySelected = @($selected | Where-Object { $_.deepOnly })
    if (-not $Deep -and $deepOnlySelected.Count -gt 0) {
        throw ('Deep mode is required for: {0}' -f (($deepOnlySelected.id) -join ', '))
    }

    $requiresConfirm = $Deep -or @($selected | Where-Object { $_.requiresConfirmation }).Count -gt 0
    if ($requiresConfirm -and -not $Confirmed) {
        throw 'Confirmation is required for selected cleanup targets.'
    }

    return $selected
}
```

- [ ] **Step 4: Extract per-target dispatch and preserve Web progress**

Create `Invoke-CleanupTargetSet` with the existing `switch ($target.action)` body. Call `Resolve-CleanupTargetSelection` first, invoke `OnTargetStart` with `($target, $index, $selected.Count)`, and keep `Remove-FolderContents` arguments unchanged:

```powershell
function Invoke-CleanupTargetSet {
    param(
        [string[]]$TargetIds,
        [bool]$Deep,
        [bool]$Confirmed,
        [string]$JobId = '',
        [scriptblock]$OnTargetStart = $null
    )

    $selected = @(Resolve-CleanupTargetSelection -TargetIds $TargetIds -Deep $Deep -Confirmed $Confirmed)
    $index = 0
    foreach ($target in $selected) {
        $index++
        if ($null -ne $OnTargetStart) {
            & $OnTargetStart $target $index $selected.Count
        }

        switch ($target.action) {
            'recycle-bin' { Clear-RecycleBin -Force -ErrorAction Stop }
            'delivery-optimization' { Invoke-DeliveryOptimizationCleanup -TargetId $target.id -TargetLabel $target.label -JobId $JobId }
            'component-store' { Invoke-ComponentStoreCleanup -TargetId $target.id -TargetLabel $target.label -JobId $JobId }
            'windows-update-downloads' { Invoke-WindowsUpdateDownloadCleanup -TargetId $target.id -TargetLabel $target.label -JobId $JobId }
            default {
                $minAgeMinutes = if ($Deep) { $target.deepMinAgeMinutes } else { $target.safeMinAgeMinutes }
                foreach ($path in @($target.paths)) {
                    Remove-FolderContents -Path $path -Label $target.label -MinAgeMinutes $minAgeMinutes -IncludePatterns $target.includePatterns -ExcludePathSegments $target.excludePathSegments -TargetId $target.id -JobId $JobId
                }
            }
        }
    }
}
```

Preserve the existing Recycle Bin event logging around `Clear-RecycleBin`. Refactor `Invoke-WebCleanupJobWorker` to call this function with `-Confirmed $true` and an `OnTargetStart` callback that performs the existing `Update-WebJob`. Refactor `Start-WebCleanupJob` to call `Resolve-CleanupTargetSelection` before queue creation instead of duplicating the guards.

- [ ] **Step 5: Run backend safety tests**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\cleanup-safety.ps1
```

Expected: PASS with `deepOnlyGuard`, `windowsUpdateServiceTransaction`, and `supportedTargetGuard` all `verified`.

- [ ] **Step 6: Commit the shared dispatcher**

```powershell
git add src/backend/NetBoost.LocalWeb.ps1 tests/cleanup-safety.ps1
git commit -m "refactor: share cleanup target dispatcher"
```

### Task 2: Add declarative CLI cleanup actions and confirmation behavior

**Files:**
- Create: `tests/cli-cleanup-center.ps1`
- Modify: `src/powershell/NetBoost_Command_Center.ps1:29-175`
- Modify: `src/powershell/NetBoost_Command_Center.ps1:961-1282`

**Interfaces:**
- Consumes: `Get-CleanupTargetDefinitions`, `Invoke-CleanupTargetSet` from Task 1.
- Produces: `Get-CliCleanupActionDefinitions` returning action records with `key`, `targetIds`, `deep`, and `confirmation` (`none`, `y`, `CONFIRM`).
- Produces: `Invoke-CliCleanupSelection -Choice [string] [-ReadInput [scriptblock]] [-CleanupInvoker [scriptblock]]` returning `back`, `cancelled`, `invalid`, or `completed`.
- Produces: `Show-CleanupCenter` interactive submenu.

- [ ] **Step 1: Write the failing isolated CLI test**

Create `tests/cli-cleanup-center.ps1`. Dot-source the app with `--help`, then validate exact action mappings and use fakes:

```powershell
#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$scriptPath = Join-Path $repoRoot 'src\powershell\NetBoost_Command_Center.ps1'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

. $scriptPath '--help' | Out-Null

$actions = @(Get-CliCleanupActionDefinitions)
$safe = $actions | Where-Object key -eq '4'
Assert-True (($safe.targetIds -join ',') -eq 'user-temp,windows-temp,directx-cache,nvidia-cache,steam-cache,thumbnails,inet-cache,delivery-optimization,windows-font-cache,windows-error-reports') 'Recommended safe cleanup contains the wrong targets.'
Assert-True (-not ($safe.targetIds -contains 'recycle-bin')) 'Recommended safe cleanup must exclude Recycle Bin.'
Assert-True (-not ($safe.targetIds -contains 'crash-dumps')) 'Recommended safe cleanup must exclude crash dumps.'

$advanced = @($actions | Where-Object { $_.confirmation -eq 'CONFIRM' })
Assert-True (($advanced.key -join ',') -eq '7,8,9') 'Advanced actions must be keys 7, 8, and 9.'
Assert-True (@($advanced | Where-Object { -not $_.deep }).Count -eq 0) 'Every advanced action must use deep mode.'

$script:dispatches = @()
$fakeInvoker = {
    param([string[]]$TargetIds, [bool]$Deep, [bool]$Confirmed)
    $script:dispatches += [pscustomobject]@{ targetIds = @($TargetIds); deep = $Deep; confirmed = $Confirmed }
}

$result = Invoke-CliCleanupSelection -Choice '8' -ReadInput { param($Prompt) 'no' } -CleanupInvoker $fakeInvoker
Assert-True ($result -eq 'cancelled' -and $script:dispatches.Count -eq 0) 'Invalid advanced confirmation must cancel without dispatch.'

$result = Invoke-CliCleanupSelection -Choice '8' -ReadInput { param($Prompt) 'CONFIRM' } -CleanupInvoker $fakeInvoker
Assert-True ($result -eq 'completed') 'Exact advanced confirmation must complete.'
Assert-True (($script:dispatches[0].targetIds -join ',') -eq 'windows-update-downloads') 'Advanced key 8 must dispatch only Windows Update downloads.'
Assert-True ($script:dispatches[0].deep -and $script:dispatches[0].confirmed) 'Advanced cleanup must dispatch as deep and confirmed.'

$script:dispatches = @()
$result = Invoke-CliCleanupSelection -Choice '6' -ReadInput { param($Prompt) 'n' } -CleanupInvoker $fakeInvoker
Assert-True ($result -eq 'cancelled' -and $script:dispatches.Count -eq 0) 'Recycle Bin cancellation must not dispatch.'
$result = Invoke-CliCleanupSelection -Choice '6' -ReadInput { param($Prompt) 'y' } -CleanupInvoker $fakeInvoker
Assert-True (($script:dispatches[0].targetIds -join ',') -eq 'recycle-bin') 'Confirmed key 6 must dispatch Recycle Bin only.'

$script:dispatches = @()
$result = Invoke-CliCleanupSelection -Choice '4' -ReadInput { param($Prompt) throw 'Safe cleanup must not prompt.' } -CleanupInvoker $fakeInvoker
Assert-True ($result -eq 'completed' -and -not $script:dispatches[0].confirmed) 'Recommended safe cleanup must dispatch without confirmation.'
```

Also assert key `0` returns `back` and invalid keys return `invalid` without dispatch.

- [ ] **Step 2: Run the CLI test and verify it fails**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\cli-cleanup-center.ps1
```

Expected: FAIL because `Get-CliCleanupActionDefinitions` is not defined.

- [ ] **Step 3: Add localized Cleanup Center strings**

Add English and Vietnamese-without-accents strings for:

```powershell
$T.CliCleanupTitle = 'CLI CLEANUP CENTER'
$T.CliCleanupSafe = 'SAFE CLEANUP'
$T.CliCleanupConfirmed = 'CONFIRMATION REQUIRED'
$T.CliCleanupAdvanced = 'ADVANCED CLEANUP'
$T.CliCleanupBack = 'Back to main menu'
$T.CliCleanupAdvancedPrompt = 'Type CONFIRM exactly to continue'
$T.CliCleanupScope = 'Scope'
$T.CliCleanupRisk = 'Risk'
$T.CliCleanupRetention = 'Retention'
```

Provide the corresponding Vietnamese-without-accents values, plus labels for actions 1 through 9. Do not use accented characters because the existing CLI localization contract is accentless.

- [ ] **Step 4: Add action definitions and injected execution**

Implement definitions with these exact mappings:

```powershell
function Get-CliCleanupActionDefinitions {
    return @(
        [pscustomobject]@{ key='1'; targetIds=@('user-temp','windows-temp'); deep=$false; confirmation='none' }
        [pscustomobject]@{ key='2'; targetIds=@('directx-cache','nvidia-cache','steam-cache'); deep=$false; confirmation='none' }
        [pscustomobject]@{ key='3'; targetIds=@('thumbnails','inet-cache','delivery-optimization','windows-font-cache','windows-error-reports'); deep=$false; confirmation='none' }
        [pscustomobject]@{ key='4'; targetIds=@('user-temp','windows-temp','directx-cache','nvidia-cache','steam-cache','thumbnails','inet-cache','delivery-optimization','windows-font-cache','windows-error-reports'); deep=$false; confirmation='none' }
        [pscustomobject]@{ key='5'; targetIds=@('crash-dumps'); deep=$false; confirmation='y' }
        [pscustomobject]@{ key='6'; targetIds=@('recycle-bin'); deep=$false; confirmation='y' }
        [pscustomobject]@{ key='7'; targetIds=@('component-store'); deep=$true; confirmation='CONFIRM' }
        [pscustomobject]@{ key='8'; targetIds=@('windows-update-downloads'); deep=$true; confirmation='CONFIRM' }
        [pscustomobject]@{ key='9'; targetIds=@('windows-prefetch'); deep=$true; confirmation='CONFIRM' }
    )
}
```

`Invoke-CliCleanupSelection` must look up the action, show metadata from `Get-CleanupTargetDefinitions`, collect only the required confirmation, and use case-sensitive `-ceq 'CONFIRM'` for advanced actions. Call the injected invoker as:

```powershell
$confirmed = $action.confirmation -ne 'none'
& $CleanupInvoker ([string[]]$action.targetIds) ([bool]$action.deep) $confirmed
```

The default invoker calls `Invoke-CleanupTargetSet`. Safe actions pass `Confirmed=$false`; confirmed actions pass `Confirmed=$true` only after valid input.

- [ ] **Step 5: Add the submenu loop**

Implement `Show-CleanupCenter` using existing `Write-UiHeader`, `Write-Section`, `Write-MenuItem`, `Read-UiInput`, and `Pause-Back`. After `completed`, `cancelled`, or `invalid`, pause and redraw; on `back`, return without pausing. Catch dispatcher exceptions inside the submenu, show the existing error style, pause, and redraw so a DISM, service-state, safety-root, or locked-path failure does not close the CLI.

- [ ] **Step 6: Run the isolated CLI test**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\cli-cleanup-center.ps1
```

Expected: PASS with no Administrator prompt and no cleanup event against real paths.

- [ ] **Step 7: Commit the Cleanup Center behavior**

```powershell
git add src/powershell/NetBoost_Command_Center.ps1 tests/cli-cleanup-center.ps1
git commit -m "feat: add guarded CLI cleanup center"
```

### Task 3: Correct main-menu copy and route shortcuts through shared targets

**Files:**
- Modify: `src/powershell/NetBoost_Command_Center.ps1:32-143`
- Modify: `src/powershell/NetBoost_Command_Center.ps1:961-1282`
- Modify: `src/powershell/NetBoost_Command_Center.ps1:1364-1425`
- Modify: `tests/cli-cleanup-center.ps1`
- Modify: `tests/README.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: `Show-CleanupCenter`, `Invoke-CleanupTargetSet`.
- Produces: honest main-menu text and confirmed shortcut `[13]`.

- [ ] **Step 1: Add failing source-level menu assertions**

Append to `tests/cli-cleanup-center.ps1`:

```powershell
$source = Get-Content -Raw -LiteralPath $scriptPath
Assert-True ($source.Contains('dashboard does not auto-run, view it by selecting option 15')) 'English Dashboard hint must point to option 15.'
Assert-True ($source.Contains('chi xem khi ban chon muc 15')) 'Vietnamese Dashboard hint must point to option 15.'
Assert-True ($source -match "'9'\s*\{\s*Show-CleanupCenter") 'Main-menu option 9 must open Cleanup Center.'
Assert-True (-not $source.Contains('Xoa TAT CA bo nho dem')) 'The misleading all-cache label must be removed.'
Assert-True (-not $source.Contains('Clear ALL system caches & Recycle Bin')) 'The misleading English all-cache label must be removed.'
```

Add a mocked shortcut assertion proving `Clean-RecycleBin` cancels on `n` and dispatches only `recycle-bin` on `y`.

- [ ] **Step 2: Run the CLI test and verify the new assertions fail**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\cli-cleanup-center.ps1
```

Expected: FAIL because the Dashboard hint still says 16 and option 9 still calls `Clean-All`.

- [ ] **Step 3: Correct localized main-menu text and routing**

Make these behavioral changes:

```powershell
$T.HeaderSubtitle = 'Quick view: dashboard does not auto-run, view it by selecting option 15.'
$T.Menu9 = 'Open CLI Cleanup Center (Safe / Advanced)'
$T.Menu10 = 'Clean Windows & User Temp files older than 24 hours'
$T.Menu12 = 'Clean basic Windows system cache'
$T.Menu13 = 'Empty Recycle Bin (confirmation required)'
```

Provide equivalent Vietnamese-without-accents strings. Change main-menu dispatch to:

```powershell
'9' { Show-CleanupCenter }
```

Do not call `Pause-Back` after `Show-CleanupCenter`, because the submenu owns its own pause/redraw loop.

- [ ] **Step 4: Make shortcuts thin wrappers over target IDs**

Replace independent path lists in shortcuts with the shared target dispatcher:

```powershell
function Clean-Temp {
    Invoke-CleanupTargetSet -TargetIds @('user-temp','windows-temp') -Deep $false -Confirmed $false
}

function Clean-Game {
    Invoke-CleanupTargetSet -TargetIds @('directx-cache','nvidia-cache','steam-cache') -Deep $false -Confirmed $false
}

function Clean-System {
    Invoke-CleanupTargetSet -TargetIds @('thumbnails','inet-cache','delivery-optimization','windows-font-cache','windows-error-reports') -Deep $false -Confirmed $false
}
```

Implement `Clean-RecycleBin` as a thin call to `Invoke-CliCleanupSelection -Choice '6'`, with optional injected scriptblocks for its test. Remove or replace the unused `Clean-All` so no function claims to clear everything.

- [ ] **Step 5: Document the CLI behavior**

In `README.md`, document that `[9]` opens Safe, Confirmed, and Advanced cleanup groups; list Windows Update downloads, Component Store, and Prefetch under Advanced; state that advanced actions require exact `CONFIRM` and cannot run as a combined group.

In `tests/README.md`, add:

```powershell
.\tests\cli-cleanup-center.ps1
```

Explain that it injects fake input and a fake cleanup dispatcher and never deletes real files.

- [ ] **Step 6: Run focused tests**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\cli-cleanup-center.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\cleanup-safety.ps1
```

Expected: both PASS.

- [ ] **Step 7: Commit menu corrections and documentation**

```powershell
git add src/powershell/NetBoost_Command_Center.ps1 tests/cli-cleanup-center.ps1 tests/README.md README.md
git commit -m "fix: clarify CLI cleanup menu"
```

### Task 4: Run full verification and inspect release invariants

**Files:**
- Verify: `src/powershell/NetBoost_Command_Center.ps1`
- Verify: `src/backend/NetBoost.LocalWeb.ps1`
- Verify: `src/web/package.json`
- Verify: all tracked changes

**Interfaces:**
- Consumes: all prior task outputs.
- Produces: verified CLI/Web cleanup parity with version `1.0.1` unchanged.

- [ ] **Step 1: Parse both PowerShell production scripts**

Run:

```powershell
$parseFailures = @()
foreach ($path in @('.\src\powershell\NetBoost_Command_Center.ps1', '.\src\backend\NetBoost.LocalWeb.ps1')) {
    $tokens = $null
    $errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile((Resolve-Path $path), [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) { $parseFailures += $errors }
}
if ($parseFailures.Count -gt 0) { throw ($parseFailures | Out-String) }
```

Expected: no output and exit code 0.

- [ ] **Step 2: Run all PowerShell test suites**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\cli-cleanup-center.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\cleanup-safety.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\backend-smoke.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\branding-assets.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\package-manager-policy.ps1
```

Expected: every command exits 0; backend smoke reports version `1.0.1` and 15 cleanup targets.

- [ ] **Step 3: Run frontend verification with pnpm**

Run:

```powershell
pnpm --dir .\src\web lint
pnpm --dir .\src\web build
```

Expected: lint and production build exit 0.

- [ ] **Step 4: Verify version and review the diff**

Run:

```powershell
$package = Get-Content -Raw .\src\web\package.json | ConvertFrom-Json
if ($package.version -ne '1.0.1') { throw 'Version changed unexpectedly.' }
git diff --check 767a437..HEAD
git status --short
git log -5 --oneline
```

Expected: version is `1.0.1`, `git diff --check` is clean, and only intentional files appear. If verification exposes a defect, return to the task that owns that behavior, add a failing assertion, fix it, rerun that task's checks and this full verification, and amend with a new focused correction commit. Do not create an empty verification commit.
