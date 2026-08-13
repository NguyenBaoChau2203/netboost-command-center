# PowerShell Core

This folder contains the current NetBoost Command Center CLI and system-operation logic.

Current entrypoint:

```bat
..\..\NetBoost_Command_Center.bat
```

Direct script path:

```powershell
.\src\powershell\NetBoost_Command_Center.ps1
```

Cleanup safety:

- Every filesystem target passes through canonical-root and child-containment guards.
- Windows Update download cleanup targets only `%SystemRoot%\SoftwareDistribution\Download` contents.
- Running `wuauserv` and `BITS` services are temporarily stopped and restored to their original states in `finally`, including after a cleanup error.
- The Web UI exposes this action only as a confirmation-required Deep target; it is not part of the default CLI `Clean-All` sequence.

Future backend work should preserve existing CLI behavior while adding structured output and local web server support.
