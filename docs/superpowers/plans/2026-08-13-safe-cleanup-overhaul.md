# Safe Cleanup Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make disk cleanup safer, more transparent, and more useful while preserving the existing UI design.

**Architecture:** Extend cleanup target policy with safe/deep retention, deep-only controls, bounded honest estimates, and typed special Windows actions. All raw filesystem deletion passes through canonical-root guards; Windows component and Delivery Optimization cleanup use their supported system tools.

**Tech Stack:** Windows PowerShell 5.1, local loopback REST API, React 19.2.6, TypeScript 6.0.2.

## Global Constraints

- Keep product version `1.0.1`.
- Keep the current UI visual design.
- Temp safe retention is 24 hours; deep retention is one hour.
- Prefetch is off by default, confirmation-required, deep-only, and limited to `*.pf` older than 30 days.
- Never use DISM `/ResetBase` and never delete WinSxS directly.
- Never include pinned Delivery Optimization files.

---

### Task 1: Cleanup policy regression checks

**Files:**
- Modify: `tests/backend-smoke.ps1`

**Interfaces:**
- Consumes: `GET /api/cleanup/targets`.
- Produces: assertions for target IDs and safety metadata.

- [ ] **Step 1: Expect `delivery-optimization` and `component-store`.**
- [ ] **Step 2: Stop expecting raw `windows-update`.**
- [ ] **Step 3: Assert Temp safe/deep ages, Prefetch deep-only policy, action kinds, and estimate completeness metadata.**
- [ ] **Step 4: Run the smoke test.**

Expected: FAIL because the new targets and metadata do not exist.

### Task 2: Target policy and honest estimates

**Files:**
- Modify: `src/backend/NetBoost.LocalWeb.ps1`
- Modify: `src/web/src/api/types.ts`
- Modify: `src/web/src/api/mockData.ts`

**Interfaces:**
- Extends `CleanupTarget` with `action`, `deepOnly`, `safeMinAgeMinutes`, `deepMinAgeMinutes`, `estimatedFileCount`, and `estimateComplete`.
- Changes `Get-PathSizeEstimate` to return a structured bounded estimate.

- [ ] **Step 1: Implement policy fields in `New-CleanupTargetDefinition`.**
- [ ] **Step 2: Define the new 14-target constitution.**
- [ ] **Step 3: Implement bounded eligible-file estimates with completion metadata.**
- [ ] **Step 4: Mirror all targets and metadata in Web mock data.**
- [ ] **Step 5: Run smoke test, lint, and build.**

### Task 3: Filesystem safety and meaningful deep mode

**Files:**
- Modify: `src/powershell/NetBoost_Command_Center.ps1`
- Modify: `src/backend/NetBoost.LocalWeb.ps1`

**Interfaces:**
- Produces: `Test-SafeCleanupRoot`, `Test-CleanupCandidatePath`, age/pattern-aware `Remove-FolderContents`, and deep-only validation.
- Consumes: target policy fields from Task 2.

- [ ] **Step 1: Add canonical cleanup-root rejection and candidate boundary checks.**
- [ ] **Step 2: Apply include patterns, safe/deep ages, and reparse-point skipping during deletion.**
- [ ] **Step 3: Reject deep-only targets when `deep=false`.**
- [ ] **Step 4: Make worker choose safe or deep retention explicitly.**
- [ ] **Step 5: Run smoke and PowerShell parser checks.**

### Task 4: Supported Windows special actions

**Files:**
- Modify: `src/powershell/NetBoost_Command_Center.ps1`
- Modify: `src/backend/NetBoost.LocalWeb.ps1`

**Interfaces:**
- Produces: `Invoke-DeliveryOptimizationCleanup` and `Invoke-ComponentStoreCleanup`.
- Consumes: `delivery-optimization` and `component-store` action kinds.

- [ ] **Step 1: Implement Delivery Optimization cleanup with `Delete-DeliveryOptimizationCache -Force` and no pinned-file switch.**
- [ ] **Step 2: Implement Component Store cleanup with DISM `/Online /Cleanup-Image /StartComponentCleanup` and explicit exit-code handling.**
- [ ] **Step 3: Dispatch special actions from the cleanup worker and add them to the background bootstrap.**
- [ ] **Step 4: Run smoke and parser checks without invoking destructive cleanup in tests.**

### Task 5: Minimal UI communication and CLI access

**Files:**
- Modify: `src/web/src/views/CleanupView.tsx`
- Modify: `src/web/src/i18n/translations.ts`
- Modify: `src/powershell/NetBoost_Command_Center.ps1`

**Interfaces:**
- Preserves current layout and styling.
- Displays partial/system estimate state and deep-only warnings.
- Adds explicit CLI cleanup entries for Safe Temp and Deep/System targets without changing the visual system.

- [ ] **Step 1: Show honest estimate/deep-only labels in existing target rows.**
- [ ] **Step 2: Add Prefetch and Component Store confirmation reasons.**
- [ ] **Step 3: Make CLI cleanup choices expose Temp and deep/system cleanup clearly.**
- [ ] **Step 4: Run lint, build, and CLI help checks.**

### Task 6: Documentation and final verification

**Files:**
- Modify: `README.md`
- Modify: `src/backend/README.md`
- Modify: `src/powershell/README.md`
- Modify: `src/web/README.md`
- Modify: `tests/README.md`
- Modify: `specs/001-local-web-command-center/contracts/api.md`

**Interfaces:**
- Produces: user-facing cleanup behavior and safety documentation with official source links.

- [ ] **Step 1: Document the 14 targets, safe/deep retention, special actions, and Prefetch warning.**
- [ ] **Step 2: Run backend smoke, parser checks, lint, and build.**
- [ ] **Step 3: Run `git diff --check` and inspect tracked npm/pnpm occurrences.**
- [ ] **Step 4: Re-index CodeGraph.**
- [ ] **Step 5: Commit as `feat: harden Windows cleanup` after all checks pass.**
