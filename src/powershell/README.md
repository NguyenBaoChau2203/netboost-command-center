# PowerShell terminal application

Launch the root NetBoost Command Center.exe or NetBoost_Command_Center.bat. For direct invocation, run NetBoost_Command_Center.ps1 in Windows PowerShell 5.1.

| Module | Responsibility |
|---|---|
| NetBoost_Command_Center.ps1 | Localized terminal menu, argument routing, DNS/task actions, dashboard, filesystem guards and Windows maintenance |
| NetBoost.Cleanup.ps1 | Cleanup target definitions, selection/confirmation validation, synchronous dispatch and console events |
| NetBoost.Mole.ps1 | Optional Mole CLI management via [18] or --mole |
| NetBoost.Win11Debloat.ps1 | Optional portable Win11Debloat management via [19] or --win11debloat |
| NetBoost.NetworkThrottle.ps1 | Read-only diagnostics, backed-up network tuning and original-state restore via [20] |
| NetBoost.State.ps1 | Validated, flushed and atomic JSON journal persistence |
| NetBoost.CS2.ps1 | Persistent Windows/NVIDIA preparation, restricted backup schemas, recovery and CS2 center [21] |
| NetBoost.CS2Priority.ps1 | Optional machine-wide CS2/voice-only Discord launch priority and independent recovery, without a background helper |

Cleanup validates canonical roots and child containment. Safe Temp cleanup preserves 24 hours; Prefetch removes only .pf files older than 30 days. Windows Update download cleanup is advanced-only and restores the original wuauserv/BITS states in finally. Risky targets require explicit confirmation. Detailed cleanup paths are opt-in with --detailed-cleanup-logs; logs print directly to the terminal. Space hides remaining item details for one cleanup selection while deletion and accurate summaries continue; the next selection resets the display. Unsupported/redirected console input keeps ordinary logging.

Mole and Win11Debloat are downloaded only after user confirmation and are not bundled into NetBoost. See [Mole](../../docs/mole-cli.md) and [Win11Debloat](../../docs/win11debloat-cli.md) usage documents.

CS2 preparation uses the installed NVIDIA driver through the small native source binding in `src/native`; no Profile Inspector binary is required. Launch-priority rules leave FACEIT/Anti-Cheat unchanged and take effect when apps restart. See [CS2 preparation and recovery](../../docs/cs2-preparation.md) for scope, backup locations and validation limits.
