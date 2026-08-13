# Local Backend

Implemented module:

- `NetBoost.LocalWeb.ps1`

Run through the stable launcher:

```powershell
.\NetBoost_Command_Center.bat --web --port 47812
```

Behavior:

- Binds only to `127.0.0.1`.
- Generates a per-session token on startup.
- Serves `src/web/dist` when present.
- Exposes the API contract from `specs/001-local-web-command-center/contracts/api.md`.
- Uses in-memory job snapshots and `/api/jobs/{jobId}/events` polling.
- Returns `adminRequired: true` for privileged actions when the launcher is not elevated.
- Uses `HttpListener` when available, with a local `TcpListener` fallback for environments where `HttpListener` is unsupported.
- Exposes 15 cleanup targets. `windows-update-downloads` is high-risk, confirmation-required, Deep-only, and resolves its fixed path from `%SystemRoot%` rather than accepting a client path.
- Runs Windows Update download cleanup inside a `wuauserv`/`BITS` service-state transaction and restores only services that were originally running.

Frontend adapter:

- `src/web/src/api/client.ts` now reads real backend data for health, dashboard, cleanup targets, scheduled task state, and settings when the UI is served by the local backend.
- Vite dev server keeps the Gemini mock API by default.
- To test the real backend from a separate local dev host, set `localStorage.netboost_api_base` to the backend base URL, for example `http://127.0.0.1:47812`.
- To force mock mode, set `localStorage.netboost_use_mock_api` to `1`.

Still pending:

- UI-side job polling for mutating DNS/cleanup/task actions.
- UI display of `adminRequired` responses from privileged backend endpoints.
- Recycle Bin per-item logging is limited by Windows shell behavior; folder cleanup targets already emit per-file events.

No cloud service, user account, or telemetry should be added here.
