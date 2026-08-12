# CodeGraph and Clean GitHub Baseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the local GitNexus index with CodeGraph and republish the verified local `1.0.1` project as a new GitHub repository with one clean root commit.

**Architecture:** Keep code-index data local and untracked. Preserve the old Git history in a verified local bundle before recreating `.git`, then delete and recreate the exact public GitHub repository only after GitHub authentication and local verification succeed.

**Tech Stack:** Git, GitHub CLI, CodeGraph CLI 1.4+, GitNexus CLI 1.6+, PowerShell 5.1, React 19, TypeScript 6, Vite 8.

## Global Constraints

- Target repository: `NguyenBaoChau2203/netboost-command-center`.
- Preserve repository visibility (`public`) and description.
- Publish branch `main` with exactly one root commit and tag `v1.0.1`.
- Preserve a recoverable bundle of the old Git refs under `.history-backup/`.
- Never commit `.gitnexus/`, `.codegraph/`, `.superpowers/`, `.playwright-cli/`, `build/`, `node_modules/`, environment files, or history backups.
- Keep CodeGraph telemetry disabled to match the project's local-first policy.
- CodeGraph covers the TypeScript/JavaScript surface; PowerShell remains outside its documented language list and must still be inspected directly.

---

### Task 1: Preserve and Verify the Current Baseline

**Files:**
- Modify: `.gitignore`
- Create locally, ignored: `.history-backup/netboost-before-clean-2026-08-13.bundle`

**Interfaces:**
- Consumes: current refs and the uncommitted `1.0.1` version-alignment changes.
- Produces: a verified recovery bundle plus a clean inclusion/exclusion boundary for the new repository.

- [ ] **Step 1: Add local-tool and recovery directories to `.gitignore`**

```gitignore
.codegraph/
.gitnexus/
.history-backup/
.superpowers/
```

- [ ] **Step 2: Create and verify the history bundle**

```powershell
New-Item -ItemType Directory -Path '.history-backup' -Force
git bundle create '.history-backup/netboost-before-clean-2026-08-13.bundle' --all
git bundle verify '.history-backup/netboost-before-clean-2026-08-13.bundle'
```

- [ ] **Step 3: Verify the application baseline**

```powershell
npm run lint --prefix src/web
npm run build --prefix src/web
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/backend-smoke.ps1 -Port 48740
```

Expected: lint/build exit `0`; smoke JSON contains `"ok": true` and `"version": "1.0.1"`.

### Task 2: Replace GitNexus with CodeGraph

**Files:**
- Delete locally: `.gitnexus/`
- Create locally, ignored: `.codegraph/`
- Modify outside repository: Codex MCP configuration and GitNexus global registry.

**Interfaces:**
- Consumes: installed `gitnexus` and `codegraph` CLIs.
- Produces: no GitNexus registration, a healthy CodeGraph index, and Codex MCP wiring.

- [ ] **Step 1: Remove the GitNexus index through its CLI**

```powershell
gitnexus clean --force
gitnexus list
```

Expected: `.gitnexus/` no longer exists and `netboost-command-center` is absent from the registry.

- [ ] **Step 2: Check/upgrade CodeGraph and disable telemetry**

```powershell
codegraph upgrade --check
codegraph telemetry off
codegraph version
```

- [ ] **Step 3: Wire CodeGraph to Codex and initialize the project**

```powershell
codegraph install --target codex --location global --yes
codegraph init 'D:\netboost-command-center'
codegraph status 'D:\netboost-command-center'
codegraph explore "How does the React UI obtain the backend version?"
```

Expected: `.codegraph/` exists, status is healthy, and exploration returns version-flow symbols from the TypeScript source.

### Task 3: Authenticate GitHub and Create a Clean Local Repository

**Files:**
- Replace repository metadata: `.git/`
- Preserve all non-ignored working-tree files as the clean snapshot.

**Interfaces:**
- Consumes: verified baseline and recovery bundle.
- Produces: branch `main`, one root commit, tag `v1.0.1`, and no old refs in the active `.git` database.

- [ ] **Step 1: Authenticate GitHub CLI with deletion scope**

```powershell
gh auth login --hostname github.com --git-protocol https --web --scopes delete_repo
gh auth status
```

- [ ] **Step 2: Verify the exact `.git` target and recreate repository metadata**

```powershell
$gitPath = (Resolve-Path -LiteralPath 'D:\netboost-command-center\.git').Path
if ($gitPath -ne 'D:\netboost-command-center\.git') { throw 'Unexpected .git target.' }
Remove-Item -LiteralPath $gitPath -Recurse -Force
git init -b main
```

- [ ] **Step 3: Stage only the intended clean snapshot**

```powershell
git add --all
git status --short
git diff --cached --check
git diff --cached --name-only
```

Expected: no local indexes, caches, backups, secrets, or agent scratch directories are staged.

- [ ] **Step 4: Commit and tag the clean baseline**

```powershell
git commit -m "chore: establish clean v1.0.1 baseline"
git tag -a v1.0.1 -m "Release 1.0.1"
git rev-list --count HEAD
```

Expected: commit count is exactly `1`.

### Task 4: Replace and Verify the GitHub Repository

**Files:**
- Mutate external repository: `NguyenBaoChau2203/netboost-command-center`.

**Interfaces:**
- Consumes: authenticated GitHub CLI and clean local `main`/`v1.0.1` refs.
- Produces: a newly created public GitHub repository at the original URL.

- [ ] **Step 1: Delete only the verified GitHub repository**

```powershell
gh repo delete NguyenBaoChau2203/netboost-command-center --yes
```

- [ ] **Step 2: Recreate it with preserved public metadata and push**

```powershell
gh repo create NguyenBaoChau2203/netboost-command-center --public --description "Windows CLI toolkit for DNS optimization, cache cleanup, and npm-to-pnpm migration scanning." --source . --remote origin --push
git push origin v1.0.1
```

- [ ] **Step 3: Verify local and remote history**

```powershell
git rev-list --count HEAD
git ls-remote --heads --tags origin
gh api repos/NguyenBaoChau2203/netboost-command-center/commits --paginate
gh repo view NguyenBaoChau2203/netboost-command-center --json nameWithOwner,url,visibility,defaultBranchRef,description
```

Expected: one commit on `main`, tag `v1.0.1`, public visibility, preserved description, and the original repository URL.

- [ ] **Step 4: Run final local verification**

```powershell
npm run lint --prefix src/web
npm run build --prefix src/web
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/backend-smoke.ps1 -Port 48741
codegraph status
git status --short --branch
```

Expected: all checks pass, CodeGraph is healthy, and the clean repository has no tracked-file changes.
