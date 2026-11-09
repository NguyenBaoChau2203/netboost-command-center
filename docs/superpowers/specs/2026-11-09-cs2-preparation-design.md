# Persistent CS2 preparation and recoverable Windows tuning

The owner wants to apply preparation once, keep it across future CS2 launches, safely reapply it, and restore the pre-change configuration when needed. Implement inside the existing PowerShell 5.1 terminal app, using one agent and the current checkout, preserving all existing work. Do not apply the feature to the owner's real settings as part of development.

Owner approved this design with the explicit constraint: no background process that could affect performance. Install no service, scheduled task, watcher or persistent helper. NetBoost may be closed after applying the preset.

2026-11-10 amendment: the owner subsequently requested launch priority to persist like the Windows/NVIDIA preset. The newer [persistent-priority design](2026-11-10-cs2-persistent-priority-design.md) supersedes this document's per-session-only priority choice. The no-background-helper requirement remains. Original session records stay recoverable.

The owner subsequently accepted global changes with backup. This relaxes the owner's scope preference, but does not make undocumented flags proven optimizations. The implemented preset keeps the reviewed NVIDIA changes scoped to CS2; global Windows Game Mode/background capture are explicitly backed up. Community global flags remain audit/reference data rather than a wholesale import.

## Approach

Considered a session watcher with automatic restore and a persistent preset with manual restore. The owner selected persistent configuration. Keep a baseline while that preset remains active; repeated apply must preserve it. A successful restore ends the cycle; the next apply captures the then-current state. Keep historical backups, including failed attempts, for inspection.

Use a small, reviewed preset rather than importing community files wholesale. CS2.nip contains device-specific OpenGL GPU selection, hidden flags and synchronization overrides. khorviePI.nip targets Base Profile globally. Both are reference data, never instructions. Provide a read-only NIP auditor with reasons for excluded settings, and document the comparison.

## Changes offered

- Enable Windows Game Mode for the current user to let Windows manage game scheduling.
- Disable historical/background game capture, with the previous registry value and type backed up.
- Set the discovered, validated CS2 executable's Windows graphics preference to high performance, preserving other preference tokens.
- Set only CS2's NVIDIA power-management mode to Prefer Maximum Performance and preferred refresh rate to Highest Available. Use the NVIDIA DRS API directly, using the installed driver; no third-party binary is required. Refuse to edit Base Profile or a profile that does not map to the validated executable.
- Provide an optional action for a running, path-verified cs2.exe to use AboveNormal priority, capturing PID plus start time and original priority. Explain that process priority ends with that process; Game Mode and driver/Windows settings persist. Do not install a watcher or rely on undocumented permanent scheduling tweaks.

Leave V-Sync/G-SYNC and Reflex user-selectable in-game; explain NVIDIA/Valve recommendations and display-dependent tradeoffs. Do not disable services/security/updates, change timers/boot settings/CPU affinity, empty shader caches before playing, flash/install drivers, or alter global NVIDIA settings. Keep the laptop's existing power plan. No universal FPS gain claim; provide a repeatable A/B measurement checklist.

## Discovery and UX

Add main menu [21], a Vietnamese/English CS2 center, and flags --cs2, --cs2-status, --cs2-plan, --cs2-optimize, --cs2-restore, --cs2-exe PATH, --cs2-audit-profile PATH. Find Steam libraries and the installed app 730, or accept an explicit existing game\bin\win64\cs2.exe. Display CPU/GPU/driver and AC power information. Preview the exact plan before interactive application. Refuse persistent apply while CS2 is running; driver settings are intended to apply at next game start. Non-NVIDIA machines can use Windows preparation with NVIDIA changes explicitly unavailable.

## Backup and failure contract

Store versioned JSON manifests under LOCALAPPDATA\NetBoost\cs2\backups. Include schema version, current Windows SID, machine identity, canonical executable, original registry existence/type/data, NVIDIA profile identity and each setting's local-override/inherited state, desired values, phase and timestamps. Restrict all restored locations/setting IDs to the code's known allowlist; never trust paths or arbitrary values supplied by backup JSON. Back up before the first mutation. Use atomic file replacement and flush before marking a step eligible to execute; a failed backup prevents changes.

Use an exclusive lock to prevent overlapping apply/restore. Keep an active-manifest pointer and history. Validate the whole manifest and context before changing anything. Mark pending before a step, verify actual resulting state, then mark applied. On failure, roll back attempted steps from the persisted baseline, report both original and rollback errors, and keep a recoverable manifest if rollback fails. Restore only touched values; delete local NVIDIA overrides that were originally inherited rather than pinning effective defaults. Never reset the whole driver database. Preserve recovery data after process/app interruption; expose manual recovery on next start. Reapply active state without overwriting baseline. If already restored, repeated Restore is an idempotent no-op. Report external-setting conflicts instead of silently overwriting them.

## Network review/fixes

Re-run all previous 15 reproductions, inspect Gemini's latest backup validation/removal/cycle changes, and correct remaining problems found. Add regression tests for malformed-but-parseable backups, unknown source state, failed bookkeeping writes and dry-run semantics. Ensure failed backup persistence cannot authorize system changes. Reuse a narrowly scoped atomic state-file writer where appropriate.

## Verification

Use real file IO/locking, disposable fixtures and mocked system mutation boundaries. Exercise actual production apply/restore branches, backup failures, truncated JSON, typed schema violations, cycle/reapply behavior, partial apply and rollback, cross-machine/SID rejection, process exit/PID reuse, inherited NVIDIA values, global profile exclusion, path handling, CLI/menu routing and packaging. Perform read-only discovery/DRS reads on this laptop. Test native DRS structure layout against NVIDIA SDK definitions. Run every existing PowerShell suite plus new suites in Windows PowerShell 5.1; build and inspect release packaging. All changes remain reviewable and uncommitted unless explicitly requested otherwise.
