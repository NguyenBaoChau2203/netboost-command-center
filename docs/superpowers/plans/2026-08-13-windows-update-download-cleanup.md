# Windows Update Download Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an explicit, deep-only cleanup target for `%SystemRoot%\SoftwareDistribution\Download` that safely restores the original Windows Update service state.

**Architecture:** The backend exposes a fifteenth cleanup target with its own `windows-update-downloads` action. The PowerShell action runs filesystem deletion through the existing canonical path guard inside a service transaction that records `wuauserv` and `BITS`, stops only services that are currently running, and restores those services in `finally` even when cleanup fails. Tests inject service fakes so automated verification never touches real Windows services or the real update cache.

**Tech Stack:** Windows PowerShell 5.1, local loopback REST API, React 19.2.6, TypeScript 6.0.2, npm.

## Global Constraints

- Keep product version `1.0.1`.
- Keep the current UI visual design.
- The target ID is `windows-update-downloads` and the action kind is `windows-update-downloads`.
- The target is high-risk, confirmation-required, deep-only, and off by default.
- Resolve the runtime path from `$env:SystemRoot`; never assume the Windows drive is `C:` for deletion.
- Delete only contents below `SoftwareDistribution\Download` through `Remove-FolderContents`; never delete the root directory.
- If a required service cannot be stopped, do not start deletion.
- Restore only services that were running before the cleanup attempt, including on failure.
- Automated tests must use injected service fakes and temporary directories; they must not stop real services or delete the real update cache.

---

### Task 1: Service transaction and safety regression tests

**Files:**
- Modify: `tests/cleanup-safety.ps1`
- Modify: `tests/backend-smoke.ps1`

**Interfaces:**
- Consumes: `Invoke-WithTemporarilyStoppedServices -ServiceNames <string[]> -Action <scriptblock> -GetServiceState <scriptblock> -StopService <scriptblock> -StartService <scriptblock>`.
- Produces: regression coverage for original-state restoration, action failure, stop failure, deep-only policy, and the fifteenth target contract.

- [ ] **Step 1: Write the failing service-transaction tests.**

  Add fakes that model `wuauserv=Running` and `BITS=Stopped`, invoke the missing helper, and assert that only `wuauserv` is stopped and restored while the action runs once. Add a second case whose action throws and assert the originally running service is still restored and the error is rethrown. Add a third case where stopping the second running service throws and assert deletion never runs while the first service is restored.

- [ ] **Step 2: Write the failing target-contract tests.**

  Add `windows-update-downloads` to the expected ID list and assert `action='windows-update-downloads'`, `risk='high'`, `deepOnly=$true`, `requiresConfirmation=$true`, and that its path ends in `SoftwareDistribution\Download`. Verify `Start-WebCleanupJob` rejects it when `-Deep $false`.

- [ ] **Step 3: Run tests to verify RED.**

  Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/cleanup-safety.ps1`

  Expected: FAIL because `Invoke-WithTemporarilyStoppedServices` is not defined.

  Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/backend-smoke.ps1`

  Expected: FAIL because the new target is not exposed.

- [ ] **Step 4: Commit the failing contract tests after confirming the intended failures.**

  ```powershell
  git add tests/cleanup-safety.ps1 tests/backend-smoke.ps1
  git commit -m "test: specify Windows Update cache safety"
  ```

### Task 2: PowerShell action and backend dispatch

**Files:**
- Modify: `src/powershell/NetBoost_Command_Center.ps1`
- Modify: `src/backend/NetBoost.LocalWeb.ps1`

**Interfaces:**
- Produces: `Invoke-WithTemporarilyStoppedServices` and `Invoke-WindowsUpdateDownloadCleanup`.
- Extends: `New-CleanupTargetDefinition.Action` with `windows-update-downloads`.
- Dispatches: `windows-update-downloads` from `Invoke-WebCleanupJobWorker`.

- [ ] **Step 1: Implement the minimal service transaction.**

  Snapshot each named service through `GetServiceState`, stop only snapshots whose status is `Running`, invoke `Action` only after every required stop succeeds, and in `finally` start only the names successfully stopped from an originally running state. Preserve the primary exception; if cleanup succeeded but restoration failed, throw the restoration failure.

- [ ] **Step 2: Implement the Windows Update cleanup action.**

  `Invoke-WindowsUpdateDownloadCleanup` calls `Ensure-Admin`, resolves `Join-Path $env:SystemRoot 'SoftwareDistribution\Download'`, runs `Remove-FolderContents` as the transaction action, and emits INFO/SUMMARY/ERROR job events without logging secrets or accepting a client-supplied path.

- [ ] **Step 3: Register the target and worker functions.**

  Add the fifteenth target with high risk, confirmation, and deep-only metadata. Add both new functions to the background bootstrap list and add an explicit worker switch branch for `windows-update-downloads`; do not fall through to raw filesystem dispatch.

- [ ] **Step 4: Run focused tests to verify GREEN.**

  Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/cleanup-safety.ps1`

  Expected: PASS with no real service calls.

  Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/backend-smoke.ps1`

  Expected: PASS with 15 cleanup targets.

- [ ] **Step 5: Commit the backend increment.**

  ```powershell
  git add src/powershell/NetBoost_Command_Center.ps1 src/backend/NetBoost.LocalWeb.ps1 tests/cleanup-safety.ps1 tests/backend-smoke.ps1
  git commit -m "feat: safely clear Windows Update downloads"
  ```

### Task 3: Web contract, copy, documentation, and full verification

**Files:**
- Modify: `src/web/src/api/types.ts`
- Modify: `src/web/src/api/mockData.ts`
- Modify: `src/web/src/views/CleanupView.tsx`
- Modify: `src/web/src/i18n/translations.ts`
- Modify: `README.md`
- Modify: `src/backend/README.md`
- Modify: `src/powershell/README.md`
- Modify: `src/web/README.md`
- Modify: `tests/README.md`
- Modify: `specs/001-local-web-command-center/contracts/api.md`
- Regenerate: `src/backend/public/**`

**Interfaces:**
- Extends: `CleanupTarget.action` with `'windows-update-downloads'`.
- Adds: `cleanConfirmWindowsUpdateReason` in Vietnamese and English.
- Mirrors: the target in mock mode with the same default-off policy as the backend.

- [ ] **Step 1: Extend the typed web contract and mock target.**

  Add the action literal, then add a high-risk/deep-only/confirmation-required mock target with `path: '%SystemRoot%\\SoftwareDistribution\\Download'`; existing default selection logic must leave it unchecked.

- [ ] **Step 2: Add precise confirmation copy.**

  Append a confirmation reason when `windows-update-downloads` is selected, explaining that downloaded Windows Update packages will be removed and may need to be downloaded again. Keep the existing layout and styling unchanged.

- [ ] **Step 3: Update documentation.**

  Change the cleanup count from 14 to 15, document the service-state transaction and default-off deep-only behavior, and replace the obsolete statement that raw `SoftwareDistribution\Download` cleanup is never used. Keep official Microsoft Support and Microsoft Learn links adjacent to the behavior they justify.

- [ ] **Step 4: Build with the authoritative package manager.**

  Run: `npm --prefix src/web run lint`

  Expected: exit 0.

  Run: `npm --prefix src/web run build`

  Expected: exit 0 and refreshed backend public assets.

- [ ] **Step 5: Run the complete verification suite.**

  Run the PowerShell parser over `src/powershell/NetBoost_Command_Center.ps1` and `src/backend/NetBoost.LocalWeb.ps1`, then run `tests/cleanup-safety.ps1`, `tests/backend-smoke.ps1`, `npm --prefix src/web run lint`, `npm --prefix src/web run build`, and `git diff --check`. No step may invoke the new destructive action against the host.

- [ ] **Step 6: Commit the web and documentation increment.**

  ```powershell
  git add src/web src/backend/public README.md src/backend/README.md src/powershell/README.md tests/README.md specs/001-local-web-command-center/contracts/api.md
  git commit -m "docs: explain Windows Update cache cleanup"
  ```
