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

CLI Cleanup Center behavior:

```powershell
.\tests\cli-cleanup-center.ps1
```

This verifies the Safe, confirmation-required, and Advanced target mappings; exact `CONFIRM` behavior; corrected main-menu routing and copy; and the `[10]` through `[13]` shortcuts. It injects fake input and a fake cleanup dispatcher, so it never deletes real files or invokes Windows maintenance actions.

Cleanup policy safety:

```powershell
.\tests\cleanup-safety.ps1
```

This uses disposable temporary folders and injected service fakes to verify canonical-root guards, candidate containment, Prefetch age/pattern policy, deep-only enforcement, rejection of unsupported target IDs, and Windows Update service restoration on success, cleanup failure, and stop failure. It does not request Administrator rights, stop real services, or delete system files.

Brand assets and Windows shortcut contract:

```powershell
.\tests\branding-assets.ps1
```

This verifies that the simplified SVG is absent, the canonical Mochi Cat PNG is the approved 1254×1254 RGBA file with the exact SHA-256 hash, and the ICO contains all seven required layers. It also builds the local EXE and validates Git ignore policy plus the target, working directory, icon, and version metadata of a disposable Windows shortcut. It does not launch NetBoost or request elevation.

Mochi Cat EXE launcher:

```powershell
.\tests\exe-launcher.ps1
```

This compiles the C# launcher in memory and as a Windows EXE, round-trips difficult command-line arguments through the native Windows parser, verifies UAC and PowerShell process settings, checks the GUI subsystem and version metadata, and compares the embedded icon pixel-for-pixel with the 32-pixel ICO layer. It does not show a UAC dialog or execute the real NetBoost runtime.

Portable release package:

```powershell
.\tests\release-package.ps1
```

This builds and extracts the v1.0.1 portable ZIP, verifies all runtime files including the branded EXE, rejects development-only files, parses the packaged PowerShell scripts, creates a disposable EXE-targeting shortcut, and verifies the SHA-256 sidecar file.

pnpm migration policy:

```powershell
.\tests\package-manager-policy.ps1
```

This verifies version 1.0.1, the pinned pnpm package manager, the committed `pnpm-lock.yaml`, absence of npm's `package-lock.json`, pnpm store ignore policy, and pnpm-only README commands.
