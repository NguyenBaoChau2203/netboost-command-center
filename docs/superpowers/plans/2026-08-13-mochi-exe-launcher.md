# Mochi EXE Launcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a small `NetBoost Command Center.exe` that displays the Mochi Cat icon, opens the CLI by default, forwards every existing argument, and replaces the v1.0.1 release ZIP with a verified package containing the EXE.

**Architecture:** A dependency-free C# Windows launcher resolves the PowerShell entry point relative to its own directory. It relaunches itself with UAC when needed, then starts Windows PowerShell and returns its exit code. PowerShell build scripts compile the launcher with the existing ICO and assemble the portable release deterministically.

**Tech Stack:** C#/.NET Framework via Windows PowerShell 5.1 `CSharpCodeProvider`, PowerShell tests, GitHub Release assets.

## Global Constraints

- Keep the product and release version at `1.0.1`.
- Double-clicking the EXE opens the CLI; `--web` and all existing arguments are forwarded unchanged.
- Keep `NetBoost_Command_Center.bat` as a fallback.
- Require no Node.js, pnpm, or separate .NET installation for supported Windows 10/11 users.
- The release EXE must embed `assets/brand/netboost-mochi-cat.ico`.

---

### Task 1: Build and test the native-looking launcher

**Files:**
- Create: `tests/exe-launcher.ps1`
- Create: `src/launcher/NetBoost.Launcher.cs`
- Create: `tools/Build-NetBoostLauncher.ps1`
- Modify: `.gitignore`

**Interfaces:**
- Produces: `NetBoostLauncher.Program.ResolveScriptPath(string)`, `QuoteWindowsArgument(string)`, `BuildArgumentString(IEnumerable<string>)`, `CreateElevationStartInfo(string, string[])`, and `CreatePowerShellStartInfo(string, string[])`.
- Produces: `tools/Build-NetBoostLauncher.ps1 -OutputPath <path>` and defaults to `NetBoost Command Center.exe` in the repository root.

- [ ] Write `tests/exe-launcher.ps1` first. It must require the source/build files, compile the C# in memory, round-trip difficult arguments through `CommandLineToArgvW`, assert the PowerShell and UAC process settings, build the EXE, verify GUI subsystem `2`, version `1.0.1`, and compare the embedded icon pixels with the canonical ICO.
- [ ] Run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\exe-launcher.ps1` and verify it fails because the launcher files do not exist.
- [ ] Implement `NetBoost.Launcher.cs` with safe Windows argument quoting, relative script resolution, UAC relaunch, PowerShell execution, UAC-cancel handling, and a clear message box for missing runtime files.
- [ ] Implement `Build-NetBoostLauncher.ps1` using `CSharpCodeProvider`, `/target:winexe`, `/win32icon`, `/optimize+`, and `/platform:anycpu`.
- [ ] Ignore only `/NetBoost Command Center.exe`, run the launcher test, and verify it passes.
- [ ] Commit the tested launcher increment.

### Task 2: Integrate EXE into shortcuts and reproducible release packaging

**Files:**
- Modify: `tests/branding-assets.ps1`
- Create: `tests/release-package.ps1`
- Modify: `tools/Create-NetBoostShortcut.ps1`
- Create: `tools/Build-NetBoostRelease.ps1`

**Interfaces:**
- `Create-NetBoostShortcut.ps1` targets `NetBoost Command Center.exe` when present and falls back to `NetBoost_Command_Center.bat` otherwise.
- `Build-NetBoostRelease.ps1 -OutputDirectory <path>` produces `NetBoost-Command-Center-v1.0.1.zip` and `.zip.sha256` and emits their paths and hash.

- [ ] Update branding and release-package tests first to require the EXE shortcut target and an EXE-containing portable ZIP.
- [ ] Run both tests and verify they fail because shortcut selection and release builder are absent.
- [ ] Update shortcut selection with EXE-first/BAT-fallback behavior.
- [ ] Implement the release builder with validated version-specific paths, exact runtime file copying, launcher compilation into staging, ZIP creation, and SHA-256 output.
- [ ] Run both tests and verify the shortcut and package assertions pass.
- [ ] Commit the tested packaging increment.

### Task 3: Document, verify, merge, and correct the public v1.0.1 package

**Files:**
- Modify: `README.md`
- Modify: `docs/releases/v1.0.1.md`
- Modify: `tests/README.md`

**Interfaces:**
- User instructions prefer `NetBoost Command Center.exe` and retain the BAT fallback.
- Release notes disclose the packaging correction and new checksum.

- [ ] Update user and test documentation for the EXE launcher.
- [ ] Run parser checks, all PowerShell suites including launcher/package tests, `pnpm lint`, `pnpm build`, `pnpm audit --audit-level high`, and `git diff --check`.
- [ ] Build the final release ZIP, extract it, run launcher/package smoke checks, and record the SHA-256.
- [ ] Commit documentation, push the branch, create a ready PR, and squash merge after GitHub reports it clean.
- [ ] Move the existing v1.0.1 tag to the merged commit, replace the public ZIP/checksum assets, and verify the downloaded public ZIP hash.
