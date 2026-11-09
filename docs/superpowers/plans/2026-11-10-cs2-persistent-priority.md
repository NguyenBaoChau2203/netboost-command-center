# Persistent CS2 Priority Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans inline. The owner prohibits subagents.

**Goal:** Apply launch priority once for CS2 with voice-only Discord, compatible in scope with FACEIT and recoverable without a NetBoost background process.

**Architecture:** Add a small CS2 priority module with narrow native-view HKLM adapters. Reuse the existing CS2 transaction/recovery engine with an independent ProcessPriority journal under ProgramData. Preserve recovery of original manifests and per-session records.

**Tech Stack:** Windows PowerShell 5.1, .NET RegistryKey, JSON journals, existing PowerShell test scripts.

**Spec:** docs/superpowers/specs/2026-11-10-cs2-persistent-priority-design.md

## Global constraints

- Single agent; reuse current checkout and preserve previous changes.
- No background process/service/scheduled task/watcher; no live game/Discord/Anti-Cheat writes during development.
- Only cs2.exe AboveNormal (6), optional Discord.exe BelowNormal (5); leave FACEIT/Anti-Cheat unchanged.
- Machine-wide rules must have durable original backups, conflict checks and independent restore.
- No guaranteed FPS or Anti-Cheat compatibility claims; Windows supplies initial priority, not continuous enforcement.

## Review focus

- Active backup from the previous build remains valid and restorable.
- Shared machine-wide changes cannot get conflicting per-user baselines.
- Existing IFEO path filtering is refused, never silently changed.
- A failed or unverified second write rolls back the first from durable data.
- Restoring priority alone must preserve the user's working Windows/NVIDIA preset.

## Task 1: Persistent priority and recovery

Files: new src/powershell/NetBoost.CS2Priority.ps1 and tests/cs2-persistent-priority.ps1; modify src/powershell/NetBoost.CS2.ps1.

- [x] Write behavioral tests for independent apply/preview/restore, baseline durability, repeat/history, permission/readback failure, conflict, UseFilter, strict target/scope validation and no process writes.
- [x] Run the new suite and confirm the expected missing-function failure.
- [x] Implement Get-NetBoostCS2PriorityPlan, Set-NetBoostCS2ProcessPriority, Restore-NetBoostCS2Priority, Get-NetBoostCS2PriorityStatus, narrow HKLM adapters; keep old session action as Set-NetBoostCS2SessionPriority for legacy regression coverage.
- [x] Extend known manifest scope/definition resolution and run new plus existing CS2 suites.

## Task 2: Product flow and packaging

Files: src/powershell/NetBoost_Command_Center.ps1, CS2 menu, README.md, docs/cs2-preparation.md, docs/cs2-research.md, tests/cs2-cli.ps1, tests/release-package.ps1, tests/README.md, tools/Build-NetBoostRelease.ps1.

- [x] Add failing routing/confirmation coverage for persistent [4], priority-only [7], CLI --cs2-priority-restore, and package module inclusion.
- [x] Implement UI/CLI/status and combined restore, with next-launch and machine-wide scope explained.
- [x] Update usage, FACEIT/overlay research and restoration documentation; run targeted checks.

## Task 3: Verification and authorized publication

- [x] Review the full diff inline against the specification and regression requirements.
- [x] Run all tests/*.ps1 in Windows PowerShell 5.1 and build/inspect the portable ZIP.
- [x] Resolve release version against existing remote tags, update release notes/version, rebuild and reverify relevant tests.
- [ ] Commit all reviewed Gemini fixes and CS2 work, merge main without force, push and publish ZIP plus checksum under the user's existing authorization.

## Ledger

- Design follows the owner's explicit request: persist [4], no background helper, backups, FACEIT unchanged. Ordinary implementation choices are made inline rather than asking the owner to repeat this authorization.
- Shell is not elevated. Live HKLM/game/Anti-Cheat mutation is excluded from development checks; registry transactions are exercised with injected boundaries and real durable files.
- RED/GREEN: missing Get-NetBoostCS2PriorityPlan, unrecognized --cs2-priority-plan, omitted priority module in package, and old application version were observed before their implementation changes. Priority transaction suite now passes 73 assertions; CLI suite passes 17; old preparation suite passes 39.
- Full verification: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File build/verify-v1.2.0.ps1` passed 15/15 suites, PowerShell 5.1.26100.9818. Logs: build/verification-v1.2.0. Native readonly plan sees no existing CS2/Discord priority rules; planned DWORDs 6 and 5; no live writes.
- Final review: performed inline by the main agent under the owner's single-agent policy. Verified machine-wide shared root/lock, original baseline retention, scope guards, legacy preparation/session restoration, journal-lock rollback and independent/combined restore. FACEIT live compatibility and IFEO launch behavior remain explicitly unverified, rather than being inferred from mock transactions.
- Publication version: v1.2.0, because v1.1.0 already exists publicly. Main and origin/main initially match 9f7ae82. Publication authorization is the owner's preceding request, with this addition completed first.
