# PowerShell tests

Run these from the repository root in Windows PowerShell 5.1. Each suite uses disposable fixtures, read-only checks or injected actions; no actual DNS changes, task registration, system cleanup or debloat is performed.

```powershell
.\tests\terminal-only.ps1
.\tests\cli-cleanup-center.ps1
.\tests\cleanup-safety.ps1
.\tests\mole-integration.ps1
.\tests\win11debloat-integration.ps1
.\tests\exe-launcher.ps1
.\tests\branding-assets.ps1
.\tests\release-package.ps1
```

| Suite | Coverage |
|---|---|
| terminal-only | Removed components/dependencies absent, HTTP functions absent, all 15 cleanup targets retained, legacy flags rejected without launching anything, CLI logging privacy, menu 18/19 routing |
| cli-cleanup-center | Safe/confirmed/advanced mappings, exact CONFIRM behavior, localized labels and main-menu routing |
| cleanup-safety | Canonical roots, child containment, Prefetch policies, deep/confirmation guards, Windows Update service restoration and synchronous dispatch |
| mole-integration | Version/channel detection, official release URLs/digests, install/update/uninstall confirmation, local ZIP fixtures and offline behavior |
| win11debloat-integration | Dated releases, portable ownership, CLI/WhatIf arguments, update failures, unknown-file and registry-backup preservation |
| exe-launcher | Windows argument round-trips, UAC process settings, exit codes, native EXE metadata and embedded icon |
| branding-assets | Canonical artwork/ICO, generated launcher and disposable Windows shortcut |
| release-package | Terminal-only ZIP contents, required modules/guides, PowerShell parsing, shortcut and SHA-256 sidecar |

The optional-tool tests use fake downloads and scripts that must not run actual maintenance. Launcher tests do not show a UAC prompt or start the real runtime. Packaging and branding tests may rebuild ignored local artifacts.
