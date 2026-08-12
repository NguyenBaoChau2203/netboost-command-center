# Prompt For Opus Review

Review this branch as a large NetBoost Command Center local web update.

Read first:

1. `.specify/memory/constitution.md`
2. `specs/001-local-web-command-center/spec.md`
3. `specs/001-local-web-command-center/plan.frontend-gemini.md`
4. `specs/001-local-web-command-center/plan.backend-codex.md`
5. `specs/001-local-web-command-center/contracts/api.md`
6. `specs/001-local-web-command-center/tasks.md`
7. `specs/001-local-web-command-center/review.opus.md`

Review priorities:

- Does the implementation preserve CLI behavior?
- Does the backend bind locally and avoid cloud/account/telemetry behavior?
- Are privileged actions and destructive cleanup protected by confirmation/admin checks?
- Does cleanup skip locked files without force-closing apps or stopping services?
- Does frontend copy avoid unsupported claims?
- Do frontend data shapes match the API contract?
- Are test/smoke results sufficient for the changed surface?

Return findings first, ordered by severity, with file/line references.
