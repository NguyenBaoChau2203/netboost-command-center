# NetBoost Mochi Cat Reference Fidelity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the simplified Mochi Cat artwork with the exact user-approved PNG, derive the Windows ICO from that PNG, remove the misleading SVG, and refresh the branded shortcut without changing launcher behavior or version 1.0.1.

**Architecture:** Treat the supplied 1254×1254 RGBA PNG as an immutable canonical binary identified by SHA-256. Enforce fidelity in the PowerShell brand contract, derive only the required ICO size layers from the canonical PNG, and keep the existing shortcut helper interface unchanged.

**Tech Stack:** PowerShell 5.1 contract tests, SHA-256, PNG binary metadata, Pillow ICO export, Windows Script Host COM shortcuts, pnpm verification.

## Global Constraints

- Canonical PNG SHA-256 must be exactly `65FB24DF0490DEF66230911CD64E50784CA5BAF95770C5F2B7E8F70E1668BBBE`.
- Canonical PNG must remain byte-for-byte identical to the supplied 1254×1254 RGBA source.
- Remove `assets/brand/netboost-mochi-cat.svg`; do not replace it with a raster wrapper.
- ICO must contain exactly 16, 24, 32, 48, 64, 128, and 256 pixel layers derived from the canonical PNG.
- Preserve `NetBoost_Command_Center.bat` as the canonical launcher.
- Preserve project version `1.0.1`.
- Do not change the CLI or Web UI design.
- Do not delete, rewrite, or force-push the GitHub repository.

---

### Task 1: Change the brand contract from vector fidelity to reference fidelity

**Files:**

- Modify: `tests/branding-assets.ps1`

**Interfaces:**

- Consumes: `assets/brand/netboost-mochi-cat.png`, `assets/brand/netboost-mochi-cat.ico`, `tools/Create-NetBoostShortcut.ps1`
- Produces: executable contract `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\branding-assets.ps1`

- [ ] **Step 1: Replace the SVG assertions with canonical PNG assertions**

  Set `$expectedPngHash` to `65FB24DF0490DEF66230911CD64E50784CA5BAF95770C5F2B7E8F70E1668BBBE`; assert that the SVG path does not exist; assert PNG IHDR dimensions are 1254×1254; assert `(Get-FileHash -Algorithm SHA256).Hash` equals `$expectedPngHash`. Keep the ICO and shortcut assertions intact.

- [ ] **Step 2: Run the changed contract and verify RED**

  Run: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\branding-assets.ps1`

  Expected: FAIL because the legacy SVG still exists or because the current simplified PNG is 1024×1024 and has the wrong SHA-256.

- [ ] **Step 3: Commit the failing contract**

  Run:

  ```powershell
  git add -- tests/branding-assets.ps1
  git commit -m "test: require approved Mochi Cat source artwork"
  ```

### Task 2: Replace assets and refresh the shortcut

**Files:**

- Replace: `assets/brand/netboost-mochi-cat.png`
- Replace: `assets/brand/netboost-mochi-cat.ico`
- Delete: `assets/brand/netboost-mochi-cat.svg`
- Recreate locally, ignored: `NetBoost Command Center.lnk`

**Interfaces:**

- Consumes: approved source PNG at `C:\Users\chau1\AppData\Local\Temp\codex-clipboard-8f0f283a-4e75-4cce-b81e-a63d1521f1cb.png`
- Produces: canonical PNG hash, seven-layer Windows ICO, refreshed `.lnk` using the unchanged helper

- [ ] **Step 1: Verify the source before copying**

  Run `Get-FileHash -Algorithm SHA256` and verify the source hash is exactly `65FB24DF0490DEF66230911CD64E50784CA5BAF95770C5F2B7E8F70E1668BBBE`; inspect it with Pillow and verify size `(1254, 1254)` and mode `RGBA`.

- [ ] **Step 2: Replace the PNG without image regeneration**

  Copy the exact source bytes to `assets/brand/netboost-mochi-cat.png`, then run `Get-FileHash` on both files and assert the hashes match.

- [ ] **Step 3: Remove the simplified SVG**

  Delete only `assets/brand/netboost-mochi-cat.svg` through an explicit patch.

- [ ] **Step 4: Derive the ICO**

  Use the bundled Python runtime and Pillow to load the canonical PNG as RGBA and save `assets/brand/netboost-mochi-cat.ico` with sizes `[(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)]`.

- [ ] **Step 5: Run the brand contract and verify GREEN**

  Run: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\branding-assets.ps1`

  Expected: PASS with canonical PNG hash, 1254×1254 dimensions, absent SVG, seven ICO layers, and verified shortcut metadata.

- [ ] **Step 6: Refresh and inspect the local shortcut**

  Run `tools\Create-NetBoostShortcut.ps1`, open the resulting `.lnk` through `WScript.Shell`, and verify its target, working directory, ICO path, and `1.0.1` description. Do not launch it.

- [ ] **Step 7: Inspect the committed PNG visually**

  Open `assets/brand/netboost-mochi-cat.png` and confirm it matches the supplied reference, including glow, eye nodes, ear circuitry, whisker nodes, collar, and lightning pendant.

- [ ] **Step 8: Commit the corrected assets**

  Run:

  ```powershell
  git add -- assets/brand/netboost-mochi-cat.png assets/brand/netboost-mochi-cat.ico assets/brand/netboost-mochi-cat.svg
  git commit -m "fix: restore approved Mochi Cat artwork"
  ```

### Task 3: Align documentation and run regression verification

**Files:**

- Modify: `README.md`
- Modify: `tests/README.md`

**Interfaces:**

- Consumes: canonical PNG and derived ICO contract
- Produces: user-facing asset documentation and final verification evidence

- [ ] **Step 1: Update documentation**

  Remove claims that an editable SVG exists. Document `netboost-mochi-cat.png` as the approved high-fidelity canonical source and `netboost-mochi-cat.ico` as its Windows shortcut derivative. Update the test description to include 1254×1254 and SHA-256 verification.

- [ ] **Step 2: Run all PowerShell checks**

  Parse all project `.ps1` files, then run:

  ```powershell
  .\tests\branding-assets.ps1
  .\tests\package-manager-policy.ps1
  .\tests\cleanup-safety.ps1
  .\tests\backend-smoke.ps1
  ```

  Expected: all commands exit zero, backend reports version `1.0.1`, 15 cleanup targets, removed npm scanner, and verified guards.

- [ ] **Step 3: Run pnpm checks**

  From `src/web`, run `pnpm lint`, `pnpm build`, and `pnpm audit --audit-level high`.

  Expected: lint and build exit zero; audit reports no known vulnerabilities.

- [ ] **Step 4: Review repository state**

  Confirm `git diff --check` is clean, the generated `.lnk` is ignored, the SVG is deleted, the canonical PNG hash matches, and no unrelated source or build output is modified.

- [ ] **Step 5: Commit documentation**

  Run:

  ```powershell
  git add -- README.md tests/README.md
  git commit -m "docs: mark Mochi Cat PNG as canonical artwork"
  ```
