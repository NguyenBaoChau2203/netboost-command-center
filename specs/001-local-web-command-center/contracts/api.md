# Local Web API Contract

Base URL: `http://127.0.0.1:{port}`

All mutating requests should include the current session token.

## Common Types

```json
{
  "ok": true,
  "message": "string",
  "adminRequired": false
}
```

## GET /api/health

Returns backend health and local-only state.

```json
{
  "ok": true,
  "appName": "NetBoost Command Center",
  "version": "dev",
  "bindAddress": "127.0.0.1",
  "isAdmin": true,
  "sessionTokenEnabled": true
}
```

## GET /api/dashboard

Returns dashboard state.

```json
{
  "adapter": {
    "name": "Ethernet",
    "status": "Online",
    "interfaceIndex": 12
  },
  "dns": {
    "servers": ["1.1.1.1", "1.0.0.1"],
    "mode": "Manual"
  },
  "autoDnsTask": {
    "name": "NetBoost Auto DNS Optimizer",
    "status": "Active"
  },
  "latency": {
    "googleMs": 12,
    "cloudflareMs": 8,
    "recommended": "Cloudflare"
  },
  "recentLogs": []
}
```

## POST /api/dns/auto

Starts auto DNS selection job.

Response:

```json
{
  "jobId": "dns-20260526-001",
  "status": "queued"
}
```

## POST /api/dns/provider

Body:

```json
{
  "provider": "Google"
}
```

Allowed providers: `Google`, `Cloudflare`.

## POST /api/dns/reset

Resets DNS to DHCP/Auto.

## POST /api/dns/flush

Flushes DNS resolver cache.

## GET /api/cleanup/targets

Returns supported targets only.

```json
[
  {
    "id": "user-temp",
    "label": "Temp nguoi dung",
    "path": "%TEMP%",
    "risk": "low",
    "action": "filesystem",
    "deepOnly": false,
    "safeMinAgeMinutes": 1440,
    "deepMinAgeMinutes": 60,
    "includePatterns": ["*"],
    "excludePathSegments": [],
    "estimatedBytes": 1288490188,
    "estimatedFileCount": 1820,
    "estimateComplete": true,
    "requiresConfirmation": false
  }
]
```

## POST /api/cleanup/run

Body:

```json
{
  "targetIds": ["user-temp", "windows-temp"],
  "deep": false,
  "confirmed": true
}
```

Deep-only targets are rejected unless `deep` is `true`. Risky targets and every Deep job require `confirmed: true`.

Response:

```json
{
  "jobId": "cleanup-20260526-001",
  "status": "queued"
}
```

## GET /api/jobs/{jobId}

Returns job snapshot.

```json
{
  "jobId": "cleanup-20260526-001",
  "status": "running",
  "progress": 65,
  "currentTarget": "NVIDIA DXCache",
  "filesDeleted": 245,
  "dirsDeleted": 18,
  "locked": 3,
  "reclaimedBytes": 641728512
}
```

## GET /api/jobs/{jobId}/events

Streams or returns log events.

```json
{
  "timestamp": "2026-05-26T12:30:00+07:00",
  "level": "DELETE_OK",
  "targetId": "nvidia-dxcache",
  "path": "C:\\Users\\Chau\\AppData\\Local\\NVIDIA\\DXCache\\file.bin",
  "bytes": 49152,
  "message": "Deleted file"
}
```

## GET /api/tasks/auto-dns

Returns scheduled task state.

## POST /api/tasks/auto-dns/create

Creates the Auto DNS scheduled task.

## POST /api/tasks/auto-dns/remove

Removes the Auto DNS scheduled task.

## POST /api/tasks/auto-dns/run

Runs Auto DNS once now.

## GET /api/settings

Returns local settings.

## PATCH /api/settings

Updates UI/log/backend preferences that are safe to persist locally.
