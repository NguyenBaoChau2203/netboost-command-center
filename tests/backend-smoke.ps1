#Requires -Version 5.1
param(
    [int]$Port = 0
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$launcher = Join-Path $repoRoot 'NetBoost_Command_Center.bat'
$expectedVersion = '1.0.1'

if ($Port -le 0) {
    $Port = 47800 + (Get-Random -Minimum 100 -Maximum 800)
}

function Invoke-RawHttpRequest {
    param(
        [string]$Method,
        [string]$Path,
        [string]$Body = '',
        [string]$Token = ''
    )

    $client = [Net.Sockets.TcpClient]::new('127.0.0.1', $Port)
    try {
        $stream = $client.GetStream()
        $bodyBytes = [Text.Encoding]::UTF8.GetBytes($Body)
        $tokenHeader = if ([string]::IsNullOrWhiteSpace($Token)) { '' } else { "X-NetBoost-Token: $Token`r`n" }
        $requestText = "{0} {1} HTTP/1.1`r`nHost: 127.0.0.1:{2}`r`nContent-Type: application/json`r`n{3}Content-Length: {4}`r`nConnection: close`r`n`r`n" -f $Method, $Path, $Port, $tokenHeader, $bodyBytes.Length
        $headerBytes = [Text.Encoding]::ASCII.GetBytes($requestText)
        $stream.Write($headerBytes, 0, $headerBytes.Length)
        if ($bodyBytes.Length -gt 0) {
            $stream.Write($bodyBytes, 0, $bodyBytes.Length)
        }
        $stream.Flush()

        $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::UTF8)
        $response = $reader.ReadToEnd()
        $parts = $response -split "`r`n`r`n", 2
        $statusLine = ($parts[0] -split "`r`n")[0]
        $statusCode = [int](($statusLine -split '\s+')[1])
        $bodyText = if ($parts.Count -gt 1) { $parts[1] } else { '' }
        $json = $null
        if (-not [string]::IsNullOrWhiteSpace($bodyText)) {
            try { $json = $bodyText | ConvertFrom-Json } catch { }
        }

        return [pscustomobject]@{
            StatusCode = $statusCode
            Headers = $parts[0]
            Body = $bodyText
            Json = $json
        }
    } finally {
        $client.Close()
    }
}

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

$scriptPath = Join-Path $repoRoot 'src\powershell\NetBoost_Command_Center.ps1'
$proc = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$scriptPath`"", '--web', '--port', "$Port") -WorkingDirectory $repoRoot -WindowStyle Hidden -PassThru

try {
    $base = "http://127.0.0.1:$Port"
    $healthResponse = $null
    for ($i = 0; $i -lt 40; $i++) {
        Start-Sleep -Milliseconds 250
        if ($proc.HasExited) {
            throw "Backend exited early with code $($proc.ExitCode)."
        }

        try {
            $healthResponse = Invoke-WebRequest -Uri "$base/api/health" -UseBasicParsing -TimeoutSec 1
            break
        } catch {
        }
    }

    Assert-True ($null -ne $healthResponse) 'Backend did not become ready.'

    $health = $healthResponse.Content | ConvertFrom-Json
    # PS < 7.0: Invoke-WebRequest may omit Set-Cookie from the response
    # headers collection, particularly when the cookie has no domain/path.
    # Fall back to a raw TCP request to recover the token when needed.
    $cookie = [string]$healthResponse.Headers['Set-Cookie']
    if ([string]::IsNullOrWhiteSpace($cookie)) {
        $rawHealth = Invoke-RawHttpRequest -Method 'GET' -Path '/api/health'
        $cookieHeader = @($rawHealth.Headers -split "`r`n" | Where-Object { $_ -match '^Set-Cookie:' } | Select-Object -First 1)
        if ($cookieHeader.Count -gt 0) {
            $cookie = ($cookieHeader[0] -split ':', 2)[1].Trim()
        }
    }
    $token = (($cookie -split ';')[0] -split '=')[1]

    Assert-True ($health.ok -eq $true) 'Health endpoint did not return ok=true.'
    Assert-True ($health.version -eq $expectedVersion) "Health endpoint version '$($health.version)' does not match release '$expectedVersion'."
    Assert-True ($health.bindAddress -eq '127.0.0.1') 'Backend is not bound to 127.0.0.1.'
    Assert-True ($health.sessionTokenEnabled -eq $true) 'Session token is not enabled.'
    Assert-True ($token.Length -eq 32) 'Session token cookie was not issued.'
    $authHeaders = @{ 'X-NetBoost-Token' = $token }

    $dashboard = Invoke-RestMethod -Uri "$base/api/dashboard" -Method Get -Headers $authHeaders -TimeoutSec 10
    Assert-True ($null -ne $dashboard.dns) 'Dashboard DNS object missing.'

    $targets = @(Invoke-RestMethod -Uri "$base/api/cleanup/targets" -Method Get -Headers $authHeaders -TimeoutSec 10)
    $expectedIds = @(
        'user-temp',
        'windows-temp',
        'directx-cache',
        'nvidia-cache',
        'steam-cache',
        'crash-dumps',
        'thumbnails',
        'inet-cache',
        'recycle-bin',
        'windows-update',
        'windows-font-cache',
        'windows-prefetch',
        'windows-error-reports'
    )
    $actualIds = @($targets | ForEach-Object { $_.id })
    Assert-True ($actualIds.Count -eq $expectedIds.Count) 'Cleanup target count does not match the constitution.'
    foreach ($id in $expectedIds) {
        Assert-True ($actualIds -contains $id) "Cleanup target missing: $id"
    }

    $staticRoot = Invoke-WebRequest -Uri "$base/" -UseBasicParsing -TimeoutSec 5
    Assert-True ($staticRoot.StatusCode -eq 200) 'Static UI root did not respond with 200.'

    $releaseMismatches = [Collections.Generic.List[string]]::new()
    $webPackage = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'src\web\package.json') | ConvertFrom-Json
    if ($webPackage.version -ne $expectedVersion) {
        $releaseMismatches.Add("Web package version is '$($webPackage.version)'.")
    }

    $scriptMatch = [regex]::Match($staticRoot.Content, '<script[^>]+src="([^"]+\.js)"')
    if (-not $scriptMatch.Success) {
        $releaseMismatches.Add('Static UI root does not reference a JavaScript bundle.')
    } else {
        $bundlePath = $scriptMatch.Groups[1].Value
        $bundle = Invoke-WebRequest -Uri "$base$bundlePath" -UseBasicParsing -TimeoutSec 5
        $stableMarker = "v$expectedVersion (Stable)"
        if (-not $bundle.Content.Contains($stableMarker)) {
            $releaseMismatches.Add("Static UI bundle does not contain '$stableMarker'.")
        }
        if ($bundle.Content.Contains('1.2.0')) {
            $releaseMismatches.Add("Static UI bundle still contains stale release marker '1.2.0'.")
        }
        if ($bundle.Content.Contains('npm-pnpm')) {
            $releaseMismatches.Add("Static UI bundle still exposes the removed npm-to-pnpm feature.")
        }
    }

    Assert-True ($releaseMismatches.Count -eq 0) ("Release version mismatch: {0}" -f ($releaseMismatches -join ' '))

    $missingToken = Invoke-RawHttpRequest -Method 'POST' -Path '/api/dns/flush' -Body '{}'
    Assert-True ($missingToken.StatusCode -eq 401) 'Missing-token mutating request was not rejected with 401.'

    $adminGuardStatus = 'skipped-admin-session'
    if ($health.isAdmin -eq $false) {
        $adminGuard = Invoke-RawHttpRequest -Method 'POST' -Path '/api/dns/flush' -Body '{}' -Token $token
        Assert-True ($adminGuard.StatusCode -eq 403) 'Non-admin privileged request was not rejected with 403.'
        Assert-True ($adminGuard.Json.adminRequired -eq $true) 'Non-admin privileged request did not return adminRequired=true.'
        $adminGuardStatus = 'verified'
    }

    $scanBody = @{
        root = $repoRoot
        maxDepth = 2
        ignore = @('node_modules', '.git', 'dist', 'build')
    } | ConvertTo-Json -Compress
    $removedNpmRoute = Invoke-RawHttpRequest -Method 'POST' -Path '/api/npm/scan' -Body $scanBody -Token $token
    Assert-True ($removedNpmRoute.StatusCode -eq 404) 'Removed npm scan route did not return 404.'

    $helpOutput = (& 'powershell.exe' -NoProfile -ExecutionPolicy Bypass -File $scriptPath '--help' 2>&1 | Out-String)
    Assert-True (-not $helpOutput.Contains('--scan-npm')) 'CLI help still advertises the removed npm scan mode.'

    [pscustomobject]@{
        ok = $true
        version = $health.version
        port = $Port
        isAdmin = $health.isAdmin
        cleanupTargets = $actualIds.Count
        adminGuard = $adminGuardStatus
        npmScanRoute = 'removed'
        npmScanCli = 'removed'
    } | ConvertTo-Json -Depth 6
} finally {
    if ($proc -and -not $proc.HasExited) {
        Stop-Process -Id $proc.Id -ErrorAction SilentlyContinue
    }
}
