# Persistent CS2 priority with Discord and FACEIT

The owner explicitly requests changing menu [4] from a per-session action to an apply-once configuration, so CS2 keeps launch priority when used with voice-only Discord and, later, FACEIT/Anti-Cheat. Preserve the previous no-background-process requirement and backup/restore contract. Complete this addition before the previously requested merge/push/release.

## Approach and scope

Windows IFEO `PerfOptions\CpuPriorityClass` can supply an initial priority by executable name without a watcher. Use DWORD 6 (AboveNormal) for `cs2.exe`, and optional DWORD 5 (BelowNormal) for voice-only `Discord.exe`. Menu [4] previews and enables both with explicit APPLY, just like [2]. This is a machine-wide, executable-name rule, including launches without the other apps. Existing Windows/NVIDIA preparation stays independent.

Alternatives: a resident watcher violates the owner's requirement; a custom shortcut/launcher fails the request to launch normally via Steam/FACEIT. IFEO is the fitting approach, but PerfOptions is not a public supported Win32 contract. Label this opt-in mechanism accurately; verify the registry state and expose observed running priority without claiming FACEIT certification or continuous enforcement. A game, launcher, or Anti-Cheat can change priority later; NetBoost does not counteract it.

Keep FACEIT client, FACEITService, Anti-Cheat process/driver, security, boot settings, affinity, IO and memory priority unchanged. CS2 receives higher initial CPU scheduling priority relative to default Normal applications. Do not infer that lowering Anti-Cheat would improve FPS. Add FACEIT's overlay troubleshooting and an A/B measurement checklist.

## Storage and recovery

Store an independent versioned priority journal in `%ProgramData%\NetBoost\cs2-priority`, with one machine-wide lock. Require the original machine/account identity for recovery. Allow only the two exact executable names, CpuPriorityClass, native registry view, and known intended DWORDs. Refuse an existing IFEO UseFilter configuration instead of altering it. Backup and flush the whole original baseline before changes; preserve original values/types and absent values. Do not delete IFEO parent keys or unrelated values.

Reuse the existing durable journal, state comparison, rollback and conflict detection. Add an explicit `Scope=ProcessPriority` manifest variant while accepting the old Windows/NVIDIA manifest and process records for recovery. Repeated apply preserves the original baseline. A failed second registry write rolls back the first. Interrupted writes remain recoverable. A new apply after restore creates a fresh historical backup.

Menu [7] and `--cs2-priority-restore` restore only launch priorities. Menu [3]/`--cs2-restore` restore priority and the existing preset, reporting failures from either journal. Old per-session process backups remain restorable. Enable/restore affects future process starts; ask users to fully exit and reopen CS2/Discord themselves. Do not open protected game/Anti-Cheat processes for modification.

## Verification and release

Exercise the real transaction engine with filesystem IO and injected registry boundaries: preview, baseline-before-write, no running app requirement, idempotence, history, external changes, permission/write/readback failures, UseFilter, malformed scopes/targets and recovery. Test the narrow native registry adapter's input guard and readonly access. Do not apply this to the owner's real CS2/Discord IFEO keys during development. The current shell is not elevated; report that live launch-priority/FACEIT behavior requires the user's test.

Run all PowerShell 5.1 suites, update CLI/menu/docs and package inclusion. Hold public publishing until this addition has been verified; the owner already authorized merge into main, push and public release. No subagents, per owner policy.
