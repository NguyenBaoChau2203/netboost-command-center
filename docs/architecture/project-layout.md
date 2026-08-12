# Project Layout

## Current Layout

```text
NetBoost_Command_Center.bat
src/
  powershell/
    NetBoost_Command_Center.ps1
  backend/
  web/
specs/
docs/
tests/
```

## Rationale

- Root launcher stays stable for users.
- PowerShell core is separated from future web assets.
- `src/backend` is the boundary for local web server modules and API adapters.
- `src/web` is the boundary for Gemini's frontend work.
- `specs` stores Spec Kit-style feature artifacts.
- `docs` stores human handoff notes, mockup references, and architecture notes.
- `tests` reserves a place for smoke checks and fixtures.

## Mockup Policy

Do not commit large Stitch zip exports by default. Store references and selected screenshots only when they are needed for review.
