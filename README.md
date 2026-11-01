# NetBoost Command Center

A terminal-based Windows network and cleanup toolkit, with optional Chris Titus WinUtil, Mole CLI and Win11Debloat integrations.

Windows 10/11 · Windows PowerShell 5.1 · Vietnamese / English · MIT

**Current release: v1.1.0** — [Download the portable ZIP](https://github.com/NguyenBaoChau2203/netboost-command-center/releases/download/v1.1.0/NetBoost-Command-Center-v1.1.0.zip) · [SHA-256 checksum](https://github.com/NguyenBaoChau2203/netboost-command-center/releases/download/v1.1.0/NetBoost-Command-Center-v1.1.0.zip.sha256) · [Release notes](docs/releases/v1.1.0.md)

## Changes in v1.1.0

- Runs entirely in the terminal; the former browser interface and HTTP backend have been removed.
- Adds Mole CLI management at **[18]** and Win11Debloat management at **[19]**, including explicit install/download, update and removal choices.
- Keeps all 15 guarded cleanup targets in a standalone PowerShell module.
- Retains the Mochi Cat EXE launcher, DNS tools, scheduled Auto DNS, terminal dashboard and Vietnamese/English labels.

When upgrading from v1.0.1, extract the new ZIP into a new folder and run the included EXE. The old Web option 17 and the `--web`/`--port` arguments are no longer supported. The tool integrations retain menu numbers 18 and 19.

## Run

Extract the complete portable ZIP and double-click **NetBoost Command Center.exe**. The branded launcher requests administrator rights through UAC and opens the terminal menu. **NetBoost_Command_Center.bat** remains available as a fallback.

```powershell
& '.\NetBoost Command Center.exe'
& '.\NetBoost Command Center.exe' --lang en
& '.\NetBoost Command Center.exe' --lang vi
```

The application uses Windows' built-in PowerShell and .NET Framework. No additional development runtime is needed to run or build it. The launcher is not digitally code-signed; verify the release ZIP against its SHA-256 sidecar file if Windows reports an unknown publisher.

## Terminal menu

```text
NETWORK / DNS
 [1 ] Auto chon DNS ping thap hon ngay bay gio
 [2 ] Ep Google DNS (8.8.8.8 / 8.8.4.4)
 [3 ] Ep Cloudflare DNS (1.1.1.1 / 1.0.0.1)
 [4 ] Xem DNS hien tai
 [5 ] Tao lich auto DNS khi dang nhap
 [6 ] Xoa lich auto DNS
 [7 ] Xoa bo nho dem DNS (Flush DNS)
 [8 ] Dat lai DNS ve DHCP/Auto

CLEANUP
 [9 ] Mo Trung tam don dep CLI (An toan / Nang cao)
 [10] Don tep tam Windows & Nguoi dung cu hon 24 gio
 [11] Don dep bo nho dem Game & Do hoa
 [12] Don cache Windows co ban
 [13] Lam trong Thung rac (can xac nhan)

TOOLS
 [14] Mo Chris Titus WinUtil
 [15] Xem bang thong tin (Dashboard)
 [16] Switch interface language to English
 [18] Quan ly Mole CLI (cai / mo / cap nhat / go cai dat)
 [19] Quan ly Win11Debloat (tai / mo / cap nhat / go)
 [0 ] Thoat chuong trinh
```

Mole and Win11Debloat retain options 18 and 19. The menu starts without running latency tests or opening the dashboard. Select option 15 to inspect the terminal dashboard.

## DNS and scheduled tasks

NetBoost measures six ping samples each for Google (8.8.8.8) and Cloudflare (1.1.1.1) and can apply the faster provider. A tie keeps the current DNS, and a failed comparison leaves DNS unchanged. You can also explicitly choose either provider, flush the resolver cache, or reset DNS to DHCP.

The optional **NetBoost Auto DNS Optimizer** scheduled task runs 30 seconds after Windows logon. Create it with option 5 or remove it with option 6. It uses the current user's highest available privileges; DNS changes and task management require administrator rights.

## Cleanup Center

Option 9 groups cleanup into:

- **Safe:** temporary files older than 24 hours, rebuildable game/graphics caches, basic Windows caches, or the recommended safe group.
- **Confirmation required:** crash dumps and Recycle Bin require `y`.
- **Advanced:** Component Store, Windows Update downloads and old Prefetch files require the exact case-sensitive text `CONFIRM`. Advanced targets run individually.

The standalone `NetBoost.Cleanup.ps1` module defines and validates these 15 targets:

| Target | Scope / policy |
|---|---|
| User Temp | `%TEMP%`; safe retains 24 hours, advanced retains 1 hour |
| Windows Temp | `C:\Windows\Temp`; same retention |
| DirectX cache | `%LOCALAPPDATA%\D3DSCache` |
| NVIDIA cache | `DXCache`, `GLCache`, `NV_Cache` |
| Steam cache | Discovered `shadercache\730` directories |
| Crash dumps | `%LOCALAPPDATA%\CrashDumps`; confirmation required |
| Thumbnails | Windows Explorer thumbnail cache |
| INetCache | Windows Internet cache |
| Recycle Bin | Explicit confirmation before emptying |
| Component Store | Advanced; DISM `/StartComponentCleanup`, never `ResetBase` |
| Delivery Optimization | Supported Windows cleanup command; pinned files preserved |
| Windows Update downloads | Advanced; only `SoftwareDistribution\Download` contents |
| Font cache | Windows Font Cache directory |
| Prefetch | Advanced; `.pf` older than 30 days; preserves `ReadyBoot` and `Layout.ini` |
| Windows Error Reports | Safe retains 24 hours, advanced retains 1 hour |

Cleanup validates canonical roots and child containment, rejects root/profile/Windows-directory deletion and linked traversal, and skips locked files. Windows Update cleanup restores the original running/stopped states of wuauserv and BITS even after errors. Core cleanup does not terminate user applications or graphics drivers.

Events print to the terminal. Parent paths are hidden by default. Use `--detailed-cleanup-logs` to include complete paths for that process. NetBoost does not persist a settings file or start a local server.

## Optional tools

- **[14] Chris Titus WinUtil:** asks for confirmation before downloading and running the upstream tool.
- **[18] Mole CLI:** detects installations and offers confirmed install/update/uninstall, the interactive menu, cleanup preview and disk analysis. See [Mole integration](docs/mole-cli.md).
- **[19] Win11Debloat:** downloads verified portable packages and offers the terminal menu, WhatIf preview and confirmed updates/removal. Removing the script package does not undo Windows changes; backups and settings remain. See [Win11Debloat integration](docs/win11debloat-cli.md).

External tools retain their own behavior once opened. NetBoost verifies official package URLs, SHA-256 and package versions for the Mole and Win11Debloat releases it downloads. Entering a manager never installs or applies cleanup/debloat automatically.

## Command-line options

```powershell
& '.\NetBoost Command Center.exe' --help
& '.\NetBoost Command Center.exe' --status
& '.\NetBoost Command Center.exe' --dashboard
& '.\NetBoost Command Center.exe' --auto-dns
& '.\NetBoost Command Center.exe' --google
& '.\NetBoost Command Center.exe' --cloudflare
& '.\NetBoost Command Center.exe' --reset-dns
& '.\NetBoost Command Center.exe' --mole
& '.\NetBoost Command Center.exe' --win11debloat
& '.\NetBoost Command Center.exe' --detailed-cleanup-logs
```

Use `--lang en` or `--lang vi` with any supported command. Unsupported options return exit code 2 and show help without opening a manager or performing a system action.

## Build and verify

From the repository root in Windows PowerShell:

```powershell
.\tools\Build-NetBoostLauncher.ps1
.\tools\Create-NetBoostShortcut.ps1
.\tools\Build-NetBoostRelease.ps1
```

The release builder packages the terminal launcher, PowerShell modules, brand assets and usage documents into `build\release`, with a SHA-256 sidecar file. The generated EXE and machine-specific shortcut remain ignored by Git.

Run the documented [PowerShell test suites](tests/README.md). They use disposable fixtures and injected actions instead of changing actual DNS, tasks or Windows cleanup targets. See [project layout](docs/architecture/project-layout.md) for source boundaries.

## License

[MIT](LICENSE). Optional tools are separate upstream projects with their own licenses.
