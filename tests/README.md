# Tests

Reserved for future automated checks and smoke fixtures.

Suggested test groups:

- CLI smoke checks
- PowerShell structured-output checks
- Safe cleanup fixture checks
- Local web API contract checks
- Frontend build and visual smoke checks

Current backend smoke:

```powershell
.\tests\backend-smoke.ps1
```

This starts `NetBoost_Command_Center.bat --web` on a random local port, verifies health/dashboard/static UI serving, checks the 14-target cleanup contract, confirms mutating requests need a session token, verifies non-admin privileged actions return `adminRequired`, and confirms the removed npm scanner routes stay absent. It does not change DNS, scheduled tasks, or system cleanup targets.

Cleanup policy safety:

```powershell
.\tests\cleanup-safety.ps1
```

This uses disposable temporary folders to verify canonical-root guards, candidate containment, Prefetch age/pattern policy, deep-only enforcement, and rejection of unsupported target IDs. It does not request Administrator rights or delete system files.
