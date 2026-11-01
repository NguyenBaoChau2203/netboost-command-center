# Mole CLI integration

Select **Tools → [18] Manage Mole CLI**, or launch NetBoost with `--mole`.
This integration uses the free [Mole CLI for Windows](https://github.com/tw93/Mole/tree/windows), not the separately licensed desktop application.

## Menu behavior

| State | Available actions |
|---|---|
| CLI not installed, release lookup succeeds | `[1]` Install, `[5]` Check again, `[0]` Back |
| CLI installed | `[1]` Open Mole, `[2]` Preview cleanup, `[3]` Analyze disk, `[4]` Uninstall, `[5]` Check again, `[0]` Back |
| Installed version is older than the latest stable Windows release | Also show `[6]` Update, including current and available versions |
| GitHub is unavailable | Keep installed actions; disable first installation and update until a successful recheck |

Install, update, and uninstall require `y` confirmation. Opening the manager or declining a prompt makes no installation changes. Preview opens `clean --dry-run` in a separate PowerShell window. Open starts Mole's own interactive menu; Analyze opens its disk explorer. Users choose any subsequent deletion inside Mole themselves. Mole's normal cleanup can delete files permanently.

The menu checks GitHub once on entry, then only when `[5]` is selected. The main NetBoost menu does not perform network checks. Unknown installed versions keep Open, Preview, Analyze, and Uninstall available but do not enable Update. UI labels follow NetBoost's Vietnamese/English setting.

## Installation and update channels

New installations use the architecture-specific ZIP from an official stable `V<version>-windows` GitHub release. The ZIP must have the expected official download URL and a SHA-256 digest in the GitHub asset metadata. NetBoost verifies the downloaded hash and package version before invoking the package's original installer. It does not use the repository's default macOS release or the moving development branch for new installations.

New CLI files go to `%LOCALAPPDATA%\Programs\NetBoost\MoleCLI`; the upstream installer adds this directory to the user's PATH. Git and Go are not prerequisites for the release ZIP installation. Temporary download/extraction files are removed afterward. Existing unrelated directories and linked installation paths are refused. If GitHub has no ZIP for the PC's architecture, the menu reports the missing package instead of installing another architecture.

Detection checks the NetBoost installation, the official `Programs\mole-cli` location, the legacy `%LOCALAPPDATA%\Mole` location only when it contains CLI files, directories on PATH, Scoop's current Mole directory, and local WinGet `tw93.MoleCLI` packages. It reads the installed `VERSION` file or the legacy version helper without executing the detected CLI. A paid desktop-app-only installation does not count as a CLI installation.

Existing channels retain their original management behavior:

| Installation | Update | Uninstall |
|---|---|---|
| Release ZIP | Verify and run the newer release installer with `-Force` | Original `install.ps1 -InstallDir <root> -Uninstall` |
| Git source | Mole's `update` command | Original installer |
| Scoop | `scoop update mole` | `scoop uninstall mole` |
| WinGet | `winget upgrade --id tw93.MoleCLI --exact --source winget` | `winget uninstall --id tw93.MoleCLI --exact --source winget` |

Git updates follow upstream's Windows source branch. Package-manager catalogs may trail a GitHub release, so those installations update to the version their manager currently provides. NetBoost does not replace a package-manager installation with a ZIP or modify a Git checkout through the release installer. Uninstall may separately ask about keeping Mole settings; NetBoost leaves that choice to the upstream tool.

## Verification

Run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\mole-integration.ps1` for isolated fixture checks. The release packaging check also verifies that `NetBoost.Mole.ps1` is shipped and parses under Windows PowerShell. Tests do not install real Mole or run cleanup on the machine.
