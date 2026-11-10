# Space to skip cleanup file output

> Execution: one agent inline, as required by the owner.

**Goal:** While cleanup prints deleted files, Space hides remaining item details and leaves accurate summaries visible, without cancelling deletion.

**Design:** The existing synchronous cleanup engine reports each item immediately. Add a display state scoped to one Invoke-CleanupTargetSet call and restore the previous state in finally. Read console input without blocking only while item details are visible; Space hides all subsequent per-file/directory lines across the selected targets. Keep target warnings/errors and summaries visible, and retain failure counters for hidden item errors. Print localized hint/acknowledgment. No threads, background process, buffered replay, persistent setting, or deletion-policy changes. Unavailable/redirected console input disables key polling without failing cleanup. New cleanup calls start with details visible; existing full-path privacy preference is unchanged.

**Files:** src/powershell/NetBoost.Cleanup.ps1 (display state, console key probe, event filter, scoped dispatch), src/powershell/NetBoost_Command_Center.ps1 (identify individual item errors), tests/cleanup-display.ps1, README.md, tests/README.md.

**Verification:** Real fixture deletion with injected key input/output; test Space vs other keys, across-target suppression, continued deletion and exact failure summaries, unhandled-error/finally restoration, subsequent-run reset, noninteractive/failed key input, and unchanged summary/error visibility. Run existing cleanup/terminal suites, package and verify.

- [x] Add a failing behavioral test before changing runtime code.
- [x] Implement bounded nonblocking key reads and one-run display suppression.
- [x] Verify deletion/counts and reset/error handling with disposable fixtures.
- [x] Update usage and run the relevant regression suites and package checks.

The request fully specifies the desired interaction; routine implementation choices are made inline under existing authorization. Global Windows/game settings are not involved.

## Verification record

- RED observed: New-CleanupDisplayState missing before implementation. Runtime changes then pass 18 assertions, including actual fixture deletion, locked-file counts, cross-target suppression and state restoration on exceptions.
- Actual Windows PowerShell 5.1 console/PTY probe: received a Space key while emitting fixture events, hid the rest, displayed the summary and exited successfully (SPACE_CONSOLE_PROBE_PASSED). No files were changed by that console probe.
- Full verification: build/verify-v1.2.1.ps1 passes 16/16 suites under Windows PowerShell 5.1.26100.9818, including packaged EXE/version/modules/docs/checksum. Logs: build/verification-v1.2.1.
- Inline review completed by the main agent per owner policy. Display suppression returns before path/timestamp formatting, retains task warnings/errors and failure counts, and does not change deletion/confirmation/retention/service policies. Acknowledgment correctly says cleanup must finish before final counts appear.
- Patch release v1.2.1 follows the owner's existing request to distribute the application publicly. v1.2.0 and its assets remain unchanged.
