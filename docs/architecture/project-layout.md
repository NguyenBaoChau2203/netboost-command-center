# Project layout

```text
NetBoost Command Center.exe       # Generated branded terminal launcher
NetBoost_Command_Center.bat       # Fallback launcher
src/
  launcher/NetBoost.Launcher.cs
  powershell/
    NetBoost_Command_Center.ps1
    NetBoost.Cleanup.ps1
    NetBoost.Mole.ps1
    NetBoost.Win11Debloat.ps1
assets/brand/                    # Canonical Mochi Cat artwork and icon
docs/                            # Usage, architecture and historical design notes
tests/                           # PowerShell fixtures and launcher/package checks
tools/                           # Build, packaging and shortcut scripts
```

The root launcher starts Windows PowerShell 5.1. The main script loads the terminal cleanup module and optional tool managers. Cleanup definitions and confirmation policies are independent of transport; execution is synchronous and output goes to the terminal. The project has no frontend bundle, HTTP API, local web server or JavaScript development dependencies.

The docs/superpowers notes describe historical work and may reference earlier architectures. Current runtime behavior is documented in the root README, module README and integration guides.
