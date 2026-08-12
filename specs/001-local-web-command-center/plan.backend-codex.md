# Backend Plan - Codex

Owner: Codex

## Objective

Expose the existing PowerShell capabilities through a safe local backend for the web UI, while preserving CLI behavior.

## Proposed Location

- PowerShell core: `src/powershell/`
- Backend boundary notes and future server modules: `src/backend/`
- API contract: `specs/001-local-web-command-center/contracts/api.md`

## Architecture Direction

1. Keep `NetBoost_Command_Center.bat` as the root launcher.
2. Keep CLI flags functional.
3. Add a future `--web` mode that starts a local backend on `127.0.0.1`.
4. Serve built frontend assets from the local backend after `src/web` has a build output.
5. Use a job model for long-running operations.
6. Stream logs via Server-Sent Events or a polling endpoint.

## Backend Runtime Preference

Default preference: Windows PowerShell 5.1-compatible local server using `HttpListener`.

Reason:
- Matches current zero-install positioning.
- Keeps backend inspectable.
- Avoids requiring Node.js for users who only need DNS/cleanup.

Fallback:
- If `HttpListener` proves too fragile for streaming or browser security needs, document the blocker before proposing a Node-based local backend.

## Work Packages

### B1 - Preserve CLI After Layout Move

- Root `.bat` launches `src/powershell/NetBoost_Command_Center.ps1`.
- Existing flags continue to work:
  - `--help`
  - `--dashboard`
  - `--status`
  - `--auto-dns`
  - `--google`
  - `--cloudflare`
  - `--reset-dns`
  - `--scan-npm <path>`
  - `--lang en|vi`

### B2 - Extract Machine-Readable Operations

Add internal functions or modes that can return objects/JSON for:
- Current DNS status
- Dashboard state
- Auto DNS task state
- npm scan results
- Cleanup target estimates
- Cleanup result summaries

Do not break existing human-readable CLI output.

### B3 - File-Level Cleanup Logging

Update cleanup routines to emit structured log events:
- `INFO`
- `DELETE_OK`
- `DELETE_DIR`
- `SKIP_LOCKED`
- `WARN`
- `ERROR`
- `SUMMARY`

Each file event should include path, optional size, target label, and timestamp.

Important:
- Do not stop display drivers.
- Do not force-close applications.
- Do not add unsupported cleanup targets.

### B4 - Local Web Server

Add local server behavior:
- Bind to `127.0.0.1`.
- Generate a session token on startup.
- Reject unsafe origins when possible.
- Provide health/status endpoints.
- Provide operation endpoints from `contracts/api.md`.
- Support long-running job IDs for cleanup/npm scan/DNS operations.

### B5 - Admin/Elevation Handling

- Read-only endpoints run as standard user.
- Privileged endpoints return `adminRequired` when not elevated.
- If relaunch/elevation is added, it must use normal UAC and never bypass Windows security.

### B6 - Tests And Smoke Checks

- CLI smoke checks for help/status/scan behavior.
- JSON contract checks for read-only endpoints.
- Manual verification of cleanup logs on a safe temp fixture before system paths.
- Browser smoke once frontend exists.

## Backend Definition Of Done

- Existing CLI still works.
- `--web` can start a local-only backend.
- API responses follow the contract.
- Long-running operations produce visible logs.
- Cleanup logs file-level events and skips locked files.
- No cloud/account/telemetry surfaces exist.
