# Feature Spec: Local Web Command Center

## Status

Phase 1 Complete

## Goal

Add a local web interface for NetBoost Command Center while keeping the current PowerShell CLI usable.

The web UI should make DNS status, cleanup, scheduled task management, and settings easier to understand. It must stay local-only and transparent about privileged or destructive actions.

## Users

- Windows users who prefer a visual dashboard over the current CLI menu.
- Power users who still need CLI flags and scheduled tasks.

## User Stories

### US1 - Dashboard

As a user, I can open a local dashboard and see current adapter, DNS, Auto DNS task status, last latency check, cleanup status, npm scan summary, and recent logs.

Acceptance:
- Dashboard loads from `127.0.0.1`.
- No cloud/account UI is present.
- DNS providers are limited to Google and Cloudflare.
- Cleanup summary only references supported targets.

### US2 - DNS Controls

As a user, I can run auto DNS selection, force Google, force Cloudflare, reset to DHCP, flush DNS, and view current DNS.

Acceptance:
- Privileged operations request administrator elevation or return a clear admin-required state.
- Results stream into the terminal/log panel.
- Failure leaves current DNS unchanged when possible.

### US3 - Cleanup

As a user, I can choose supported cleanup targets, read the impact warning, confirm risky actions, and see file-level logs while cleanup runs.

Acceptance:
- Supported targets match the constitution.
- Recycle Bin and deep cleanup require explicit confirmation.
- Safe Temp cleanup preserves the newest 24 hours; Deep Temp cleanup preserves the newest hour.
- Prefetch is deep-only and limited to `.pf` files older than 30 days.
- Component Store and Delivery Optimization use supported Windows maintenance commands instead of raw Windows Update cache deletion.
- Locked files are skipped and listed.
- The app never stops drivers, force-closes apps, or claims unsupported cleanup targets.

### US4 - Auto DNS Scheduled Task

As a user, I can view, create, remove, and test the NetBoost Auto DNS scheduled task.

Acceptance:
- Task name is `NetBoost Auto DNS Optimizer`.
- Trigger is Windows logon with a 30 second delay.
- Admin-required states are visible.
- Logs show DNS task actions only.

### US5 - Settings

As a user, I can adjust local UI preferences and confirm backend safety settings.

Acceptance:
- Shows local-only bind address.
- Shows session token state.
- Shows log settings.
- Shows script and launcher paths.
- No account, logout, plan, or telemetry collection UI.

## Non-Functional Requirements

- Windows 10/11 target.
- PowerShell 5.1 compatibility for existing core.
- Web backend must bind to `127.0.0.1` unless explicitly changed in a later spec.
- UI must be responsive for desktop and approximately 390px mobile width.
- Logs should be copyable and optionally saved.
- No network dependency for running the local app after build assets exist.

## Out Of Scope

- Shipping an installer.
- Running as a Windows service.
- Cloud sync or user accounts.
- Unsupported cleanup targets such as browser cookies, Spotify, Adobe temp, VS Code extension cache, Windows Update cache, or generic pip/npm cache cleanup.
