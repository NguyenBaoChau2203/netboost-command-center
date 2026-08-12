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

This starts `NetBoost_Command_Center.bat --web` on a random local port, verifies health/dashboard/settings/static UI serving, checks that cleanup targets match the constitution, confirms mutating requests need a session token, verifies non-admin privileged actions return `adminRequired`, and runs a report-only npm scan. It does not change DNS, scheduled tasks, cleanup targets, package manager files, or `node_modules`.
