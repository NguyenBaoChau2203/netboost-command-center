# Opus Review Checklist

Use this after Gemini frontend and Codex backend work are integrated.

## Review Prompt

Review the NetBoost Command Center local web update against the Spec Kit artifacts in `specs/001-local-web-command-center/` and the constitution in `.specify/memory/constitution.md`.

Prioritize:
- Security risks
- Privilege/elevation mistakes
- Product-scope drift
- Data loss or destructive cleanup behavior
- API contract mismatches
- Missing tests or smoke evidence
- UI copy that misleads users

## Must-Pass Checks

- Root `NetBoost_Command_Center.bat` still launches the CLI.
- Existing CLI flags still work.
- Web backend binds to `127.0.0.1`.
- No cloud/account/profile/plan/logout UI exists.
- Cleanup targets match the approved target list.
- Cleanup skips locked files and does not stop drivers or force-close apps.
- Dangerous cleanup actions require confirmation.
- Recycle Bin behavior is explicit.
- Admin-required states are visible for privileged operations.
- Terminal/log UI can show per-file cleanup events.
- Mobile does not show unsupported dashboard metrics or actions.

## Evidence To Request

- Git diff summary.
- CLI smoke output.
- Backend API smoke output.
- Frontend build output.
- Desktop screenshots for dashboard, cleanup, npm, task, settings.
- Mobile screenshots for dashboard, cleanup, npm, settings.
- Known limitations list.
