# Frontend Plan - Gemini 3.5 Flash High

Owner: Gemini 3.5 Flash High

## Objective

Build the local web UI from the approved Stitch mockup direction, using the API contract in `contracts/api.md`. The first pass may use mocked data, but component boundaries must match the backend contract.

## Source Inputs

- Latest Stitch mockup reference: `stitch_netboost_command_center_dashboard (4).zip`
- Use the refined desktop screens and latest mobile screens only.
- Ignore older screens in the zip that include cloud/account/migrate/unsupported cleanup content.
- Product rules: `.specify/memory/constitution.md`
- API contract: `specs/001-local-web-command-center/contracts/api.md`

## Proposed Location

- UI source: `src/web/`
- Shared frontend docs: `src/web/README.md`

## Suggested Stack

- React + Vite + TypeScript.
- CSS modules or plain CSS variables for design tokens.
- Keep dependencies small.
- Use code-native UI text and controls.
- Do not ship Stitch screenshots as UI.

## Required Screens

1. Dashboard
   - Adapter card
   - DNS card
   - Auto DNS card
   - Latency card
   - DNS latency comparison
   - Cleanup summary card
   - npm -> pnpm summary
   - Terminal output

2. DNS
   - Current adapter/DNS state
   - Auto select
   - Google
   - Cloudflare
   - Reset DHCP
   - Flush DNS
   - Operation result log

3. Cleanup
   - Supported target list only
   - Impact warning
   - Confirmation modal
   - Running state with progress
   - Per-file log panel
   - Completed summary
   - Locked-file table

4. npm -> pnpm
   - Report-only note
   - Path input
   - Scan controls
   - Summary cards
   - Project result cards/table
   - Suggested commands as copyable guidance
   - No migrate buttons

5. Auto Task
   - Scheduled task status
   - Create/remove/run-now actions
   - Admin warning
   - DNS task timeline/logs only

6. Settings
   - Language, theme, compact mode
   - Local bind address
   - Session token status
   - Confirmation toggles
   - Log settings
   - PowerShell script and launcher paths

## Mobile Rules

- Bottom navigation for primary tabs.
- Tables become stacked cards.
- Terminal lines can scroll horizontally.
- Sticky primary cleanup action is allowed.
- No account/avatar/cloud/logout UI.

## Copy Rules

- Vietnamese UI with proper accents.
- Keep technical commands and paths in monospace.
- Avoid unsupported labels:
  - CPU/RAM dashboard metrics
  - OpenDNS
  - cloud backup
  - account/profile/plans
  - automatic npm migration

## Deliverables

- Componentized UI under `src/web/`.
- Mock API adapter that can later swap to real backend.
- Responsive desktop/mobile layouts.
- Short `src/web/README.md` update with run/build instructions.
- Screenshots for dashboard, cleanup, npm scanner, task, settings on desktop and mobile.

## Frontend Definition Of Done

- UI compiles.
- No unsupported product claims remain.
- All buttons have realistic disabled/loading/success/error states.
- Data shape matches `contracts/api.md`.
- Desktop and mobile match the approved visual direction closely enough for Opus review.
