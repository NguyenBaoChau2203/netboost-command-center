# Win11Debloat terminal integration

Select **Tools → [19] Manage Win11Debloat**, or run NetBoost with `--win11debloat`. The source is [Raphire/Win11Debloat](https://github.com/Raphire/Win11Debloat).

Win11Debloat is a portable PowerShell tool for removing apps and changing Windows settings. NetBoost downloads a local copy and opens the upstream terminal menu. Downloading the tool does not run it or apply any tweaks.

## Menu

| Option | Behavior |
|---|---|
| `[1]` when absent | Confirm and download the latest verified stable package |
| `[1]` when present | Confirm and open `Win11Debloat.ps1 -CLI` |
| `[2]` | Open `-CLI -WhatIf` to preview user-selected changes; shown only when the copy advertises `SupportsShouldProcess` |
| `[4]` | Confirm removal of NetBoost-managed script packages |
| `[5]` | Check GitHub again |
| `[6]` | Confirm and download a newer stable package; shown only for a known older local version |
| `[0]` | Return to the main menu |

Labels follow NetBoost's Vietnamese/English setting. Upstream retains its own translations. NetBoost checks releases once on entering this manager and again only after `[5]`. The main terminal menu makes no automatic Win11Debloat network calls. If GitHub is unavailable, local Open and Preview remain usable; first download and update require a successful lookup.

Opening the tool always includes `-CLI`, so NetBoost does not default to the upstream graphical launcher. Preview adds `-WhatIf`, which upstream documents as previewing selected tweaks and app removals without applying them. Upstream may still write logs or its own local settings. NetBoost passes no automatic presets, `-Silent`, registry tweaks, app selections, backup-disabling flags, or other system-change arguments.

Win11Debloat requires Windows PowerShell 5.1 and administrator rights for its operation. NetBoost uses the built-in `powershell.exe`, not PowerShell 7. When run directly without elevation, the upstream tool handles its administrator prompt.

## Downloads and updates

NetBoost looks for official stable releases tagged `yyyy.MM.dd`, ignoring invalid dates, drafts and prereleases. It requires the `Win11Debloat.zip` release asset, the exact official GitHub download URL, and a SHA-256 digest in the asset metadata. It verifies both the downloaded hash and the script's declared version before installing any package. It does not fall back to an unverified moving branch or execute the repository's remote bootstrap command.

Packages are stored under:

```text
%LOCALAPPDATA%\Programs\NetBoost\Win11Debloat\packages\<release-tag>
```

Downloads and extraction happen in a private temporary folder. A complete package is staged under a unique `.pending-<id>` directory, records its owned files in `.netboost-package.json`, and is then renamed to its final version directory. Detection selects the newest completed package. A failed download/hash/version check leaves any previously downloaded version usable. Older completed versions are retained until explicit tool removal, so an already-open session can continue using its files.

No Git, Scoop, WinGet, PATH change, or system-wide installation is required to download a package. Upstream may need WinGet for some app-management operations once the user chooses them.

## Existing portable copies

NetBoost first checks its own managed packages, then conventional standalone locations: `C:\Win11Debloat` (using the system drive), `%TEMP%\Win11Debloat`, `%LOCALAPPDATA%\Win11Debloat`, and `%USERPROFILE%\Downloads\Win11Debloat`. A data-only folder without the script and required companion files is not treated as an installed tool. Version detection reads the script as text without executing it.

An external copy can be opened or previewed. Updating it downloads a newer separate NetBoost-managed copy. Its original folder is never overwritten or removed by NetBoost; the Remove option is offered only for managed packages. This detection is bounded and does not search all disks for arbitrary extracted folders.

## Removing the tool and reverting Windows changes

**Removing a script package does not reverse Windows changes already applied with Win11Debloat.** The confirmation prompt makes this distinction explicit.

Removal validates the recorded relative paths for every managed package before deleting files. It deletes only recorded files, the ownership record, and directories that are then empty. Unrecorded user files remain. Linked paths and entries that escape their package are refused. The wrapper does not touch `%LOCALAPPDATA%\Win11Debloat`, where upstream stores registry backups, logs, preferences and last-used settings.

For reversing applied settings or restoring removed apps, follow the upstream [Reverting Changes guide](https://github.com/Raphire/Win11Debloat/wiki/Reverting-Changes). NetBoost does not claim that removing its downloaded files performs that restoration.

## Verification

Run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\win11debloat-integration.ps1` for isolated fixture checks. The fixture scripts deliberately throw if executed. Tests exercise the integration without applying Windows tweaks or running actual debloat. The portable release test verifies that this module and guide are packaged with NetBoost.
