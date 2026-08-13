<div align="center">

# ⚡ NetBoost Command Center

**A dual-mode, local-first Windows optimization suite**

*CLI-first · React/Vite Web UI · PowerShell 5.1 backend · Local-first backend*

---

[![Platform: Windows](https://img.shields.io/badge/Platform-Windows%2010%20%2F%2011-0078D4?style=flat-square&logo=windows&logoColor=white)](https://microsoft.com/windows)
[![Shell: PowerShell 5.1](https://img.shields.io/badge/Shell-PowerShell%205.1-012456?style=flat-square&logo=powershell&logoColor=white)](https://docs.microsoft.com/en-us/powershell/)
[![React 19](https://img.shields.io/badge/React-19-61DAFB?style=flat-square&logo=react&logoColor=black)](https://react.dev)
[![Vite 8](https://img.shields.io/badge/Vite-8-646CFF?style=flat-square&logo=vite&logoColor=white)](https://vitejs.dev)
[![TypeScript 6](https://img.shields.io/badge/TypeScript-6-3178C6?style=flat-square&logo=typescript&logoColor=white)](https://www.typescriptlang.org)
[![Tailwind CSS 4](https://img.shields.io/badge/Tailwind_CSS-4-06B6D4?style=flat-square&logo=tailwindcss&logoColor=white)](https://tailwindcss.com)
[![UI: Modern CLI](https://img.shields.io/badge/UI-Modern%20CLI%20%2B%20Web%20UI-7c3aed?style=flat-square)](#-ui-modes)
[![i18n](https://img.shields.io/badge/i18n-EN%20%2F%20VI-f59e0b?style=flat-square)](#-internationalization-i18n)
[![License: MIT](https://img.shields.io/badge/License-MIT-22c55e?style=flat-square)](LICENSE)

</div>

---

## 📖 Overview

**NetBoost Command Center** is a powerful, privacy-first Windows system optimization tool that operates in two complementary modes from a single launcher:

| Mode | Interface | Entry Point | Description |
|------|-----------|-------------|-------------|
| **CLI** | Terminal (CMD/PowerShell) | `NetBoost Command Center.exe` (`.bat` fallback) | 17-option interactive menu, fully ASCII-safe |
| **Web UI** | Browser at `127.0.0.1:47812` | `--web` flag or Option `[17]` | React/Vite SPA served by a pure PowerShell TCP backend |

Both modes share the **same PowerShell core engine** for DNS management, cache cleanup, and scheduled task control. NetBoost does not collect telemetry or require an account; core actions run through a local loopback backend on your machine.

---

## ✨ Feature Highlights

### 🌐 DNS Optimization
- **Auto-select DNS** — pings Google (`8.8.8.8`) and Cloudflare (`1.1.1.1`) with 6 samples each, automatically applies the faster provider
- **One-command force DNS** — instantly apply Google DNS or Cloudflare DNS to the active network adapter
- **Scheduled Auto-DNS Task** — optional, off by default, and created only after explicit confirmation; registers `NetBoost Auto DNS Optimizer` to run 30 seconds after Windows logon
- **Flush DNS / Reset to DHCP** — clean slate in one keystroke

### 🧹 Cache Cleanup (15 Targets)
Safe, transparent cleanup with bounded estimates, automatic locked-file skipping, and supported Windows maintenance actions:

| # | Target ID | Path | Risk |
|---|-----------|------|------|
| 1 | `user-temp` | `%TEMP%` — Safe: >24h, Deep: >1h | Low |
| 2 | `windows-temp` | `C:\Windows\Temp` — Safe: >24h, Deep: >1h | Low |
| 3 | `directx-cache` | `%LOCALAPPDATA%\D3DSCache` | Medium |
| 4 | `nvidia-cache` | `%LOCALAPPDATA%\NVIDIA\DXCache/GLCache/NV_Cache` | Medium |
| 5 | `steam-cache` | Steam `shadercache\730` (all libraries) | Medium |
| 6 | `crash-dumps` | `%LOCALAPPDATA%\CrashDumps` | High ⚠️ |
| 7 | `thumbnails` | `%LOCALAPPDATA%\Microsoft\Windows\Explorer` | Low |
| 8 | `inet-cache` | `%LOCALAPPDATA%\Microsoft\Windows\INetCache` | Low |
| 9 | `recycle-bin` | Recycle Bin | High ⚠️ |
| 10 | `component-store` | DISM `/StartComponentCleanup` — Deep only | Medium ⚠️ |
| 11 | `delivery-optimization` | Supported Delivery Optimization cmdlet | Low |
| 12 | `windows-update-downloads` | `%SystemRoot%\SoftwareDistribution\Download` — Deep only | High ⚠️ |
| 13 | `windows-font-cache` | Windows Font Cache service directory | Low |
| 14 | `windows-prefetch` | Only `*.pf` older than 30 days — Deep only | Medium ⚠️ |
| 15 | `windows-error-reports` | `C:\ProgramData\Microsoft\Windows\WER` | Low |

> Prefetch and Windows Update downloads are visible but off by default. Both require Deep mode and confirmation. Prefetch preserves `ReadyBoot` and `Layout.ini`. Windows Update cleanup deletes only the contents below `SoftwareDistribution\Download`, temporarily stops only running `wuauserv`/`BITS` services, and restores their original states even when cleanup fails. Windows may download removed update packages again when needed.

The Windows Update sequence follows Microsoft's documented troubleshooting workflow: [Microsoft Support — troubleshoot problems updating Windows](https://support.microsoft.com/en-us/windows/deployment/updates-lifecycle/troubleshoot-problems-updating-windows) and [Microsoft Learn — common Windows Update errors](https://learn.microsoft.com/en-us/troubleshoot/windows-client/installing-updates-features-roles/common-windows-update-errors).

### 📊 Live Dashboard
- Real-time adapter name, DNS servers, and connection status
- Side-by-side latency comparison: Google vs. Cloudflare (ms)
- Auto-DNS Scheduled Task status, last run time, and trigger info
- Live PowerShell execution log stream

### ⏰ Scheduled Task Management
- Create / remove `NetBoost Auto DNS Optimizer` via Task Scheduler with explicit confirmation before creation
- Runs at highest privilege (`RunLevel Highest`) with 30-second network-ready delay
- Test-run task directly from the Web UI with live PowerShell console output

### ⚙️ Settings (Web UI)
- Language: Vietnamese (`vi`) / English (`en`) — persisted to `src/backend/settings.local.json`
- Theme: Light / Dark / System (follows OS preference)
- Compact mode toggle
- Detailed per-file deletion logging is opt-in; paths are hidden by default, live job logs are capped in memory, and recent logs stay local
- Security: bind address display, session-token policy

---

## 🚀 Quick Start

### Prerequisites
- Windows 10 / 11
- Windows PowerShell 5.1 (built-in, no additional install needed)
- Modern browser (for Web UI mode only)

### Mochi Cat EXE launcher and branded shortcut

Windows batch files cannot embed a custom icon. The release ZIP therefore includes `NetBoost Command Center.exe`, a small launcher with the Mochi Cat icon embedded. It opens the CLI by default, requests Administrator permission through UAC, and forwards every existing flag such as `--web` or `--dashboard`. `NetBoost_Command_Center.bat` remains available as a fallback.

When working from a source checkout, build or refresh the ignored local EXE with:

```powershell
.\tools\Build-NetBoostLauncher.ps1
```

Create or refresh `NetBoost Command Center.lnk` in the project root:

```powershell
.\tools\Create-NetBoostShortcut.ps1
```

Create the branded shortcut on the current user's desktop instead:

```powershell
.\tools\Create-NetBoostShortcut.ps1 -Desktop
```

The shortcut targets the EXE when it is present and falls back to the BAT otherwise. The generated `.lnk` is machine-specific and ignored by Git. The committed brand files are:

- `assets/brand/netboost-mochi-cat.png` — approved high-fidelity 1254×1254 canonical artwork
- `assets/brand/netboost-mochi-cat.ico` — Windows icon derived from the canonical PNG, with 16–256 px layers

### 1 — Launch the CLI (Auto-Elevation)

After extracting the release ZIP, simply **double-click** `NetBoost Command Center.exe`. Use `NetBoost_Command_Center.bat` only as a fallback.

The EXE automatically detects whether it is running with Administrator privileges. If not, it relaunches itself with the Windows `runas` verb, preserving every command-line argument. No "Run as Administrator" right-click is required.

```powershell
& '.\NetBoost Command Center.exe'
& '.\NetBoost Command Center.exe' --web
```

### 2 — Use the CLI Menu

```
+--------------------------------------------------------------------+
|                         NETBOOST COMMAND CENTER                    |
+--------------------------------------------------------------------+
  Mo nhanh: dashboard khong tu chay, chi xem khi ban chon muc 15.

  NETWORK / DNS
  [1 ] Auto chon DNS ping thap hon ngay bay gio
  [2 ] Ep Google DNS (8.8.8.8 / 8.8.4.4)
  [3 ] Ep Cloudflare DNS (1.1.1.1 / 1.0.0.1)
  [4 ] Xem DNS hien tai
  [5 ] Tao lich auto DNS khi dang nhap
  [6 ] Xoa lich auto DNS
  [7 ] Xoa bo nho dem DNS (Flush DNS)
  [8 ] Dat lai DNS ve DHCP/Auto

  CLEANUP
  [9 ] Mo Trung tam don dep CLI (An toan / Nang cao)
  [10] Don tep tam Windows & Nguoi dung cu hon 24 gio
  [11] Don dep bo nho dem Game & Do hoa
  [12] Don cache Windows co ban
  [13] Lam trong Thung rac (can xac nhan)

  TOOLS
  [14] Mo Chris Titus WinUtil
  [15] Xem bang thong tin (Dashboard)
  [16] Switch interface language to English
  [17] Mo giao dien Web UI (trinh duyet local)
  [0 ] Thoat chuong trinh

Chon muc (Select option):
```

Option **`[9]`** opens the CLI Cleanup Center with three clearly separated groups:

- **Safe:** Temp older than 24 hours, Game/Graphics caches, basic Windows caches, or the recommended safe group.
- **Confirmation required:** Crash Dumps and Recycle Bin require `y` before execution.
- **Advanced:** Component Store, Windows Update downloads, and Prefetch require the exact case-sensitive text `CONFIRM`. Advanced actions run one at a time; there is no “run all advanced” option.

The CLI and Web UI use the same cleanup target definitions, path guards, retention rules, and Windows service restoration logic.

### 3 — Launch the Web UI (Option 17 or `--web`)

Select **`[17]`** from the menu, or run with the `--web` flag:

```powershell
& '.\NetBoost Command Center.exe' --web
& '.\NetBoost Command Center.exe' --web --port 47812
```

When Option 17 is triggered:
1. **Port check** — NetBoost checks if port `47812` is occupied and refuses to stop unrelated local processes; close the other app or choose another port
2. **TCP backend starts** — `Start-NetBoostTcpBackend` binds a `System.Net.Sockets.TcpListener` to `127.0.0.1:47812`
3. **Browser opens** — `Start-Process http://127.0.0.1:47812/` launches your default browser
4. **Non-blocking loop** — the CLI window stays alive, polling `[Console]::KeyAvailable` every 100 ms; press **`Q`** or **`ESC`** to cleanly stop the server and return to the main menu without closing CMD

```
+----------------------------------------------------------+
  [Web] NetBoost Command Center local backend is running.
+----------------------------------------------------------+
  - URL          : http://127.0.0.1:47812/
  - Bind Address : 127.0.0.1
  - Runtime      : TcpListener Fallback
  - Session Token: <auto-generated GUID>
------------------------------------------------------------
  [!] Keep this command prompt window open while using the Web UI.
  [*] You can access the Web UI at: http://127.0.0.1:47812/
  [x] Press Q or ESC to stop the Web UI and return to the main CLI menu.
+----------------------------------------------------------+
```

---

## 💻 CLI Reference

All flags are accepted by both the EXE and BAT launchers and passed through to the PowerShell script.

| Flag | Alias | Description |
|------|-------|-------------|
| *(none)* | | Interactive 17-option menu (default mode) |
| `--auto-dns` | `-auto-dns`, `-AutoDns` | Non-interactive: run Auto DNS selection and exit |
| `--google` | `-google` | Force Google DNS (8.8.8.8 / 8.8.4.4) and exit |
| `--cloudflare` | `-cloudflare` | Force Cloudflare DNS (1.1.1.1 / 1.0.0.1) and exit |
| `--reset-dns` | `-reset-dns`, `-ResetDns` | Reset DNS to DHCP/Auto and exit |
| `--status` | `-status` | Show current DNS adapter status and exit |
| `--dashboard` | `-dashboard` | Show telemetry dashboard and exit |
| `--web` | `-web` | Start local Web UI backend server |
| `--port <number>` | `-port` | Set web server port (default: `47812`, range: 1–65535) |
| `--lang en` | `-lang en` | Use English interface |
| `--lang vi` | `-lang vi` | Use Vietnamese interface (default) |
| `--help` | `-help`, `/?` | Show usage reference and exit |

**Examples:**
```powershell
# Run as a one-shot Auto DNS optimizer (e.g. in a scheduled task)
& '.\NetBoost Command Center.exe' --auto-dns --lang en

# Start Web UI on a custom port
& '.\NetBoost Command Center.exe' --web --port 8080
```

---

## 🎨 UI Modes

### ASCII Mode (Default — `$UseFancyUi = $false`)

The default mode uses only 7-bit ASCII characters (`+`, `-`, `|`, `[ ]`, `[OK]`, `[!]`, `[ERR]`) for all UI chrome. This guarantees **100% visual fidelity** on every Windows font and code page — including the default CMD window running under UAC elevation where Unicode rendering can produce garbled `? ?` artifacts.

### Fancy / Emoji Mode (`$UseFancyUi = $true`)

Enable by editing line 11 of [NetBoost_Command_Center.ps1](./src/powershell/NetBoost_Command_Center.ps1):
```powershell
$UseFancyUi = $true   # Change from $false to enable emoji icons
```

In Fancy mode the same icons used in the Web UI are echoed in the terminal (🌐 ⚡ 🧹 📦 📊 🛠️). Recommended for **Windows Terminal** or **VS Code terminal** with a Nerd Font installed.

---

## 🗂️ Project Structure

```
NetBoost_Command_Center/
│
├── NetBoost Command Center.exe          # Generated/release launcher with embedded Mochi Cat icon
├── NetBoost_Command_Center.bat          # Fallback launcher: auto-elevation + PS1 entry point
├── assets/brand/                        # Canonical Mochi Cat PNG and Windows ICO
├── tools/Build-NetBoostLauncher.ps1     # Compiles the local EXE with the embedded icon
├── tools/Build-NetBoostRelease.ps1      # Builds the portable ZIP and SHA-256 file
├── tools/Create-NetBoostShortcut.ps1    # Creates an EXE-first branded Windows shortcut
├── LICENSE                              # MIT License
├── README.md                            # This file
├── .gitignore
│
├── src/
│   ├── launcher/
│   │   └── NetBoost.Launcher.cs          # UAC, safe argument forwarding, PowerShell startup
│   │
│   ├── powershell/
│   │   └── NetBoost_Command_Center.ps1  # CLI core: menu, DNS, cleanup
│   │                                    # 1 532 lines · #Requires -Version 5.1
│   │
│   ├── backend/
│   │   ├── NetBoost.LocalWeb.ps1        # TCP HTTP server + REST API engine
│   │   │                                # 1 776 lines · dot-sourced by CLI at startup
│   │   ├── settings.local.json          # User settings (auto-created on first run)
│   │   └── README.md
│   │
│   └── web/                             # React / Vite / TypeScript frontend
│       ├── index.html
│       ├── package.json                 # react@19, vite@8, tailwindcss@4, typescript@6
│       ├── vite.config.ts
│       ├── tsconfig.json
│       ├── dist/                        # Production build (served by backend)
│       │   ├── index.html
│       │   ├── favicon.svg
│       │   ├── icons.svg
│       │   └── assets/
│       └── src/
│           ├── main.tsx                 # React entry point
│           ├── App.tsx                  # Shell: sidebar nav, top bar, mobile bottom nav
│           ├── index.css                # Global styles + design tokens
│           ├── App.css
│           ├── api/
│           │   ├── client.ts            # Typed API client (fetch + token auth)
│           │   ├── types.ts             # Shared TypeScript interfaces
│           │   └── mockData.ts          # Dev-mode mock data
│           ├── i18n/
│           │   └── translations.ts      # Vietnamese + English
│           └── views/
│               ├── DashboardView.tsx    # Latency cards, cleanup summary, live logs
│               ├── DnsView.tsx          # DNS adapter status + optimization actions
│               ├── CleanupView.tsx      # 15-target cleanup with live job progress
│               ├── AutoTaskView.tsx     # Task Scheduler management + workflow diagram
│               └── SettingsView.tsx     # Language, theme, security, logging settings
│
├── docs/
│   ├── architecture/
│   └── mockups/
│
├── specs/
└── tests/
```

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ NetBoost Command Center.exe (recommended) / .bat (fallback)     │
│              (Auto-UAC + safe argument forwarding)              │
└──────────────────────────────┬──────────────────────────────────┘
                               │  passes all args
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│           src/powershell/NetBoost_Command_Center.ps1            │
│                                                                 │
│  ┌─────────────────┐   dot-sources   ┌───────────────────────┐  │
│  │   CLI Engine    │ ─────────────►  │  src/backend/         │  │
│  │  (Menu / DNS /  │                 │  NetBoost.LocalWeb.ps1│  │
│  │    Cleanup)     │ ◄─────────────  │  (REST API + TCP srv) │  │
│  └─────────────────┘  shared state   └───────────────────────┘  │
└──────────────────────────────┬──────────────────────────────────┘
                               │
              Mode: --web / Option [17]
                               │
                               ▼
          ┌────────────────────────────────────┐
          │  TcpListener on 127.0.0.1:47812    │
          │                                    │
          │  Serves:                           │
          │   • GET  /api/health               │
          │   • GET  /api/dashboard            │
          │   • POST /api/dns/auto             │
          │   • POST /api/dns/provider         │
          │   • POST /api/dns/flush            │
          │   • POST /api/dns/reset            │
          │   • GET  /api/cleanup/targets      │
          │   • POST /api/cleanup/run          │
          │   • GET  /api/jobs/{id}            │
          │   • GET  /api/jobs/{id}/events     │
          │   • GET  /api/tasks/auto-dns       │
          │   • POST /api/tasks/auto-dns/*     │
          │   • GET  /api/settings             │
          │   • PATCH /api/settings            │
          │   • GET  /                  ──► src/web/dist/index.html │
          └─────────────┬──────────────────────┘
                        │  HTTP (loopback only)
                        ▼
          ┌─────────────────────────────────┐
          │   React 19 + Vite SPA           │
          │   (pre-built in src/web/dist/)  │
          │                                 │
          │  Views: Dashboard · DNS         │
          │         Cleanup · AutoTask      │
          │         Settings                │
          │                                 │
          │  i18n: Vietnamese + English     │
          │  Theme: Light / Dark / System   │
          └─────────────────────────────────┘
```

### Security Model

| Property | Value |
|----------|-------|
| **Bind address** | `127.0.0.1` (loopback only — no LAN/WAN exposure) |
| **Session token** | Per-session UUID generated at `Start-NetBoostWebBackend`; passed as an `HttpOnly` cookie `netboost_session` and required for all API calls except health/static assets |
| **CORS** | Only the exact local backend origin, for example `http://127.0.0.1:47812`, is accepted |
| **Token validation** | Checks `X-NetBoost-Token` header, `Authorization: Bearer`, then `netboost_session` cookie; query-string tokens are not accepted |
| **Data collection** | **None.** NetBoost does not upload user files, paths, logs, or settings |
| **Process isolation** | Background API jobs run in separate PowerShell runspaces; live job events are capped in memory |
| **Shutdown** | Background PowerShell runspaces, the TCP server, and owned dialog child processes are stopped when the CLI window closes |

---

## 🔌 Web UI — REST API Reference

All endpoints require the session cookie or `X-NetBoost-Token` header (except `GET /api/health` and static assets).

| Method | Path | Body / Params | Description |
|--------|------|---------------|-------------|
| `GET` | `/api/health` | — | Server info, `isAdmin`, version |
| `GET` | `/api/dashboard` | — | Adapter, DNS, task, latency, recent logs |
| `POST` | `/api/dns/auto` | — | Ping-test and apply fastest DNS |
| `POST` | `/api/dns/provider` | `{ provider: "Google"\|"Cloudflare" }` | Force specific DNS provider |
| `POST` | `/api/dns/flush` | — | Flush DNS client cache |
| `POST` | `/api/dns/reset` | — | Reset DNS to DHCP/Auto |
| `GET` | `/api/cleanup/targets` | — | 15 cleanup targets with bounded estimate metadata |
| `POST` | `/api/cleanup/run` | `{ targetIds: string[], deep: boolean, confirmed: boolean }` | Start a validated async cleanup job |
| `GET` | `/api/jobs/{id}` | — | Poll async job state |
| `GET` | `/api/jobs/{id}/events` | — | Poll capped live job events |
| `GET` | `/api/tasks/auto-dns` | — | Auto-DNS scheduled task state |
| `POST` | `/api/tasks/auto-dns/create` | `{ confirmed: true }` | Register scheduled task after explicit confirmation |
| `POST` | `/api/tasks/auto-dns/remove` | — | Unregister scheduled task |
| `POST` | `/api/tasks/auto-dns/run` | — | Test-run the task immediately |
| `GET` | `/api/settings` | — | Read user settings |
| `PATCH` | `/api/settings` | Partial settings object | Save user settings |
| `GET` | `/` | — | Serve React SPA (`dist/index.html`) |
| `GET` | `/assets/*` | — | Serve static Vite build assets |

---

## 🌐 Internationalization (i18n)

The project ships with a fully symmetric bilingual translation layer:

| Attribute | Value |
|-----------|-------|
| **Languages** | Vietnamese (`vi`) — default · English (`en`) |
| **Total keys** | 259 per language (in `src/web/src/i18n/translations.ts`) |
| **CLI keys** | ~50 per language (inline dictionary in `NetBoost_Command_Center.ps1`) |
| **CLI flag** | `--lang vi` / `--lang en` (scanned before any other processing) |
| **Web UI toggle** | EN | VI switcher in the top bar; persisted to `settings.local.json` |
| **CLI accent handling** | `Convert-UiText` strips diacritics via Unicode NFD normalization in ASCII mode |

---

## 🛡️ Safety Guarantees

NetBoost is designed around a strict **do-no-harm** philosophy:

- ✅ **Never kills Display Drivers** or GPU processes
- ✅ **Never force-closes user applications** — locked files are silently skipped
- ✅ **Rejects drive roots, profile roots, Windows roots, path escapes, and reparse-point traversal** before file deletion
- ✅ **Never uploads user files, local paths, logs, or settings**
- ✅ **Never installs persistent services** — only one optional Task Scheduler entry after explicit user confirmation
- ✅ **Requires explicit confirmation** for risky targets (Recycle Bin, Component Store, Windows Update downloads, Prefetch, Crash Dumps)
- ✅ **Uses supported/documented Windows actions** for Component Store, Delivery Optimization, and Windows Update download cleanup; never uses DISM `ResetBase`
- ✅ **Restores Windows Update service state** — only originally running `wuauserv`/`BITS` services are stopped and restarted, including after cleanup errors
- ✅ **Never stops unrelated processes on port conflicts** — reports the occupied port instead of force-killing another app
- ✅ **All server runspaces and owned dialog child processes terminate** when the CLI window is closed
- ✅ **Local-first by design** — TCP server is bound exclusively to `127.0.0.1`, inaccessible from LAN or WAN

---

## 🔧 Development

### Frontend (Web UI)

```bash
cd src/web
pnpm install

# Start Vite dev server (hot reload)
pnpm dev

# Type-check and build production bundle → src/web/dist/
pnpm build

# Lint
pnpm lint
```

> **Note:** The Vite dev server runs on `localhost:5173` with CORS pre-configured for the PowerShell backend at `127.0.0.1:47812`. For the full integrated experience, start the CLI backend first.

### Backend (PowerShell)

The backend is a single dot-sourced script requiring no install steps. It uses only built-in .NET classes available in PowerShell 5.1:
- `System.Net.Sockets.TcpListener` — HTTP transport
- `System.Threading.Runspace` — background job isolation
- `System.Collections.ArrayList` (Synchronized) — thread-safe event log queue

To test the backend in isolation:
```powershell
& '.\NetBoost Command Center.exe' --web --port 47812
```

---

## 📋 Requirements

| Component | Minimum Version | Notes |
|-----------|----------------|-------|
| Windows | 10 (1903+) / 11 | Required for `Get-NetTCPConnection`, `Get-NetAdapter`, `Get-NetRoute` |
| Windows PowerShell | **5.1** | Ships with all supported Windows versions; no PowerShell 7 needed |
| .NET Framework | Windows built-in 4.x | Used only by the small EXE launcher; no separate runtime installation needed |
| Node.js + pnpm | Current LTS / pnpm 10+ (optional) | Only required for Web UI development / rebuilding the frontend |
| Administrator rights | Required for DNS ops | Auto-elevated via UAC on first launch |

---

## 📄 License

MIT © 2025 NetBoost Command Center contributors — see [LICENSE](./LICENSE).

---

<div align="center">

**Built with ❤️ for Windows developers who care about a fast, lean machine.**

*CLI-first · Local-only · No telemetry · Open source*

</div>
