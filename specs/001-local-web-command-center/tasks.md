# Task Split

## Frontend - Gemini

- [x] F1: Create `src/web` React/Vite scaffold.
- [x] F2: Add design tokens from Stitch refined mockups.
- [x] F3: Build app shell, desktop sidebar, mobile bottom nav.
- [x] F4: Build Dashboard screen using mock API data.
- [x] F5: Build DNS screen and operation states.
- [x] F6: Build Cleanup screen, warning panel, modal, live log, completed/locked states.
- [x] F7: Build npm -> pnpm report-only screen.
- [x] F8: Build Auto DNS task screen.
- [x] F9: Build Settings screen.
- [x] F10: Add typed API client matching `contracts/api.md`.
- [x] F11: Run responsive visual QA and capture screenshots.

## Backend - Codex

- [x] B1: Verify root launcher works after moving PowerShell core.
- [x] B2: Add structured output helpers for read-only status.
- [x] B3: Add file-level cleanup log events.
- [x] B4: Add job model for long-running operations.
- [x] B5: Add local web server `--web` mode.
- [x] B6: Implement API endpoints from `contracts/api.md`.
- [x] B7: Add admin-required handling for privileged operations.
- [x] B8: Add smoke checks and safe cleanup fixture tests.
- [x] B9: Wire frontend build serving when `src/web/dist` exists.

## Integration

- [x] I1: Replace frontend mock API with local backend calls.
- [x] I2: Verify all mutating actions require session token.
- [x] I3: Verify no unsupported product claims remain.
- [x] I4: Verify desktop and mobile views.
- [x] I5: Prepare Opus review packet.

## Deferred to Phase 2

- P2-1: async jobs (backend chạy cleanup/DNS đồng bộ, cần chuyển sang RunspacePool).
