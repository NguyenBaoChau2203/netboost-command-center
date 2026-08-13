# NetBoost CLI Cleanup Center Design

**Date:** 2026-08-13  
**Status:** Approved in conversation  
**Version constraint:** Keep the product version at `1.0.1`.

## Goal

Make cleanup equally usable from the PowerShell CLI and the Web UI without making destructive actions easy to trigger by mistake. Correct menu text that currently overstates or mislabels behavior.

## Chosen approach

Option `[9]` becomes a dedicated CLI Cleanup Center. Options `[10]` through `[13]` remain quick actions for experienced users. This was selected over adding many new top-level menu numbers because it keeps the main menu short and gives sensitive actions enough space for scope and safety warnings.

The rejected alternatives were:

- Add every cleanup target to the main menu: immediately visible, but long and easy to misread.
- Keep advanced cleanup Web-only: smallest code change, but does not serve the user's CLI-first workflow.

## Main menu corrections

- Correct the header hint so Dashboard points to option `[15]`, not `[16]`, in Vietnamese and English.
- Rename `[9]` from the inaccurate “clear all caches” wording to “CLI Cleanup Center” / “Trung tam don dep CLI”.
- Clarify `[10]` as temporary files older than 24 hours.
- Clarify `[12]` as basic system cache, because it is not every Windows system cache.
- Clarify `[13]` as a destructive Recycle Bin action that asks for confirmation.
- Keep `[10]` Temp, `[11]` Game & Graphics, `[12]` Basic System Cache, and `[13]` Recycle Bin as shortcuts.

## Cleanup Center layout

The submenu has three sections and returns to itself after an action:

### Safe quick cleanup

- `[1]` Temporary files: User Temp and Windows Temp, only files older than 24 hours.
- `[2]` Game and graphics: DirectX, NVIDIA, and discovered Steam shader caches.
- `[3]` Basic Windows cache: thumbnails, INetCache, Delivery Optimization, Font Cache, and Windows Error Reports older than 24 hours.
- `[4]` Run recommended safe cleanup: combines `[1]`, `[2]`, and `[3]`; it does not include Recycle Bin, crash dumps, or any deep-only target.

### Confirmed cleanup

- `[5]` Crash dumps.
- `[6]` Recycle Bin.

These show the target description and require `y` before execution.

### Advanced cleanup

- `[7]` Windows Component Store through `DISM /Online /Cleanup-Image /StartComponentCleanup`; never use `ResetBase`.
- `[8]` Windows Update downloads under `%SystemRoot%\SoftwareDistribution\Download`; preserve the directory itself and restore the original running states of `wuauserv` and `BITS` even after an error.
- `[9]` Windows Prefetch: only `*.pf` older than 30 days; preserve `ReadyBoot` and `Layout.ini`.

Every advanced action shows its exact scope, warns that it is advanced, and requires the user to type `CONFIRM` exactly. An empty, invalid, or interrupted response cancels the action. There is no “run all advanced actions” command.

`[0]` returns to the main menu.

## Shared cleanup execution

CLI target groups are defined as target IDs and executed through the same cleanup target definitions and guarded action dispatcher used by the local Web backend. The CLI must not maintain a second set of deletion paths or weaken backend metadata such as `deepOnly`, `requiresConfirmation`, minimum age, include patterns, or excluded path segments.

The PowerShell backend module is already loaded before the interactive menu. The CLI calls a synchronous adapter around the shared dispatcher so terminal output remains immediate; it does not start the HTTP server or browser.

Legacy shortcut functions may remain as thin wrappers, but their target membership must match the definitions above. Recycle Bin receives its own confirmation when invoked from shortcut `[13]` as well as from the Cleanup Center.

## Feedback and failure handling

- Before confirmed or advanced actions, display the label, path/scope, risk level, and retention rule where applicable.
- During execution, reuse existing cleanup events and per-target summaries.
- A missing folder is a warning and does not fail unrelated targets.
- Locked files are skipped and reported separately.
- A safety-root rejection, service-state failure, DISM failure, or unexpected action error is shown as an error; the menu remains usable afterward.
- Windows Update cleanup aborts before deletion if required running services cannot be stopped, and service restoration remains guaranteed through the existing `finally` path.

## Language and compatibility

- Add complete Vietnamese-without-accents and English strings for submenu headings, descriptions, confirmations, cancellation, and invalid choices.
- Retain PowerShell 5.1 compatibility and the current text-only visual style.
- Do not change the product version, Web UI layout, cleanup API contract, or approved Mochi Cat assets.

## Verification

- Add source-level menu regression tests for the corrected Dashboard number, honest option labels, Cleanup Center routing, and Recycle Bin confirmation.
- Add behavior tests with mocked input and mocked cleanup dispatch to prove:
  - safe group IDs exclude all confirmation-required and deep-only targets;
  - `y` is sufficient only for confirmed non-deep actions;
  - advanced actions run only after exact `CONFIRM`;
  - cancellation never calls the cleanup dispatcher;
  - the submenu returns cleanly to the main menu.
- Reuse backend smoke and cleanup-safety tests to protect target metadata, path guards, Prefetch retention, DISM arguments, and Windows Update service restoration.
- Run PowerShell parser checks, all PowerShell tests, frontend lint, and frontend production build.
- Inspect the final diff and confirm the repository version remains `1.0.1`.
