# Remove npm-to-pnpm Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the npm-to-pnpm scanner from every current product surface while retaining npm as the frontend development toolchain.

**Architecture:** Delete the vertical feature slice from React, the local REST backend, and the PowerShell CLI. Protect the removal with behavior-level smoke checks: the REST route returns 404 and CLI help no longer advertises the scanner.

**Tech Stack:** Windows PowerShell 5.1, React 19.2.6, TypeScript 6.0.2, Vite 8.0.12.

## Global Constraints

- Keep product version `1.0.1`.
- Keep the current UI visual design.
- Keep `npm run lint` and `npm run build` as supported developer commands.
- Do not edit historical release notes solely to erase historical npm build commands.

---

### Task 1: Removal regression checks

**Files:**
- Modify: `tests/backend-smoke.ps1`

**Interfaces:**
- Consumes: local backend HTTP API and CLI `--help` output.
- Produces: assertions that `/api/npm/scan` is absent and `--scan-npm` is not advertised.

- [ ] **Step 1: Replace the successful npm scan smoke flow with a POST expecting HTTP 404.**
- [ ] **Step 2: Add a CLI help assertion that `--scan-npm` is absent.**
- [ ] **Step 3: Run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/backend-smoke.ps1`.**

Expected: FAIL because `/api/npm/scan` still returns a job and CLI help still lists `--scan-npm`.

### Task 2: Remove backend and CLI scanner

**Files:**
- Modify: `src/backend/NetBoost.LocalWeb.ps1`
- Modify: `src/powershell/NetBoost_Command_Center.ps1`

**Interfaces:**
- Removes: `Find-NpmProjectsForWeb`, `Invoke-WebNpmScanJobWorker`, `Start-WebNpmScanJob`, `/api/npm/scan`, `Find-NpmProjects`, `Show-NpmScan`, and `NpmScan` argument mode.
- Preserves: health, DNS, cleanup, settings, tasks, and Web UI startup.

- [ ] **Step 1: Remove the npm worker functions and background bootstrap entries.**
- [ ] **Step 2: Remove the `/api/npm/scan` route.**
- [ ] **Step 3: Remove CLI scanner translations, functions, menu item, help text, aliases, and dispatch mode.**
- [ ] **Step 4: Change the CLI dashboard runtime card to show PowerShell/Windows context rather than npm/pnpm versions.**
- [ ] **Step 5: Run the smoke test and confirm the REST/CLI removal assertions pass.**

### Task 3: Remove React feature slice

**Files:**
- Delete: `src/web/src/views/NpmPnpmView.tsx`
- Modify: `src/web/src/App.tsx`
- Modify: `src/web/src/views/DashboardView.tsx`
- Modify: `src/web/src/api/client.ts`
- Modify: `src/web/src/api/types.ts`
- Modify: `src/web/src/api/mockData.ts`
- Modify: `src/web/src/i18n/translations.ts`

**Interfaces:**
- Removes: npm navigation ID, scanner view, scanner client state/methods, scan types, mock projects, and translation keys.
- Preserves: `ApiClient` public methods used by DNS, cleanup, settings, tasks, and folder selection.

- [ ] **Step 1: Remove navigation/import/render and dashboard teaser.**
- [ ] **Step 2: Remove scanner client state/methods and mock projects.**
- [ ] **Step 3: Remove scan types and translations.**
- [ ] **Step 4: Run `npm run lint` and expect exit code 0.**
- [ ] **Step 5: Run `npm run build` and expect exit code 0.**

### Task 4: Update current documentation

**Files:**
- Modify: `README.md`
- Modify: `src/web/README.md`
- Modify: `tests/README.md`
- Modify: `specs/001-local-web-command-center/contracts/api.md`
- Modify: `specs/001-local-web-command-center/spec.md`
- Modify: `specs/001-local-web-command-center/tasks.md`
- Modify: `specs/001-local-web-command-center/plan.backend-codex.md`
- Modify: `specs/001-local-web-command-center/plan.frontend-gemini.md`
- Modify: `specs/001-local-web-command-center/prompts/gemini-frontend.md`
- Modify: `specs/001-local-web-command-center/prompts/opus-review.md`
- Modify: `specs/001-local-web-command-center/review.opus.md`
- Modify: `docs/mockups/README.md`

**Interfaces:**
- Produces: current documentation that describes DNS, cleanup, tasks, and settings without advertising the removed scanner.

- [ ] **Step 1: Remove scanner-specific current documentation and diagrams.**
- [ ] **Step 2: Keep npm commands that are explicitly frontend build instructions.**
- [ ] **Step 3: Run tracked-source searches and review every remaining npm/pnpm occurrence for historical/build-tool legitimacy.**

### Task 5: Commit the removal slice

- [ ] **Step 1: Run backend smoke, lint, and build.**
- [ ] **Step 2: Inspect `git diff --check` and `git diff --stat`.**
- [ ] **Step 3: Commit as `refactor: remove npm-to-pnpm scanner` after all checks pass.**
