# Prompt For Gemini 3.5 Flash High

Use this repository as a Spec Kit project. Your job is frontend only.

Read these files first:

1. `.specify/memory/constitution.md`
2. `specs/001-local-web-command-center/spec.md`
3. `specs/001-local-web-command-center/plan.frontend-gemini.md`
4. `specs/001-local-web-command-center/contracts/api.md`
5. `docs/mockups/README.md`

Build the local web UI in `src/web/`.

Important constraints:

- This is a local-only Windows utility UI.
- Do not add cloud login, accounts, plans, logout, telemetry, backup, VPN, antivirus, CPU/RAM dashboard metrics, or OpenDNS.
- Cleanup targets must match the constitution.
- The UI must show warnings and confirmation for risky cleanup.
- The terminal/log surface must support per-file cleanup logs.
- Use Vietnamese UI text with proper accents.
- Keep technical paths and commands in monospace.
- Use mocked API data only behind a typed API adapter that follows `contracts/api.md`.

Deliver:

- React/Vite/TypeScript UI under `src/web/`.
- Responsive desktop and mobile screens.
- Build/run instructions in `src/web/README.md`.
- Screenshots for final review.

Do not modify backend or PowerShell files unless the user explicitly asks you to.
