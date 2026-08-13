# Tests

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

This starts `NetBoost_Command_Center.bat --web` on a random local port, verifies health/dashboard/static UI serving, checks the 15-target cleanup contract, confirms mutating requests need a session token, verifies non-admin privileged actions return `adminRequired`, and confirms the removed npm scanner routes stay absent. It does not change DNS, scheduled tasks, or system cleanup targets.

Cleanup policy safety:

```powershell
.\tests\cleanup-safety.ps1
```

This uses disposable temporary folders and injected service fakes to verify canonical-root guards, candidate containment, Prefetch age/pattern policy, deep-only enforcement, rejection of unsupported target IDs, and Windows Update service restoration on success, cleanup failure, and stop failure. It does not request Administrator rights, stop real services, or delete system files.

Brand assets and Windows shortcut contract:

```powershell
.\tests\branding-assets.ps1
```

This verifies that the simplified SVG is absent, the canonical Mochi Cat PNG is the approved 1254×1254 RGBA file with the exact SHA-256 hash, and the ICO contains all seven required layers. It also validates Git ignore policy and the target, working directory, icon, and version metadata of a disposable Windows shortcut. It does not launch NetBoost or request elevation.

pnpm migration policy:

```powershell
.\tests\package-manager-policy.ps1
```

This verifies version 1.0.1, the pinned pnpm package manager, the committed `pnpm-lock.yaml`, absence of npm's `package-lock.json`, pnpm store ignore policy, and pnpm-only README commands.
