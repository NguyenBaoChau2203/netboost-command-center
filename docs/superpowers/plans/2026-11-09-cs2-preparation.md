# CS2 preparation implementation plan

> Execute inline with superpowers:executing-plans; the owner's single-agent rule applies to implementation, review and verification. Preserve the dirty working tree and leave changes uncommitted.

**Goal:** Repair remaining network backup weaknesses and deliver a persistent, reversible CS2 preparation center without background processes.

**Architecture:** PowerShell modules use a durable JSON writer and strict known-setting snapshots. A small C# NVAPI DRS bridge accesses only the CS2-associated profile. Read-only discovery and NIP audit precede explicit apply/restore; manifests journal changes and retain recovery data.

**Tech stack:** Windows PowerShell 5.1, .NET Framework Add-Type, installed NVIDIA NVAPI, existing CLI/release tools.

**Spec:** docs/superpowers/specs/2026-11-09-cs2-preparation-design.md (approved; no background tasks or watchers).

## Constraints and review focus

- One agent, current checkout, preserve Gemini's edits, no commit/push or actual gaming-configuration apply during development.
- Persist baseline before mutations; reject malformed/context-mismatched backups before restore; retain recovery records after interruption.
- No global NVIDIA writes, arbitrary NIP imports, process killing, service/security/timer/affinity changes, power-plan replacement, permanent process.
- Windows registry snapshots preserve value type/existence; GPU preference preserves unrelated tokens; NVIDIA snapshots distinguish inheritance from overrides.
- Test backup write failure, bookkeeping failure, failure between steps, repeated apply/restore, external changes, missing NVIDIA, process identity/PID reuse and executable path ambiguity.

## Task 1: Network backup durability

Files: src/powershell/NetBoost.State.ps1; src/powershell/NetBoost.NetworkThrottle.ps1; tests/network-throttle-durability.ps1.

- [x] Add regression tests for typed-invalid state, Unknown source values, failed completion bookkeeping and ApplyChanges=false; run and observe failures.
- [x] Implement Write-NetBoostJsonFile(Path,Value,NoOverwrite) using a same-directory temporary file, flush, parse verification and atomic rename/replace. Harden network snapshot validation and completion writes; dry-run performs no persistence or mutations.
- [x] Verify both new regressions and existing network tests; re-run the 15 previous reproductions.

## Task 2: Native NVIDIA bridge and NIP auditor

Files: src/native/NetBoost.NvidiaDrs.cs; src/powershell/NetBoost.CS2.ps1; tests/cs2-preparation.ps1.

- [x] Add tests that fail for absent audit/plan interfaces and known unsafe profile imports/global or device-bound flags.
- [x] Implement secure XML audit; allowlisted CS2 plan; compile/read-only probe NVAPI interop. Driver snapshot fields are Id,Value,UserOverride and ProfileName, with exact known IDs 274197361 and 6600001. Native DRS edits refuse Base Profile and changed executable/profile associations.
- [x] Verify real read-only DRS capture and SDK structure sizes; tests use fake driver mutation boundaries.

## Task 3: Persistent apply/restore engine

Files: src/powershell/NetBoost.CS2.ps1; tests/cs2-preparation.ps1.

- [x] Add failing behavior tests for apply/restore roundtrip, baseline preservation, atomic backup failure, partial rollback, corrupt/cross-context manifest, external-setting conflicts, inherited driver settings and PID reuse.
- [x] Implement Get-NetBoostCS2Plan, Get-NetBoostCS2Status, Invoke-NetBoostCS2Optimize, Restore-NetBoostCS2, Set-NetBoostCS2ProcessPriority with production system adapters and injectable boundaries. Lock each transaction; journal attempted steps before apply; verify after apply and restore; keep historical manifest and active recovery pointer.
- [x] Run behavior tests, including interrupted active state and second apply/restore cycle. All mutations remain mocked or target disposable fixtures.

## Task 4: CLI, menu, release and documentation

Files: src/powershell/NetBoost_Command_Center.ps1; tools/Build-NetBoostRelease.ps1; tests/release-package.ps1; tests/README.md; README.md; docs/cs2-preparation.md; docs/cs2-research.md.

- [x] Add integration checks for flags/menu dispatch, space-containing executable/profile paths and packaged files.
- [x] Add menu 21, VI/EN UI and documented flags; preview before interactive apply; recovery information and no-background-process statement. Include State/CS2/native source in release packaging and parser checks.
- [x] Document hardware, provided NIP comparison, primary sources and community findings distinguished from verified facts, driver/settings caveats and A/B performance measurement procedure.
- [x] Run every tests/*.ps1 suite in Windows PowerShell 5.1, inspect package and run read-only CLI flows; review changes inline and fix findings with regression tests.

## Progress

- Discovery: Gemini's newest network changes pass all 15 prior reproductions. Remaining durability/type/dry-run checks are being added.
- Research: laptop i5-11400H, RTX 3050 Ti, 16 GB, 120 Hz; provided CS2 profile has device-bound OpenGL selector, second profile targets Base Profile. Owner chose persistent settings/manual restore and no background process.
- Task 1 complete: five new durability cases observed RED then GREEN; original network suite passes (57 assertions).
- Task 2 complete: safe NIP auditor handles both supplied files; native DRS read-only capture verified on this laptop and SDK IDs/layouts checked.
- Task 3 complete: core apply/restore, runtime priority, failure rollback, bookkeeping failure and invalid typed backup tests observed RED then GREEN; 39 preparation assertions, plus 7 real Registry adapter cases on a removed disposable HKCU key.
- Task 4 complete: menu 21, CLI, release files and documentation. Final fresh run: all 14 tests/*.ps1 suites exited 0 in Windows PowerShell 5.1; includes 13 CLI assertions, 39 preparation assertions, 7 real Registry adapter assertions, 4 native profile-scope checks and 7 network durability cases. Release ZIP refreshed successfully after the final code changes, then packaged read-only discovery/DRS status verified. All 15 previous regression scenarios pass with the strengthened no-backup/no-reset contract.
- Ruling: reuse the current dirty checkout on codex/cs2-preparation to retain Gemini's changes and the owner's app path; no new worktree, commit or push. Single-agent inline review follows the owner's rule.
- Ruling: keep the laptop power plan and Discord hardware-acceleration settings untouched. The owner uses voice only, reports a measured 10-15% FPS loss, and requested no background process. Priority is a one-shot action on existing processes, not a permanent IFEO policy or watcher.
- Final inline review fixes: handle UTF-8 files with legacy UTF-16 XML declaration; open writable Registry keys explicitly; preserve unsigned DWORD bits; normalize duplicate GPU preference tokens; reject non-integral driver snapshots; continue rollback from the durable baseline when completion bookkeeping cannot be written; reject conflicting CS2 CLI actions.
- Final review: self-review performed inline as required by the owner's single-agent policy; no subagent, extra reviewer chat or CLI agent used. No outstanding critical/important findings in the tested scope. Live NVIDIA writes and FPS/voice measurements remain for the owner's first deliberate Apply/A-B test; development performed read-only DRS discovery and mocked mutation tests.
- Final fixes: NVIDIA scope checks enumerate all profile executables to reject profiles shared with other apps; network optimization preserves existing voice/media QoS and Restore refuses guessed-default resets when no baseline exists. Each change was observed RED then GREEN in a regression test.
- Ruling: the owner's later acceptance of global effects permits reviewed global options, but is not evidence that each hidden flag in the supplied Base Profile improves CS2. Keep the selected NVIDIA preset per-CS2, and include the approved global Windows Game Mode/capture settings with backups. Other global driver flags stay in the read-only audit. Cost if this choice is wrong: additional reviewed global settings may be needed after A/B measurement.
