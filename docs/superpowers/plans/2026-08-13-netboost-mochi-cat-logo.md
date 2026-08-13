# NetBoost Mochi Cat Logo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the approved NetBoost Mochi Cat branding as production-ready SVG, PNG, and ICO assets, plus a portable PowerShell helper that creates a branded Windows shortcut while preserving the existing BAT launcher and version 1.0.1.

**Architecture:** Keep `NetBoost_Command_Center.bat` as the single launch entry point. Store deterministic brand assets under `assets/brand/`; attach the multi-resolution ICO to a generated `.lnk` whose target is the BAT file, working directory is the repository root, and elevation remains handled by the existing BAT logic. Validate file structure and shortcut metadata with a standalone PowerShell contract test.

**Tech Stack:** SVG, Sharp (SVG-to-PNG rasterization), Pillow (multi-resolution ICO packaging), Windows Script Host COM (`WScript.Shell`), PowerShell tests, pnpm project checks.

## Global Constraints

- Preserve project version `1.0.1`.
- Do not change the current CLI or Web UI design in this phase.
- Do not replace or wrap the canonical BAT launcher.
- Do not commit the machine-specific `.lnk` file.
- Keep the logo text-free and readable at 16×16 pixels.
- Use the approved visual direction: cream-white round cat, cyan network eyes, coral cheeks, cyan lightning pendant, navy rounded-square background, violet/cyan technical accents.
- Do not add npm lockfiles or npm-based workflows; retain pnpm.

---

## Task 1: Add the brand asset contract test

**Files:**

- Create: `tests/branding-assets.ps1`

- [ ] Add a small `Assert-True` helper that throws a descriptive error and increments a passing assertion count.
- [ ] Add binary helpers to read the PNG IHDR width/height as big-endian unsigned integers.
- [ ] Assert that `assets/brand/netboost-mochi-cat.svg` exists, parses as XML, has `viewBox="0 0 1024 1024"`, and contains no `text` or `script` elements.
- [ ] Assert that `assets/brand/netboost-mochi-cat.png` exists, has the PNG signature, and has a 1024×1024 IHDR.
- [ ] Assert that `assets/brand/netboost-mochi-cat.ico` exists, has ICO type `1`, contains exactly seven images, and advertises 16, 24, 32, 48, 64, 128, and 256 pixel layers.
- [ ] Run `powershell -NoProfile -ExecutionPolicy Bypass -File tests/branding-assets.ps1` and confirm it fails because the brand assets do not exist yet.
- [ ] Commit the failing contract test with message `test: define Mochi Cat brand asset contract`.

## Task 2: Create and render the approved logo assets

**Files:**

- Create: `assets/brand/netboost-mochi-cat.svg`
- Create: `assets/brand/netboost-mochi-cat.png`
- Create: `assets/brand/netboost-mochi-cat.ico`

- [ ] Draw a deterministic 1024×1024 SVG with a navy rounded-square background and a centered cream-white cat head.
- [ ] Add small coral inner ears and cheeks, cyan node/ring eyes, a minimal smile and whiskers, and a cyan lightning pendant with restrained violet accents.
- [ ] Keep shapes bold, symmetric, and separated enough to survive Windows icon downscaling; do not use text, scripts, external resources, or gradients on the cat.
- [ ] Render the SVG to a transparent-safe 1024×1024 PNG using the bundled Node runtime and Sharp.
- [ ] Package the PNG into an ICO containing 16, 24, 32, 48, 64, 128, and 256 pixel layers using the bundled Python runtime and Pillow.
- [ ] Run `powershell -NoProfile -ExecutionPolicy Bypass -File tests/branding-assets.ps1` and confirm every asset contract assertion passes.
- [ ] Inspect the rendered PNG visually and confirm that the face, cyan eyes, pendant, silhouette, and navy background match the approved concept.
- [ ] Commit the assets with message `feat: add NetBoost Mochi Cat brand assets`.

## Task 3: Add and test the branded shortcut helper

**Files:**

- Modify: `tests/branding-assets.ps1`
- Create: `tools/Create-NetBoostShortcut.ps1`
- Modify: `.gitignore`

- [ ] Extend the branding test to assert that `tools/Create-NetBoostShortcut.ps1` exists.
- [ ] Have the test invoke the helper with a temporary shortcut path, then open the result through `WScript.Shell` and assert the target is `NetBoost_Command_Center.bat`, the working directory is the repository root, and the icon points to `assets/brand/netboost-mochi-cat.ico` with index zero.
- [ ] Add a `finally` block to remove only the exact temporary test shortcut.
- [ ] Assert that `.gitignore` contains the exact root entry `/NetBoost Command Center.lnk`.
- [ ] Run the branding test and confirm the new shortcut assertions fail before the helper exists.
- [ ] Implement `tools/Create-NetBoostShortcut.ps1` with a default repository-root output, an optional explicit `-ShortcutPath`, and an optional `-Desktop` destination.
- [ ] Resolve all launcher, icon, working-directory, and output paths to absolute paths; reject simultaneous `-ShortcutPath` and `-Desktop`; require the destination directory to exist.
- [ ] Create the shortcut through `WScript.Shell`, set a versioned description, save it, verify it exists, and return a concise result object. Do not launch the shortcut.
- [ ] Add `/NetBoost Command Center.lnk` to `.gitignore` so the generated machine-specific shortcut is never committed.
- [ ] Run the branding test and confirm all asset and shortcut assertions pass.
- [ ] Run the helper with its default destination to generate the approved local `NetBoost Command Center.lnk`.
- [ ] Inspect the real shortcut through `WScript.Shell` and confirm its target, working directory, icon, and description.
- [ ] Commit the helper and tests with message `feat: add branded Windows shortcut helper`.

## Task 4: Document and verify the complete branding flow

**Files:**

- Modify: `README.md`
- Modify: `tests/README.md`

- [ ] Document the three committed logo assets and explain that Windows BAT files cannot carry embedded icons.
- [ ] Document the default shortcut command and the optional desktop command using `tools/Create-NetBoostShortcut.ps1`.
- [ ] Add the branding contract test command to `tests/README.md`.
- [ ] Run the PowerShell parser check for every project `.ps1` file.
- [ ] Run `tests/branding-assets.ps1`, `tests/cleanup-safety.ps1`, and `tests/backend-smoke.ps1`.
- [ ] Run the existing Web lint and production build through pnpm.
- [ ] Confirm `package.json` still reports `1.0.1`, no `package-lock.json` exists, and no npm command was introduced.
- [ ] Confirm `git status --short --ignored` shows the generated shortcut as ignored and no unrelated files are staged or modified.
- [ ] Review the final diff for launcher integrity, absolute-path handling, destructive operations, accidental UI changes, and visual/spec compliance.
- [ ] Commit the documentation and any final verification adjustments with message `docs: document Mochi Cat shortcut branding`.
