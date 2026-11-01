# PowerShell terminal application

Launch the root NetBoost Command Center.exe or NetBoost_Command_Center.bat. For direct invocation, run NetBoost_Command_Center.ps1 in Windows PowerShell 5.1.

| Module | Responsibility |
|---|---|
| NetBoost_Command_Center.ps1 | Localized terminal menu, argument routing, DNS/task actions, dashboard, filesystem guards and Windows maintenance |
| NetBoost.Cleanup.ps1 | Cleanup target definitions, selection/confirmation validation, synchronous dispatch and console events |
| NetBoost.Mole.ps1 | Optional Mole CLI management via [18] or --mole |
| NetBoost.Win11Debloat.ps1 | Optional portable Win11Debloat management via [19] or --win11debloat |

Cleanup validates canonical roots and child containment. Safe Temp cleanup preserves 24 hours; Prefetch removes only .pf files older than 30 days. Windows Update download cleanup is advanced-only and restores the original wuauserv/BITS states in finally. Risky targets require explicit confirmation. Detailed cleanup paths are opt-in with --detailed-cleanup-logs; logs print directly to the terminal.

Mole and Win11Debloat are downloaded only after user confirmation and are not bundled into NetBoost. See [Mole](../../docs/mole-cli.md) and [Win11Debloat](../../docs/win11debloat-cli.md) usage documents.
