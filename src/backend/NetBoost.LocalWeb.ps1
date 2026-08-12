# NetBoost local-only web backend. This file is dot-sourced by the
# PowerShell CLI after core functions are available.

$script:NetBoostVersion = '1.0.1'
$script:WebBindAddress = '127.0.0.1'
$script:WebSessionToken = $null
$script:WebAllowedOrigin = $null
$script:WebMaxJobEvents = 1000
$script:WebDetailedCleanupLogs = $false
$script:WebJobs = [hashtable]::Synchronized(@{})
$script:WebJobEvents = [hashtable]::Synchronized(@{})
$script:WebRecentLogs = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
$script:WebBackgroundTasks = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
$script:WebOwnedChildProcesses = [hashtable]::Synchronized(@{})
$script:WebSettingsCache = $null

function New-NetBoostTimestamp {
    return (Get-Date).ToString('o')
}

function New-NetBoostJobId {
    param([string]$Kind)

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $suffix = ([guid]::NewGuid().ToString('N')).Substring(0, 6)
    return ('{0}-{1}-{2}' -f $Kind, $stamp, $suffix)
}

function Add-WebRecentLog {
    param([object]$Event)

    if ($null -eq $script:WebRecentLogs) {
        $script:WebRecentLogs = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
    }

    [void]$script:WebRecentLogs.Add($Event)
    while ($script:WebRecentLogs.Count -gt 100) {
        $script:WebRecentLogs.RemoveAt(0)
    }
}

function Convert-WebEventPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ''
    }

    if ($script:WebDetailedCleanupLogs) {
        return $Path
    }

    if ($Path -eq 'Recycle Bin') {
        return $Path
    }

    try {
        $leaf = Split-Path -Path $Path -Leaf
        if ([string]::IsNullOrWhiteSpace($leaf)) {
            return '[path hidden]'
        }
        return ('...\{0}' -f $leaf)
    } catch {
        return '[path hidden]'
    }
}

function New-WebJob {
    param([string]$Kind)

    $jobId = New-NetBoostJobId -Kind $Kind
    $job = [hashtable]::Synchronized(@{
        jobId = $jobId
        kind = $Kind
        status = 'queued'
        progress = 0
        currentTarget = 'Queued'
        filesDeleted = 0
        dirsDeleted = 0
        locked = 0
        reclaimedBytes = [int64]0
    })

    $script:WebJobs[$jobId] = $job
    $script:WebJobEvents[$jobId] = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
    return $job
}

function Update-WebJob {
    param(
        [string]$JobId,
        [hashtable]$Values
    )

    if (-not $script:WebJobs.ContainsKey($JobId)) {
        return
    }

    foreach ($key in $Values.Keys) {
        $script:WebJobs[$JobId][$key] = $Values[$key]
    }
}

function Add-WebJobEvent {
    param(
        [string]$JobId,
        [object]$Event
    )

    if ([string]::IsNullOrWhiteSpace($JobId)) {
        Add-WebRecentLog -Event $Event
        return
    }

    if (-not $script:WebJobEvents.ContainsKey($JobId)) {
        $script:WebJobEvents[$JobId] = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
    }

    $events = $script:WebJobEvents[$JobId]
    [void]$events.Add($Event)
    while ($events.Count -gt $script:WebMaxJobEvents) {
        $events.RemoveAt(0)
    }
    Add-WebRecentLog -Event $Event

    if ($script:WebJobs.ContainsKey($JobId)) {
        switch ($Event.level) {
            'DELETE_OK' {
                $script:WebJobs[$JobId]['filesDeleted'] = [int]$script:WebJobs[$JobId]['filesDeleted'] + 1
                if ($Event.PSObject.Properties.Match('bytes').Count -gt 0 -and $null -ne $Event.bytes) {
                    $script:WebJobs[$JobId]['reclaimedBytes'] = [int64]$script:WebJobs[$JobId]['reclaimedBytes'] + [int64]$Event.bytes
                }
            }
            'DELETE_DIR' {
                $script:WebJobs[$JobId]['dirsDeleted'] = [int]$script:WebJobs[$JobId]['dirsDeleted'] + 1
            }
            'SKIP_LOCKED' {
                $script:WebJobs[$JobId]['locked'] = [int]$script:WebJobs[$JobId]['locked'] + 1
            }
        }
    }
}

function Test-CleanupLockedError {
    param([System.Management.Automation.ErrorRecord]$ErrorRecord)

    if ($null -eq $ErrorRecord -or $null -eq $ErrorRecord.Exception) {
        return $false
    }

    $exception = $ErrorRecord.Exception
    if ($exception -is [System.IO.IOException] -or $exception -is [System.UnauthorizedAccessException]) {
        return $true
    }

    $message = $exception.Message
    return ($message -match 'being used by another process|process cannot access|access.*denied|used by|in use|locked')
}

function Write-CleanupEvent {
    param(
        [ValidateSet('INFO', 'DELETE_OK', 'DELETE_DIR', 'SKIP_LOCKED', 'WARN', 'ERROR', 'SUMMARY')]
        [string]$Level,
        [string]$TargetId = '',
        [string]$TargetLabel = '',
        [string]$Path = '',
        [Nullable[int64]]$Bytes = $null,
        [string]$Message = '',
        [string]$JobId = ''
    )

    $event = [ordered]@{
        timestamp = New-NetBoostTimestamp
        level = $Level
        message = $Message
    }

    if (-not [string]::IsNullOrWhiteSpace($TargetId)) {
        $event.targetId = $TargetId
    }
    if (-not [string]::IsNullOrWhiteSpace($TargetLabel)) {
        $event.targetLabel = $TargetLabel
    }
    $displayPath = Convert-WebEventPath -Path $Path
    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        $event.path = $displayPath
    }
    if ($null -ne $Bytes) {
        $event.bytes = [int64]$Bytes
    }

    Add-WebJobEvent -JobId $JobId -Event ([pscustomobject]$event)

    $pathText = ''
    if (-not [string]::IsNullOrWhiteSpace($displayPath)) {
        $pathText = (' path="{0}"' -f $displayPath)
    }
    $sizeText = ''
    if ($null -ne $Bytes) {
        $sizeText = (' bytes={0}' -f $Bytes)
    }
    $targetText = ''
    if (-not [string]::IsNullOrWhiteSpace($TargetId)) {
        $targetText = (' target={0}' -f $TargetId)
    }

    Write-Line ("[{0}] {1}{2}{3}{4} {5}" -f $event.timestamp, $Level, $targetText, $pathText, $sizeText, $Message) Gray
}

function Get-NetBoostRepoRoot {
    $powerShellRoot = Split-Path -Parent $ScriptPath
    return (Resolve-Path -LiteralPath (Join-Path $powerShellRoot '..\..')).Path
}

function Get-NetBoostWebDistRoot {
    return (Join-Path (Get-NetBoostRepoRoot) 'src\web\dist')
}

function Get-NetBoostSettingsPath {
    return (Join-Path (Get-NetBoostRepoRoot) 'src\backend\settings.local.json')
}

function Get-NetBoostDefaultSettings {
    return [ordered]@{
        language = 'vi'
        theme = 'light'
        compactMode = $false
        bindAddress = '127.0.0.1'
        sessionTokenEnabled = $true
        confirmRiskyActions = $true
        detailedCleanupLogs = $false
        autoScrollLogs = $true
        logRetentionDays = 7
        powershellScriptPath = $ScriptPath
        launcherBatPath = (Join-Path (Get-NetBoostRepoRoot) 'NetBoost_Command_Center.bat')
    }
}

function Get-NetBoostSettings {
    if ($null -ne $script:WebSettingsCache) {
        return $script:WebSettingsCache
    }

    $settings = Get-NetBoostDefaultSettings
    $settingsPath = Get-NetBoostSettingsPath
    if (Test-Path -LiteralPath $settingsPath) {
        try {
            $saved = Get-Content -LiteralPath $settingsPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            foreach ($property in $saved.PSObject.Properties) {
                if ($settings.Contains($property.Name)) {
                    $settings[$property.Name] = $property.Value
                }
            }
        } catch {
            Write-Status Warning ("Failed to read local settings: {0}" -f $_.Exception.Message)
        }
    }

    $script:WebSettingsCache = $settings
    return $settings
}

function Save-NetBoostSettings {
    param([hashtable]$Updates)

    $settings = Get-NetBoostSettings
    $allowed = @(
        'language',
        'theme',
        'compactMode',
        'confirmRiskyActions',
        'detailedCleanupLogs',
        'autoScrollLogs',
        'logRetentionDays',
        'powershellScriptPath',
        'launcherBatPath'
    )

    foreach ($key in $Updates.Keys) {
        if ($allowed -contains $key) {
            $settings[$key] = $Updates[$key]
        }
    }

    $settingsPath = Get-NetBoostSettingsPath
    $json = $settings | ConvertTo-Json -Depth 8
    Set-Content -LiteralPath $settingsPath -Value $json -Encoding UTF8
    $script:WebSettingsCache = $settings
    return $settings
}

function New-CleanupTargetDefinition {
    param(
        [string]$Id,
        [string]$Label,
        [string]$DisplayPath,
        [string[]]$Paths,
        [ValidateSet('low', 'medium', 'high')]
        [string]$Risk,
        [bool]$RequiresConfirmation,
        [int]$MinAgeMinutes = 0,
        [string]$Description = ''
    )

    return [pscustomobject]@{
        id = $Id
        label = $Label
        path = $DisplayPath
        paths = @($Paths)
        risk = $Risk
        requiresConfirmation = $RequiresConfirmation
        minAgeMinutes = $MinAgeMinutes
        description = $Description
    }
}

function Get-WebSteamShaderCachePaths {
    $paths = New-Object 'System.Collections.Generic.List[string]'
    $localSteamCache = Join-Path $env:LOCALAPPDATA 'Steam\shadercache\730'
    if (Test-Path -LiteralPath $localSteamCache) {
        [void]$paths.Add((Resolve-Path -LiteralPath $localSteamCache).Path)
    }

    foreach ($libraryPath in @(Get-SteamLibraryPaths)) {
        $shaderPath = Join-Path $libraryPath 'steamapps\shadercache\730'
        if (Test-Path -LiteralPath $shaderPath) {
            [void]$paths.Add((Resolve-Path -LiteralPath $shaderPath).Path)
        }
    }

    return @($paths.ToArray() | Sort-Object -Unique)
}

function Get-CleanupTargetDefinitions {
    $local = $env:LOCALAPPDATA
    return @(
        New-CleanupTargetDefinition -Id 'user-temp' -Label 'Temp nguoi dung' -DisplayPath '%TEMP%' -Paths @($env:TEMP) -Risk 'low' -RequiresConfirmation $false -MinAgeMinutes 60 -Description 'User temporary files'
        New-CleanupTargetDefinition -Id 'windows-temp' -Label 'Windows Temp' -DisplayPath 'C:\Windows\Temp' -Paths @('C:\Windows\Temp') -Risk 'low' -RequiresConfirmation $false -MinAgeMinutes 60 -Description 'Windows temporary files'
        New-CleanupTargetDefinition -Id 'directx-cache' -Label 'DirectX Shader Cache' -DisplayPath (Join-Path $local 'D3DSCache') -Paths @((Join-Path $local 'D3DSCache')) -Risk 'medium' -RequiresConfirmation $false -Description 'DirectX shader cache'
        New-CleanupTargetDefinition -Id 'nvidia-cache' -Label 'NVIDIA DXCache / GLCache / NV_Cache' -DisplayPath (Join-Path $local 'NVIDIA') -Paths @((Join-Path $local 'NVIDIA\DXCache'), (Join-Path $local 'NVIDIA\GLCache'), (Join-Path $local 'NVIDIA\NV_Cache')) -Risk 'medium' -RequiresConfirmation $false -Description 'NVIDIA shader caches'
        New-CleanupTargetDefinition -Id 'steam-cache' -Label 'Steam shader cache' -DisplayPath 'Steam shader cache' -Paths @(Get-WebSteamShaderCachePaths) -Risk 'medium' -RequiresConfirmation $false -Description 'Steam shader cache'
        New-CleanupTargetDefinition -Id 'crash-dumps' -Label 'Crash dumps' -DisplayPath (Join-Path $local 'CrashDumps') -Paths @((Join-Path $local 'CrashDumps')) -Risk 'high' -RequiresConfirmation $true -Description 'Application crash dump files'
        New-CleanupTargetDefinition -Id 'thumbnails' -Label 'Thumbnail cache' -DisplayPath (Join-Path $local 'Microsoft\Windows\Explorer') -Paths @((Join-Path $local 'Microsoft\Windows\Explorer')) -Risk 'low' -RequiresConfirmation $false -Description 'Windows thumbnail cache'
        New-CleanupTargetDefinition -Id 'inet-cache' -Label 'INetCache' -DisplayPath (Join-Path $local 'Microsoft\Windows\INetCache') -Paths @((Join-Path $local 'Microsoft\Windows\INetCache')) -Risk 'low' -RequiresConfirmation $false -Description 'Windows INetCache'
        New-CleanupTargetDefinition -Id 'recycle-bin' -Label 'Recycle Bin' -DisplayPath 'Recycle Bin' -Paths @() -Risk 'high' -RequiresConfirmation $true -Description 'Windows Recycle Bin'
        New-CleanupTargetDefinition -Id 'windows-update' -Label 'Windows Update cache' -DisplayPath 'C:\Windows\SoftwareDistribution\Download' -Paths @('C:\Windows\SoftwareDistribution\Download') -Risk 'medium' -RequiresConfirmation $true -Description 'Windows Update temporary download files'
        New-CleanupTargetDefinition -Id 'windows-font-cache' -Label 'Windows Font Cache' -DisplayPath 'C:\Windows\ServiceProfiles\LocalService\AppData\Local\FontCache' -Paths @('C:\Windows\ServiceProfiles\LocalService\AppData\Local\FontCache') -Risk 'low' -RequiresConfirmation $false -Description 'Windows local font cache files'
        New-CleanupTargetDefinition -Id 'windows-prefetch' -Label 'Windows Prefetch' -DisplayPath 'C:\Windows\Prefetch' -Paths @('C:\Windows\Prefetch') -Risk 'medium' -RequiresConfirmation $true -Description 'Windows application prefetch cache files'
        New-CleanupTargetDefinition -Id 'windows-error-reports' -Label 'Windows Error Reports' -DisplayPath 'C:\ProgramData\Microsoft\Windows\WER' -Paths @('C:\ProgramData\Microsoft\Windows\WER') -Risk 'low' -RequiresConfirmation $false -Description 'Windows error report files'
    )
}

function Get-PathSizeEstimate {
    param(
        [string]$Path,
        [int]$MaxFiles = 500
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        return [int64]0
    }

    try {
        $sum = (Get-ChildItem -LiteralPath $Path -Force -File -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First $MaxFiles |
            Measure-Object -Property Length -Sum).Sum
        if ($null -eq $sum) {
            return [int64]0
        }
        return [int64]$sum
    } catch {
        return [int64]0
    }
}

function Get-WebCleanupTargets {
    $targets = @()
    foreach ($target in Get-CleanupTargetDefinitions) {
        $estimated = [int64]0
        foreach ($path in @($target.paths)) {
            $estimated += [int64](Get-PathSizeEstimate -Path $path)
        }

        $targets += [pscustomobject]@{
            id = $target.id
            label = $target.label
            path = $target.path
            risk = $target.risk
            estimatedBytes = $estimated
            requiresConfirmation = [bool]$target.requiresConfirmation
            description = $target.description
        }
    }

    return @($targets)
}

function Measure-WebLatency {
    param(
        [string]$Target,
        [int]$Count = 2
    )

    try {
        $samples = @()
        $raw = @(Test-Connection -ComputerName $Target -Count $Count -ErrorAction SilentlyContinue)
        foreach ($item in $raw) {
            if ($item.PSObject.Properties.Match('ResponseTime').Count -gt 0) {
                $samples += [double]$item.ResponseTime
            } elseif ($item.PSObject.Properties.Match('Latency').Count -gt 0) {
                $samples += [double]$item.Latency
            }
        }

        if ($samples.Count -eq 0) {
            return $null
        }

        return [math]::Round(($samples | Measure-Object -Average).Average, 1)
    } catch {
        return $null
    }
}

function Get-WebDashboardState {
    $adapterInfo = [ordered]@{
        name = 'No online adapter'
        status = 'Offline'
        interfaceIndex = 0
    }
    $dnsInfo = [ordered]@{
        servers = @('DHCP/Auto')
        mode = 'DHCP'
    }

    $adapter = Get-GameAdapter
    if ($adapter) {
        $adapterInfo = [ordered]@{
            name = $adapter.Name
            status = $adapter.Status.ToString()
            interfaceIndex = [int]$adapter.InterfaceIndex
        }

        $dnsText = Get-CurrentDnsText -InterfaceIndex $adapter.InterfaceIndex
        if ($dnsText -and $dnsText -notmatch 'DHCP') {
            $servers = @($dnsText -split ',\s*' | Where-Object { $_ })
            $dnsInfo = [ordered]@{
                servers = @($servers)
                mode = 'Manual'
            }
        }
    }

    $googleMs = Measure-WebLatency -Target $Providers.Google.Primary
    $cloudflareMs = Measure-WebLatency -Target $Providers.Cloudflare.Primary
    $recommended = 'Unknown'
    if ($null -ne $googleMs -and $null -ne $cloudflareMs) {
        if ($googleMs -lt $cloudflareMs) {
            $recommended = 'Google'
        } elseif ($cloudflareMs -lt $googleMs) {
            $recommended = 'Cloudflare'
        } else {
            $recommended = 'Tie'
        }
    }

    return [ordered]@{
        adapter = $adapterInfo
        dns = $dnsInfo
        autoDnsTask = Get-WebAutoDnsTaskState
        latency = [ordered]@{
            googleMs = $(if ($null -ne $googleMs) { $googleMs } else { -1 })
            cloudflareMs = $(if ($null -ne $cloudflareMs) { $cloudflareMs } else { -1 })
            recommended = $recommended
        }
        recentLogs = @($script:WebRecentLogs.ToArray())
    }
}

function Get-WebAutoDnsTaskState {
    $state = 'Not installed'
    $lastRun = $null
    try {
        $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
        $state = $task.State.ToString()
        try {
            $info = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction Stop
            if ($info.LastRunTime) {
                $lastRun = $info.LastRunTime.ToString('o')
            }
        } catch {
        }
    } catch {
    }

    return [ordered]@{
        name = $TaskName
        status = $state
        trigger = 'At logon'
        delay = '30 seconds'
        lastRun = $lastRun
    }
}

function Convert-RequestBody {
    param($Request)

    if ($null -eq $Request.InputStream -or -not $Request.HasEntityBody) {
        return @{}
    }

    $reader = New-Object System.IO.StreamReader($Request.InputStream, $Request.ContentEncoding)
    try {
        $text = $reader.ReadToEnd()
    } finally {
        $reader.Dispose()
    }

    if ([string]::IsNullOrWhiteSpace($text)) {
        return @{}
    }

    try {
        return ($text | ConvertFrom-Json -ErrorAction Stop)
    } catch {
        return @{}
    }
}

function Test-LocalOrigin {
    param([string]$Origin)

    if ([string]::IsNullOrWhiteSpace($Origin)) {
        return $true
    }

    try {
        if ([string]::IsNullOrWhiteSpace($script:WebAllowedOrigin)) {
            return $false
        }

        $uri = [Uri]$Origin
        $normalizedOrigin = ('{0}://{1}:{2}' -f $uri.Scheme, $uri.Host, $uri.Port)
        return ($normalizedOrigin -eq $script:WebAllowedOrigin)
    } catch {
        return $false
    }
}

function Get-RequestToken {
    param($Request)

    $headerToken = $Request.Headers['X-NetBoost-Token']
    if (-not [string]::IsNullOrWhiteSpace($headerToken)) {
        return $headerToken
    }

    $auth = $Request.Headers['Authorization']
    if ($auth -match '^Bearer\s+(.+)$') {
        return $matches[1]
    }

    $cookieHeader = $Request.Headers['Cookie']
    if ($cookieHeader) {
        foreach ($part in $cookieHeader -split ';') {
            $pieces = $part.Trim() -split '=', 2
            if ($pieces.Count -eq 2 -and $pieces[0] -eq 'netboost_session') {
                return $pieces[1]
            }
        }
    }

    return $null
}

function Test-WebSessionToken {
    param($Request)

    $token = Get-RequestToken -Request $Request
    return (-not [string]::IsNullOrWhiteSpace($token) -and $token -eq $script:WebSessionToken)
}

function Add-WebResponseHeader {
    param(
        $Response,
        [string]$Name,
        [string]$Value
    )

    if ($Response.PSObject.Methods.Match('AppendHeader').Count -gt 0) {
        $Response.AppendHeader($Name, $Value)
    } else {
        $Response.Headers[$Name] = $Value
    }
}

function Set-CommonWebHeaders {
    param($Context)

    $response = $Context.Response
    $origin = $Context.Request.Headers['Origin']
    if (Test-LocalOrigin -Origin $origin) {
        if (-not [string]::IsNullOrWhiteSpace($origin)) {
            Add-WebResponseHeader -Response $response -Name 'Access-Control-Allow-Origin' -Value $origin
            Add-WebResponseHeader -Response $response -Name 'Vary' -Value 'Origin'
        }
        Add-WebResponseHeader -Response $response -Name 'Access-Control-Allow-Credentials' -Value 'true'
        Add-WebResponseHeader -Response $response -Name 'Access-Control-Allow-Headers' -Value 'Content-Type, X-NetBoost-Token, Authorization'
        Add-WebResponseHeader -Response $response -Name 'Access-Control-Allow-Methods' -Value 'GET, POST, PATCH, OPTIONS'
    }

    Add-WebResponseHeader -Response $response -Name 'Cache-Control' -Value 'no-store'
    if (-not [string]::IsNullOrWhiteSpace($script:WebSessionToken)) {
        Add-WebResponseHeader -Response $response -Name 'Set-Cookie' -Value ('netboost_session={0}; Path=/; SameSite=Strict; HttpOnly' -f $script:WebSessionToken)
    }
}

function Send-WebJson {
    param(
        $Context,
        [object]$Data,
        [int]$StatusCode = 200
    )

    Set-CommonWebHeaders -Context $Context
    $json = ConvertTo-Json -InputObject $Data -Depth 16
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $bytes = $utf8NoBom.GetBytes($json)
    $Context.Response.StatusCode = $StatusCode
    $Context.Response.ContentType = 'application/json; charset=utf-8'
    $Context.Response.ContentLength64 = $bytes.Length
    $Context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $Context.Response.Close()
}

function Send-WebText {
    param(
        $Context,
        [string]$Text,
        [int]$StatusCode = 200,
        [string]$ContentType = 'text/plain; charset=utf-8'
    )

    Set-CommonWebHeaders -Context $Context
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $bytes = $utf8NoBom.GetBytes($Text)
    $Context.Response.StatusCode = $StatusCode
    $Context.Response.ContentType = $ContentType
    $Context.Response.ContentLength64 = $bytes.Length
    $Context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $Context.Response.Close()
}

function Send-ApiError {
    param(
        $Context,
        [string]$Message,
        [int]$StatusCode = 400,
        [bool]$AdminRequired = $false
    )

    Send-WebJson -Context $Context -StatusCode $StatusCode -Data ([ordered]@{
        ok = $false
        message = $Message
        adminRequired = $AdminRequired
    })
}

function Test-MutatingRequestAllowed {
    param($Context)

    $origin = $Context.Request.Headers['Origin']
    if (-not (Test-LocalOrigin -Origin $origin)) {
        Send-ApiError -Context $Context -Message 'Unsafe origin rejected.' -StatusCode 403
        return $false
    }

    if (-not (Test-WebSessionToken -Request $Context.Request)) {
        Send-ApiError -Context $Context -Message 'Missing or invalid session token.' -StatusCode 401
        return $false
    }

    return $true
}

function Test-AuthenticatedApiRequest {
    param($Context)

    $origin = $Context.Request.Headers['Origin']
    if (-not (Test-LocalOrigin -Origin $origin)) {
        Send-ApiError -Context $Context -Message 'Unsafe origin rejected.' -StatusCode 403
        return $false
    }

    if (-not (Test-WebSessionToken -Request $Context.Request)) {
        Send-ApiError -Context $Context -Message 'Missing or invalid session token.' -StatusCode 401
        return $false
    }

    return $true
}

function Test-AdminForWebAction {
    param($Context)

    if (Is-Admin) {
        return $true
    }

    Send-ApiError -Context $Context -Message 'Administrator privileges are required for this action. Restart the launcher with standard Windows UAC elevation.' -StatusCode 403 -AdminRequired $true
    return $false
}

function Get-WebBackgroundFunctionBootstrap {
    $functionNames = @(
        'Convert-UiText',
        'Write-Line',
        'Get-UiIcon',
        'Write-UiHeader',
        'Write-Status',
        'Is-Admin',
        'Ensure-Admin',
        'Get-GameAdapter',
        'Get-PathSize',
        'Get-SteamInstallPaths',
        'Get-SteamLibraryPaths',
        'Remove-FolderContents',
        'New-NetBoostTimestamp',
        'Add-WebRecentLog',
        'Convert-WebEventPath',
        'Update-WebJob',
        'Add-WebJobEvent',
        'Test-CleanupLockedError',
        'Write-CleanupEvent',
        'New-CleanupTargetDefinition',
        'Get-WebSteamShaderCachePaths',
        'Get-CleanupTargetDefinitions',
        'Measure-WebLatency',
        'Invoke-WebDnsProvider',
        'Invoke-WebDnsJobWorker',
        'Invoke-WebCleanupJobWorker',
        'Find-NpmProjectsForWeb',
        'Invoke-WebNpmScanJobWorker',
        'Invoke-WebTaskActionWorker'
    )

    $parts = New-Object 'System.Collections.Generic.List[string]'
    foreach ($name in $functionNames) {
        $command = Get-Command -Name $name -CommandType Function -ErrorAction SilentlyContinue
        if (-not $command) {
            throw ("Background worker bootstrap missing function: {0}" -f $name)
        }

        [void]$parts.Add(("function {0} {{`r`n{1}`r`n}}" -f $name, $command.Definition))
    }

    return ($parts -join "`r`n`r`n")
}

function Start-WebBackgroundTask {
    param(
        [string]$JobId,
        [scriptblock]$ScriptBlock,
        [hashtable]$Payload
    )

    $shared = [hashtable]::Synchronized(@{
        WebJobs = $script:WebJobs
        WebJobEvents = $script:WebJobEvents
        WebRecentLogs = $script:WebRecentLogs
        WebOwnedChildProcesses = $script:WebOwnedChildProcesses
        WebMaxJobEvents = $script:WebMaxJobEvents
        WebDetailedCleanupLogs = [bool](Get-NetBoostSettings).detailedCleanupLogs
        JobId = $JobId
        ScriptBlockText = $ScriptBlock.ToString()
        Payload = $Payload
        Providers = $Providers
        T = $T
        TaskName = $TaskName
        ScriptPath = $ScriptPath
        Language = $Language
        UseFancyUi = $UseFancyUi
        UseAsciiUi = $UseAsciiUi
    })

    $bootstrap = Get-WebBackgroundFunctionBootstrap
    $runner = @"
param(`$Shared)

`$ErrorActionPreference = 'Continue'
`$script:WebJobs = `$Shared.WebJobs
`$script:WebJobEvents = `$Shared.WebJobEvents
`$script:WebRecentLogs = `$Shared.WebRecentLogs
`$script:WebOwnedChildProcesses = `$Shared.WebOwnedChildProcesses
`$script:WebMaxJobEvents = [int]`$Shared.WebMaxJobEvents
`$script:WebDetailedCleanupLogs = [bool]`$Shared.WebDetailedCleanupLogs
`$Providers = `$Shared.Providers
`$T = `$Shared.T
`$TaskName = `$Shared.TaskName
`$ScriptPath = `$Shared.ScriptPath
`$Language = `$Shared.Language
`$UseFancyUi = `$Shared.UseFancyUi
`$UseAsciiUi = `$Shared.UseAsciiUi

$bootstrap

try {
    `$worker = [scriptblock]::Create(`$Shared.ScriptBlockText)
    & `$worker `$Shared.Payload
} catch {
    if (`$Shared.JobId -and `$script:WebJobs.ContainsKey(`$Shared.JobId)) {
        `$event = [pscustomobject]@{
            timestamp = New-NetBoostTimestamp
            level = 'ERROR'
            message = `$_.Exception.Message
        }
        Add-WebJobEvent -JobId `$Shared.JobId -Event `$event
        Update-WebJob -JobId `$Shared.JobId -Values @{ status = 'failed'; progress = 100; currentTarget = 'Failed' }
    }
}
"@

    $ps = [powershell]::Create()
    [void]$ps.AddScript($runner)
    [void]$ps.AddArgument($shared)
    $handle = $ps.BeginInvoke()

    [void]$script:WebBackgroundTasks.Add([pscustomobject]@{
        PowerShell = $ps
        Handle = $handle
        JobId = $JobId
        StartedAt = Get-Date
    })
}

function Clear-WebCompletedBackgroundTasks {
    if ($null -eq $script:WebBackgroundTasks) {
        return
    }

    for ($i = $script:WebBackgroundTasks.Count - 1; $i -ge 0; $i--) {
        $task = $script:WebBackgroundTasks[$i]
        if (-not $task.Handle.IsCompleted) {
            continue
        }

        try {
            [void]$task.PowerShell.EndInvoke($task.Handle)
            if ($task.PowerShell.Streams.Error.Count -gt 0 -and $task.JobId) {
                foreach ($errorRecord in $task.PowerShell.Streams.Error) {
                    Add-WebJobEvent -JobId $task.JobId -Event ([pscustomobject]@{
                        timestamp = New-NetBoostTimestamp
                        level = 'ERROR'
                        message = $errorRecord.Exception.Message
                    })
                }
            }
        } catch {
            if ($task.JobId) {
                Add-WebJobEvent -JobId $task.JobId -Event ([pscustomobject]@{
                    timestamp = New-NetBoostTimestamp
                    level = 'ERROR'
                    message = $_.Exception.Message
                })
                Update-WebJob -JobId $task.JobId -Values @{ status = 'failed'; progress = 100; currentTarget = 'Failed' }
            }
        } finally {
            $task.PowerShell.Dispose()
            $script:WebBackgroundTasks.RemoveAt($i)
        }
    }
}

function Stop-WebOwnedChildProcesses {
    if ($null -eq $script:WebOwnedChildProcesses) {
        return
    }

    foreach ($childPid in @($script:WebOwnedChildProcesses.Keys)) {
        try {
            $pidValue = [int]$childPid
            $process = Get-Process -Id $pidValue -ErrorAction SilentlyContinue
            if ($process -and $process.ProcessName -in @('powershell', 'pwsh')) {
                Stop-Process -Id $pidValue -Force -ErrorAction SilentlyContinue
            }
        } catch {
        } finally {
            [void]$script:WebOwnedChildProcesses.Remove($childPid)
        }
    }
}

function Stop-WebBackgroundTasks {
    if ($null -eq $script:WebBackgroundTasks) {
        return
    }

    Stop-WebOwnedChildProcesses

    for ($i = $script:WebBackgroundTasks.Count - 1; $i -ge 0; $i--) {
        $task = $script:WebBackgroundTasks[$i]
        try {
            if ($task.JobId -and $script:WebJobs.ContainsKey($task.JobId)) {
                Update-WebJob -JobId $task.JobId -Values @{
                    status = 'failed'
                    progress = 100
                    currentTarget = 'Cancelled because the local backend stopped'
                }
            }

            if (-not $task.Handle.IsCompleted) {
                $task.PowerShell.Stop()
            } else {
                [void]$task.PowerShell.EndInvoke($task.Handle)
            }
        } catch {
        } finally {
            try { $task.PowerShell.Dispose() } catch { }
            $script:WebBackgroundTasks.RemoveAt($i)
        }
    }
}

function Invoke-WebDnsProvider {
    param(
        [string]$ProviderName,
        [string]$JobId
    )

    $adapter = Get-GameAdapter
    if (-not $adapter) {
        throw $T.NoAdapter
    }

    $provider = $Providers[$ProviderName]
    $servers = @($provider.Primary, $provider.Secondary)
    Add-WebJobEvent -JobId $JobId -Event ([pscustomobject]@{
        timestamp = New-NetBoostTimestamp
        level = 'INFO'
        message = ('Applying {0} DNS to {1}' -f $ProviderName, $adapter.Name)
    })

    Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses $servers -ErrorAction Stop
    Clear-DnsClientCache -ErrorAction SilentlyContinue

    Add-WebJobEvent -JobId $JobId -Event ([pscustomobject]@{
        timestamp = New-NetBoostTimestamp
        level = 'SUMMARY'
        message = ('DNS updated to {0}: {1}' -f $ProviderName, ($servers -join ', '))
    })
}

function Invoke-WebDnsJobWorker {
    param([hashtable]$Payload)

    $jobId = [string]$Payload.JobId
    $Action = [string]$Payload.Action
    $ProviderName = [string]$Payload.ProviderName
    Update-WebJob -JobId $jobId -Values @{ status = 'running'; progress = 5; currentTarget = $Action }

    try {
        switch ($Action) {
            'auto' {
                Add-WebJobEvent -JobId $jobId -Event ([pscustomobject]@{
                    timestamp = New-NetBoostTimestamp
                    level = 'INFO'
                    message = 'Measuring Google and Cloudflare DNS latency.'
                })
                $google = Measure-WebLatency -Target $Providers.Google.Primary -Count 4
                $cloudflare = Measure-WebLatency -Target $Providers.Cloudflare.Primary -Count 4
                Update-WebJob -JobId $jobId -Values @{ progress = 50 }

                if ($null -eq $google -and $null -eq $cloudflare) {
                    throw 'Both DNS providers timed out. DNS was not modified.'
                }

                $winner = 'Cloudflare'
                if ($null -ne $google -and ($null -eq $cloudflare -or $google -lt $cloudflare)) {
                    $winner = 'Google'
                }

                Add-WebJobEvent -JobId $jobId -Event ([pscustomobject]@{
                    timestamp = New-NetBoostTimestamp
                    level = 'INFO'
                    message = ('Recommended provider: {0} (Google={1}ms, Cloudflare={2}ms)' -f $winner, $google, $cloudflare)
                })
                Invoke-WebDnsProvider -ProviderName $winner -JobId $jobId
            }
            'provider' {
                if ($ProviderName -ne 'Google' -and $ProviderName -ne 'Cloudflare') {
                    throw 'Unsupported DNS provider.'
                }
                Invoke-WebDnsProvider -ProviderName $ProviderName -JobId $jobId
            }
            'reset' {
                $adapter = Get-GameAdapter
                if (-not $adapter) {
                    throw $T.NoAdapter
                }
                Add-WebJobEvent -JobId $jobId -Event ([pscustomobject]@{
                    timestamp = New-NetBoostTimestamp
                    level = 'INFO'
                    message = ('Resetting DNS to DHCP/Auto for {0}' -f $adapter.Name)
                })
                Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ResetServerAddresses -ErrorAction Stop
                Clear-DnsClientCache -ErrorAction SilentlyContinue
            }
            'flush' {
                Add-WebJobEvent -JobId $jobId -Event ([pscustomobject]@{
                    timestamp = New-NetBoostTimestamp
                    level = 'INFO'
                    message = 'Flushing DNS resolver cache.'
                })
                Clear-DnsClientCache -ErrorAction SilentlyContinue
                ipconfig /flushdns | Out-Null
            }
        }

        Update-WebJob -JobId $jobId -Values @{ status = 'completed'; progress = 100; currentTarget = 'Completed' }
    } catch {
        Add-WebJobEvent -JobId $jobId -Event ([pscustomobject]@{
            timestamp = New-NetBoostTimestamp
            level = 'ERROR'
            message = $_.Exception.Message
        })
        Update-WebJob -JobId $jobId -Values @{ status = 'failed'; progress = 100; currentTarget = 'Failed' }
    }

}

function Start-WebDnsJob {
    param(
        [ValidateSet('auto', 'provider', 'reset', 'flush')]
        [string]$Action,
        [string]$ProviderName = ''
    )

    $job = New-WebJob -Kind 'dns'
    $payload = @{
        JobId = $job.jobId
        Action = $Action
        ProviderName = $ProviderName
    }
    Start-WebBackgroundTask -JobId $job.jobId -Payload $payload -ScriptBlock {
        param([hashtable]$Payload)
        Invoke-WebDnsJobWorker -Payload $Payload
    }
    return $job
}

function Invoke-WebCleanupJobWorker {
    param([hashtable]$Payload)

    $jobId = [string]$Payload.JobId
    $TargetIds = @($Payload.TargetIds | ForEach-Object { [string]$_ })
    $Deep = [bool]$Payload.Deep
    $definitions = @(Get-CleanupTargetDefinitions)
    $selected = @($definitions | Where-Object { $TargetIds -contains $_.id })

    try {
        Update-WebJob -JobId $jobId -Values @{ status = 'running'; progress = 0; currentTarget = 'Starting cleanup' }
        Write-CleanupEvent -Level INFO -TargetId 'cleanup' -TargetLabel 'Cleanup' -Message ('Cleanup job started. deep={0}; targets={1}' -f $Deep, ($TargetIds -join ',')) -JobId $jobId

        $index = 0
        foreach ($target in $selected) {
            $index++
            Update-WebJob -JobId $jobId -Values @{
                currentTarget = $target.label
                progress = [math]::Max(1, [math]::Round((($index - 1) / $selected.Count) * 100))
            }

            if ($target.id -eq 'recycle-bin') {
                Write-CleanupEvent -Level INFO -TargetId $target.id -TargetLabel $target.label -Path 'Recycle Bin' -Message 'Clearing Recycle Bin' -JobId $jobId
                try {
                    Clear-RecycleBin -Force -ErrorAction Stop
                    Write-CleanupEvent -Level SUMMARY -TargetId $target.id -TargetLabel $target.label -Path 'Recycle Bin' -Message 'Recycle Bin cleanup completed' -JobId $jobId
                } catch {
                    Write-CleanupEvent -Level WARN -TargetId $target.id -TargetLabel $target.label -Path 'Recycle Bin' -Message $_.Exception.Message -JobId $jobId
                }
            } else {
                foreach ($path in @($target.paths)) {
                    Remove-FolderContents -Path $path -Label $target.label -MinAgeMinutes $target.minAgeMinutes -TargetId $target.id -JobId $jobId
                }
            }
        }

        Write-CleanupEvent -Level SUMMARY -TargetId 'cleanup' -TargetLabel 'Cleanup' -Message 'Cleanup job completed' -JobId $jobId
        Update-WebJob -JobId $jobId -Values @{ status = 'completed'; progress = 100; currentTarget = 'Completed' }
    } catch {
        Write-CleanupEvent -Level ERROR -TargetId 'cleanup' -TargetLabel 'Cleanup' -Message $_.Exception.Message -JobId $jobId
        Update-WebJob -JobId $jobId -Values @{ status = 'failed'; progress = 100; currentTarget = 'Failed' }
    }
}

function Start-WebCleanupJob {
    param(
        [string[]]$TargetIds,
        [bool]$Deep,
        [bool]$Confirmed
    )

    $definitions = @(Get-CleanupTargetDefinitions)
    $selected = @($definitions | Where-Object { $TargetIds -contains $_.id })
    if ($selected.Count -eq 0) {
        throw 'No supported cleanup targets selected.'
    }

    $requiresConfirm = $Deep -or @($selected | Where-Object { $_.requiresConfirmation }).Count -gt 0
    if ($requiresConfirm -and -not $Confirmed) {
        throw 'Confirmation is required for selected cleanup targets.'
    }

    $job = New-WebJob -Kind 'cleanup'
    $payload = @{
        JobId = $job.jobId
        TargetIds = @($TargetIds)
        Deep = $Deep
    }
    Start-WebBackgroundTask -JobId $job.jobId -Payload $payload -ScriptBlock {
        param([hashtable]$Payload)
        Invoke-WebCleanupJobWorker -Payload $Payload
    }
    return $job
}

function Find-NpmProjectsForWeb {
    param(
        [string]$Root,
        [int]$MaxDepth = 6,
        [string[]]$Ignore = @('node_modules', '.git', 'dist', 'build')
    )

    $resolved = (Resolve-Path -LiteralPath $Root -ErrorAction Stop).Path
    $ignoreSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($name in @($Ignore + @('.hg', '.svn', '.pnpm', '.next', 'out', 'coverage', '.cache'))) {
        if (-not [string]::IsNullOrWhiteSpace($name)) {
            [void]$ignoreSet.Add($name)
        }
    }

    $queue = New-Object 'System.Collections.Generic.Queue[object]'
    $queue.Enqueue([pscustomobject]@{ Path = $resolved; Depth = 0 })
    $projects = New-Object 'System.Collections.Generic.List[object]'
    $scanned = 0
    $maxDirs = 50000

    while ($queue.Count -gt 0 -and $scanned -lt $maxDirs) {
        $item = $queue.Dequeue()
        $dir = $item.Path
        $depth = [int]$item.Depth
        $scanned++

        $children = @(Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue)
        $childNames = [System.Collections.Generic.HashSet[string]]::new(
            [string[]]($children | ForEach-Object { $_.Name }),
            [StringComparer]::OrdinalIgnoreCase
        )

        $hasPackageJson = $childNames.Contains('package.json')
        $hasPackageLock = $childNames.Contains('package-lock.json')
        $hasShrinkwrap = $childNames.Contains('npm-shrinkwrap.json')
        $hasPnpmLock = $childNames.Contains('pnpm-lock.yaml')
        $hasYarnLock = $childNames.Contains('yarn.lock')
        $hasNodeModules = $childNames.Contains('node_modules')

        if ($hasPackageJson -or $hasPackageLock -or $hasShrinkwrap -or $hasNodeModules) {
            $lockfile = 'none'
            if ($hasPackageLock) { $lockfile = 'package-lock.json' }
            elseif ($hasShrinkwrap) { $lockfile = 'npm-shrinkwrap.json' }
            elseif ($hasPnpmLock) { $lockfile = 'pnpm-lock.yaml' }
            elseif ($hasYarnLock) { $lockfile = 'yarn.lock' }

            $nodeModulesSize = [int64]0
            $nodeModulesPath = Join-Path $dir 'node_modules'
            if ($hasNodeModules) {
                $size = Get-PathSize -Path $nodeModulesPath
                if ($null -ne $size) {
                    $nodeModulesSize = [int64]$size
                }
            }

            $status = if ($hasPnpmLock) { 'completed' } else { 'ready' }
            $recommendation = if ($hasPnpmLock) { 'Already uses pnpm lockfile' } else { 'Report-only: review pnpm import and pnpm install manually' }
            $suggestions = if ($hasPnpmLock) { @() } else { @('pnpm import', 'pnpm install', 'npm run build') }

            [void]$projects.Add([pscustomobject]@{
                path = $dir
                lockfile = $lockfile
                nodeModulesSize = $nodeModulesSize
                recommendation = $recommendation
                status = $status
                suggestions = $suggestions
            })
        }

        if ($depth -ge $MaxDepth) {
            continue
        }

        foreach ($child in $children) {
            if (-not $child.PSIsContainer) {
                continue
            }
            if ($ignoreSet.Contains($child.Name)) {
                continue
            }
            if (($child.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                continue
            }
            $queue.Enqueue([pscustomobject]@{ Path = $child.FullName; Depth = ($depth + 1) })
        }
    }

    return [pscustomobject]@{
        root = $resolved
        scanned = $scanned
        hitLimit = ($scanned -ge $maxDirs)
        projects = @($projects.ToArray())
    }
}

function Invoke-WebNpmScanJobWorker {
    param([hashtable]$Payload)

    $jobId = [string]$Payload.JobId
    $Root = [string]$Payload.Root
    $MaxDepth = [int]$Payload.MaxDepth
    $Ignore = @($Payload.Ignore | ForEach-Object { [string]$_ })
    Update-WebJob -JobId $jobId -Values @{ status = 'running'; progress = 10; currentTarget = 'Scanning npm projects' }
    Add-WebJobEvent -JobId $jobId -Event ([pscustomobject]@{
        timestamp = New-NetBoostTimestamp
        level = 'INFO'
        message = ('Report-only npm -> pnpm scan started: {0}' -f $Root)
    })

    try {
        $scan = Find-NpmProjectsForWeb -Root $Root -MaxDepth $MaxDepth -Ignore $Ignore
        $projects = @($scan.projects)
        $totalNodeModules = [int64]0
        foreach ($project in $projects) {
            $totalNodeModules += [int64]$project.nodeModulesSize
            Add-WebJobEvent -JobId $jobId -Event ([pscustomobject]@{
                timestamp = New-NetBoostTimestamp
                level = 'FOUND'
                path = $project.path
                message = ('Found Node project: {0} ({1})' -f $project.path, $project.lockfile)
            })
        }

        $packageLockCount = @($projects | Where-Object { $_.lockfile -eq 'package-lock.json' -or $_.lockfile -eq 'npm-shrinkwrap.json' }).Count
        $expectedSavings = [int64]([math]::Round($totalNodeModules * 0.7))

        Update-WebJob -JobId $jobId -Values @{
            status = 'completed'
            progress = 100
            currentTarget = 'Completed'
            projectsFound = $projects.Count
            totalNodeModulesBytes = $totalNodeModules
            packageLockCount = $packageLockCount
            expectedSavingsBytes = $expectedSavings
            projects = @($projects)
            scannedFolders = $scan.scanned
            hitLimit = $scan.hitLimit
        }

        Add-WebJobEvent -JobId $jobId -Event ([pscustomobject]@{
            timestamp = New-NetBoostTimestamp
            level = 'SUMMARY'
            message = ('npm scan completed. projects={0}; reportOnly=true' -f $projects.Count)
        })
    } catch {
        Add-WebJobEvent -JobId $jobId -Event ([pscustomobject]@{
            timestamp = New-NetBoostTimestamp
            level = 'ERROR'
            message = $_.Exception.Message
        })
        Update-WebJob -JobId $jobId -Values @{ status = 'failed'; progress = 100; currentTarget = 'Failed' }
    }
}

function Start-WebNpmScanJob {
    param(
        [string]$Root,
        [int]$MaxDepth = 6,
        [string[]]$Ignore = @('node_modules', '.git', 'dist', 'build')
    )

    $job = New-WebJob -Kind 'npm-scan'
    $payload = @{
        JobId = $job.jobId
        Root = $Root
        MaxDepth = $MaxDepth
        Ignore = @($Ignore)
    }
    Start-WebBackgroundTask -JobId $job.jobId -Payload $payload -ScriptBlock {
        param([hashtable]$Payload)
        Invoke-WebNpmScanJobWorker -Payload $Payload
    }
    return $job
}

function Invoke-WebTaskActionWorker {
    param([hashtable]$Payload)

    $jobId = [string]$Payload.JobId
    $Action = [string]$Payload.Action
    $Confirmed = [bool]$Payload.Confirmed
    Update-WebJob -JobId $jobId -Values @{ status = 'running'; progress = 10; currentTarget = $Action }

    try {
        switch ($Action) {
            'create' {
                if (-not $Confirmed) {
                    throw 'Explicit user confirmation is required before creating a persistent Windows logon task.'
                }
                $taskScriptPath = $ScriptPath.Replace('"', '\"')
                $langParam = if ($Language -eq 'EN') { ' -Lang EN' } else { '' }
                $actionObj = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -ExecutionPolicy Bypass -File "{0}" -AutoDns{1}' -f $taskScriptPath, $langParam)
                $trigger = New-ScheduledTaskTrigger -AtLogOn
                $trigger.Delay = 'PT30S'
                $userId = [Security.Principal.WindowsIdentity]::GetCurrent().Name
                $principal = New-ScheduledTaskPrincipal -UserId $userId -RunLevel Highest
                $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
                Register-ScheduledTask -TaskName $TaskName -Action $actionObj -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
            }
            'remove' {
                $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
                if ($task) {
                    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
                }
            }
            'run' {
                Start-ScheduledTask -TaskName $TaskName -ErrorAction Stop
            }
        }

        Add-WebJobEvent -JobId $jobId -Event ([pscustomobject]@{
            timestamp = New-NetBoostTimestamp
            level = 'SUMMARY'
            message = ('Scheduled task action completed: {0}' -f $Action)
        })
        Update-WebJob -JobId $jobId -Values @{ status = 'completed'; progress = 100; currentTarget = 'Completed' }
    } catch {
        Add-WebJobEvent -JobId $jobId -Event ([pscustomobject]@{
            timestamp = New-NetBoostTimestamp
            level = 'ERROR'
            message = $_.Exception.Message
        })
        Update-WebJob -JobId $jobId -Values @{ status = 'failed'; progress = 100; currentTarget = 'Failed' }
    }
}

function Invoke-WebTaskAction {
    param(
        [ValidateSet('create', 'remove', 'run')] [string]$Action,
        [bool]$Confirmed = $false
    )

    $job = New-WebJob -Kind 'task'
    $payload = @{
        JobId = $job.jobId
        Action = $Action
        Confirmed = $Confirmed
    }
    Start-WebBackgroundTask -JobId $job.jobId -Payload $payload -ScriptBlock {
        param([hashtable]$Payload)
        Invoke-WebTaskActionWorker -Payload $Payload
    }
    return $job
}

function Start-WebDialogJob {
    param(
        [string]$Type,
        [string]$Filter = ''
    )

    $job = New-WebJob -Kind 'dialog'
    $jobId = $job.jobId

    $payload = @{
        Type = $Type
        Filter = $Filter
    }

    $worker = {
        param($Payload)

        $type = $Payload.Type
        $filter = $Payload.Filter

        Update-WebJob -JobId $Shared.JobId -Values @{ status = 'running'; currentTarget = 'Đang hiển thị hộp thoại...' }

        $cmdScript = if ($type -eq 'file') {
            $fFilter = if ($filter -eq 'ps1') {
                "PowerShell Scripts (*.ps1)|*.ps1|All Files (*.*)|*.*"
            } elseif ($filter -eq 'bat') {
                "Batch Files (*.bat)|*.bat|All files (*.*)|*.*"
            } else {
                "All Files (*.*)|*.*"
            }
            "[void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms'); `$d = New-Object System.Windows.Forms.OpenFileDialog; `$d.Title = 'Chọn file NetBoost'; `$d.Filter = '{0}'; `$d.InitialDirectory = [System.IO.Directory]::GetCurrentDirectory(); if (`$d.ShowDialog() -eq 'OK') {{ Write-Output `$d.FileName }}" -f $fFilter
        } else {
            "[void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms'); `$d = New-Object System.Windows.Forms.FolderBrowserDialog; `$d.Description = 'Chọn thư mục'; if (`$d.ShowDialog() -eq 'OK') {{ Write-Output `$d.SelectedPath }}"
        }

        # Run powershell.exe in hidden window style to capture standard output cleanly!
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "& {' + $cmdScript.Replace('"', '\"') + '}"'
        $psi.RedirectStandardOutput = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true

        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        [void]$proc.Start()
        if ($Shared.WebOwnedChildProcesses) {
            $script:WebOwnedChildProcesses[[string]$proc.Id] = [pscustomobject]@{
                pid = $proc.Id
                kind = 'dialog'
                startedAt = New-NetBoostTimestamp
            }
        }

        try {
            $stdout = $proc.StandardOutput.ReadToEnd()
            $proc.WaitForExit()
        } finally {
            if ($Shared.WebOwnedChildProcesses) {
                [void]$script:WebOwnedChildProcesses.Remove([string]$proc.Id)
            }
            try {
                if (-not $proc.HasExited) {
                    $proc.Kill()
                }
            } catch {
            }
            $proc.Dispose()
        }

        $selectedPath = $stdout.Trim()
        if ([string]::IsNullOrWhiteSpace($selectedPath)) {
            $selectedPath = $null
        }

        Update-WebJob -JobId $Shared.JobId -Values @{
            status = 'completed'
            progress = 100
            currentTarget = 'Hoàn tất'
            selected = $selectedPath
        }
    }

    Start-WebBackgroundTask -JobId $jobId -ScriptBlock $worker -Payload $payload
    return $job
}

function Get-WebContentType {
    param([string]$Path)

    switch ([IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        '.html' { return 'text/html; charset=utf-8' }
        '.js' { return 'text/javascript; charset=utf-8' }
        '.css' { return 'text/css; charset=utf-8' }
        '.svg' { return 'image/svg+xml' }
        '.png' { return 'image/png' }
        '.jpg' { return 'image/jpeg' }
        '.jpeg' { return 'image/jpeg' }
        '.ico' { return 'image/x-icon' }
        default { return 'application/octet-stream' }
    }
}

function Send-WebStaticFile {
    param($Context)

    $distRoot = Get-NetBoostWebDistRoot
    if (-not (Test-Path -LiteralPath $distRoot)) {
        $html = @"
<!doctype html>
<html>
<head><meta charset="utf-8"><title>NetBoost Command Center</title></head>
<body>
<h1>NetBoost Command Center backend is running</h1>
<p>Build frontend assets into <code>src/web/dist</code> to serve the UI.</p>
</body>
</html>
"@
        Send-WebText -Context $Context -Text $html -ContentType 'text/html; charset=utf-8'
        return
    }

    $rawRelative = $Context.Request.Url.AbsolutePath.TrimStart('/')
    $rawRelativeLower = $rawRelative.ToLowerInvariant()
    if ($rawRelativeLower -match '\.\.' -or $rawRelativeLower -match '%2e') {
        Send-ApiError -Context $Context -Message 'Invalid static path.' -StatusCode 400
        return
    }

    $relative = [Uri]::UnescapeDataString($rawRelative).Replace('/', '\')
    if ([string]::IsNullOrWhiteSpace($relative)) {
        $relative = 'index.html'
    }

    $candidate = Join-Path $distRoot $relative
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        $candidate = Join-Path $distRoot 'index.html'
    }

    try {
        $resolvedRoot = (Resolve-Path -LiteralPath $distRoot).Path
        $resolvedFile = (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).Path
        if (-not $resolvedFile.StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)) {
            Send-ApiError -Context $Context -Message 'Invalid static path.' -StatusCode 400
            return
        }

        Set-CommonWebHeaders -Context $Context
        $bytes = [IO.File]::ReadAllBytes($resolvedFile)
        $Context.Response.StatusCode = 200
        $Context.Response.ContentType = Get-WebContentType -Path $resolvedFile
        $Context.Response.Headers['Cache-Control'] = 'no-cache'
        $Context.Response.ContentLength64 = $bytes.Length
        $Context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        $Context.Response.Close()
    } catch {
        Send-ApiError -Context $Context -Message $_.Exception.Message -StatusCode 500
    }
}

function Invoke-NetBoostApiRequest {
    param($Context)

    $request = $Context.Request
    $method = $request.HttpMethod.ToUpperInvariant()
    $path = $request.Url.AbsolutePath.TrimEnd('/')
    if ([string]::IsNullOrWhiteSpace($path)) {
        $path = '/'
    }

    if ($method -eq 'OPTIONS') {
        Set-CommonWebHeaders -Context $Context
        $Context.Response.StatusCode = 204
        $Context.Response.Close()
        return
    }

    if ($path -notlike '/api*') {
        Send-WebStaticFile -Context $Context
        return
    }

    try {
        if ($method -eq 'GET' -and $path -eq '/api/health') {
            Send-WebJson -Context $Context -Data ([ordered]@{
                ok = $true
                appName = $AppName
                version = $script:NetBoostVersion
                bindAddress = $script:WebBindAddress
                isAdmin = (Is-Admin)
                sessionTokenEnabled = $true
            })
            return
        }

        if (-not (Test-AuthenticatedApiRequest -Context $Context)) {
            return
        }

        if ($method -eq 'GET' -and $path -eq '/api/dashboard') {
            Send-WebJson -Context $Context -Data (Get-WebDashboardState)
            return
        }

        if ($method -eq 'GET' -and $path -eq '/api/cleanup/targets') {
            Send-WebJson -Context $Context -Data @(Get-WebCleanupTargets)
            return
        }

        if ($method -eq 'GET' -and $path -match '^/api/jobs/([^/]+)$') {
            $jobId = [Uri]::UnescapeDataString($matches[1])
            if (-not $script:WebJobs.ContainsKey($jobId)) {
                Send-ApiError -Context $Context -Message 'Job not found.' -StatusCode 404
                return
            }
            Send-WebJson -Context $Context -Data $script:WebJobs[$jobId]
            return
        }

        if ($method -eq 'GET' -and $path -match '^/api/jobs/([^/]+)/events$') {
            $jobId = [Uri]::UnescapeDataString($matches[1])
            if (-not $script:WebJobEvents.ContainsKey($jobId)) {
                Send-ApiError -Context $Context -Message 'Job not found.' -StatusCode 404
                return
            }
            Send-WebJson -Context $Context -Data @($script:WebJobEvents[$jobId].ToArray())
            return
        }

        if ($method -eq 'GET' -and $path -eq '/api/tasks/auto-dns') {
            Send-WebJson -Context $Context -Data (Get-WebAutoDnsTaskState)
            return
        }

        if ($method -eq 'GET' -and $path -eq '/api/settings') {
            Send-WebJson -Context $Context -Data (Get-NetBoostSettings)
            return
        }

        if ($method -in @('POST', 'PATCH')) {
            if (-not (Test-MutatingRequestAllowed -Context $Context)) {
                return
            }
        }

        if ($method -eq 'POST' -and $path -eq '/api/dns/auto') {
            if (-not (Test-AdminForWebAction -Context $Context)) { return }
            $job = Start-WebDnsJob -Action 'auto'
            Send-WebJson -Context $Context -Data ([ordered]@{ jobId = $job.jobId; status = $job.status })
            return
        }

        if ($method -eq 'POST' -and $path -eq '/api/dns/provider') {
            if (-not (Test-AdminForWebAction -Context $Context)) { return }
            $body = Convert-RequestBody -Request $request
            $providerName = [string]$body.provider
            if ($providerName -ne 'Google' -and $providerName -ne 'Cloudflare') {
                Send-ApiError -Context $Context -Message 'Allowed providers: Google, Cloudflare.' -StatusCode 400
                return
            }
            $job = Start-WebDnsJob -Action 'provider' -ProviderName $providerName
            Send-WebJson -Context $Context -Data ([ordered]@{ jobId = $job.jobId; status = $job.status })
            return
        }

        if ($method -eq 'POST' -and $path -eq '/api/dns/reset') {
            if (-not (Test-AdminForWebAction -Context $Context)) { return }
            $job = Start-WebDnsJob -Action 'reset'
            Send-WebJson -Context $Context -Data ([ordered]@{ jobId = $job.jobId; status = $job.status })
            return
        }

        if ($method -eq 'POST' -and $path -eq '/api/dns/flush') {
            if (-not (Test-AdminForWebAction -Context $Context)) { return }
            $job = Start-WebDnsJob -Action 'flush'
            Send-WebJson -Context $Context -Data ([ordered]@{ jobId = $job.jobId; status = $job.status })
            return
        }

        if ($method -eq 'POST' -and $path -eq '/api/cleanup/run') {
            if (-not (Test-AdminForWebAction -Context $Context)) { return }
            $body = Convert-RequestBody -Request $request
            $targetIds = @($body.targetIds | ForEach-Object { [string]$_ })
            try {
                $job = Start-WebCleanupJob -TargetIds $targetIds -Deep ([bool]$body.deep) -Confirmed ([bool]$body.confirmed)
                Send-WebJson -Context $Context -Data ([ordered]@{ jobId = $job.jobId; status = $job.status })
            } catch {
                Send-ApiError -Context $Context -Message $_.Exception.Message -StatusCode 400
            }
            return
        }

        if ($method -eq 'POST' -and $path -eq '/api/npm/scan') {
            $body = Convert-RequestBody -Request $request
            $root = [string]$body.root
            if ([string]::IsNullOrWhiteSpace($root)) {
                $root = $DefaultScanRoot
            }
            $maxDepth = 6
            if ($body.maxDepth) {
                $maxDepth = [int]$body.maxDepth
            }
            $ignore = @('node_modules', '.git', 'dist', 'build')
            if ($body.ignore) {
                $ignore = @($body.ignore | ForEach-Object { [string]$_ })
            }
            $job = Start-WebNpmScanJob -Root $root -MaxDepth $maxDepth -Ignore $ignore
            Send-WebJson -Context $Context -Data ([ordered]@{ jobId = $job.jobId; status = $job.status })
            return
        }

        if ($method -eq 'POST' -and $path -match '^/api/tasks/auto-dns/(create|remove|run)$') {
            if (-not (Test-AdminForWebAction -Context $Context)) { return }
            $action = $matches[1]
            $body = Convert-RequestBody -Request $request
            $job = Invoke-WebTaskAction -Action $action -Confirmed ([bool]$body.confirmed)
            Send-WebJson -Context $Context -Data ([ordered]@{ jobId = $job.jobId; status = $job.status })
            return
        }

        if ($method -eq 'PATCH' -and $path -eq '/api/settings') {
            $body = Convert-RequestBody -Request $request
            $updates = @{}
            foreach ($property in $body.PSObject.Properties) {
                $updates[$property.Name] = $property.Value
            }
            $settings = Save-NetBoostSettings -Updates $updates
            Send-WebJson -Context $Context -Data $settings
            return
        }

        if ($method -eq 'POST' -and $path -eq '/api/dialog/select-file') {
            $body = Convert-RequestBody -Request $request
            $filter = [string]$body.filter
            $job = Start-WebDialogJob -Type 'file' -Filter $filter
            Send-WebJson -Context $Context -Data ([ordered]@{ jobId = $job.jobId; status = $job.status })
            return
        }

        if ($method -eq 'POST' -and $path -eq '/api/dialog/select-folder') {
            $job = Start-WebDialogJob -Type 'folder'
            Send-WebJson -Context $Context -Data ([ordered]@{ jobId = $job.jobId; status = $job.status })
            return
        }

        Send-ApiError -Context $Context -Message 'Endpoint not found.' -StatusCode 404
    } catch {
        Send-ApiError -Context $Context -Message $_.Exception.Message -StatusCode 500
    }
}

function Get-TcpStatusText {
    param([int]$StatusCode)

    switch ($StatusCode) {
        200 { return 'OK' }
        204 { return 'No Content' }
        400 { return 'Bad Request' }
        401 { return 'Unauthorized' }
        403 { return 'Forbidden' }
        404 { return 'Not Found' }
        500 { return 'Internal Server Error' }
        default { return 'OK' }
    }
}

function New-TcpWebResponse {
    $response = [pscustomobject]@{
        StatusCode = 200
        ContentType = 'text/plain; charset=utf-8'
        ContentLength64 = 0
        Headers = @{}
        OutputStream = (New-Object System.IO.MemoryStream)
    }

    $response | Add-Member -MemberType ScriptMethod -Name Close -Value { } -Force
    return $response
}

function New-TcpQueryString {
    param([string]$Query)

    $collection = New-Object System.Collections.Specialized.NameValueCollection
    if ([string]::IsNullOrWhiteSpace($Query)) {
        return ,$collection
    }

    foreach ($part in $Query.TrimStart('?') -split '&') {
        if ([string]::IsNullOrWhiteSpace($part)) {
            continue
        }

        $pieces = $part -split '=', 2
        $name = [Uri]::UnescapeDataString($pieces[0].Replace('+', ' '))
        $value = ''
        if ($pieces.Count -eq 2) {
            $value = [Uri]::UnescapeDataString($pieces[1].Replace('+', ' '))
        }
        $collection.Add($name, $value)
    }

    return ,$collection
}

function Invoke-NetBoostTcpClient {
    param(
        [System.Net.Sockets.TcpClient]$Client,
        [int]$Port
    )

    $stream = $Client.GetStream()
    $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8, $false, 8192, $true)
    try {
        $requestLine = $reader.ReadLine()
        if ([string]::IsNullOrWhiteSpace($requestLine)) {
            return
        }

        $requestParts = $requestLine -split '\s+'
        if ($requestParts.Count -lt 2) {
            return
        }

        $method = $requestParts[0]
        $target = $requestParts[1]
        $headers = @{}
        while ($true) {
            $line = $reader.ReadLine()
            if ($null -eq $line -or $line -eq '') {
                break
            }

            $headerParts = $line -split ':', 2
            if ($headerParts.Count -eq 2) {
                $headers[$headerParts[0].Trim()] = $headerParts[1].Trim()
            }
        }

        $body = ''
        $contentLength = 0
        if ($headers.ContainsKey('Content-Length')) {
            [void][int]::TryParse($headers['Content-Length'], [ref]$contentLength)
        }
        if ($contentLength -gt 0) {
            $buffer = New-Object char[] $contentLength
            $read = 0
            while ($read -lt $contentLength) {
                $count = $reader.Read($buffer, $read, ($contentLength - $read))
                if ($count -le 0) {
                    break
                }
                $read += $count
            }
            $body = -join $buffer[0..([math]::Max(0, $read - 1))]
        }

        $uri = [Uri]("http://127.0.0.1:$Port$target")
        $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
        $requestStream = New-Object System.IO.MemoryStream(,$bodyBytes)
        $request = [pscustomobject]@{
            HttpMethod = $method
            Url = $uri
            Headers = $headers
            InputStream = $requestStream
            ContentEncoding = [System.Text.Encoding]::UTF8
            HasEntityBody = ($contentLength -gt 0)
            QueryString = (New-TcpQueryString -Query $uri.Query)
        }
        $response = New-TcpWebResponse
        $context = [pscustomobject]@{
            Request = $request
            Response = $response
        }

        Invoke-NetBoostApiRequest -Context $context

        $payload = $response.OutputStream.ToArray()
        if ($response.ContentLength64 -eq 0 -and $payload.Length -gt 0) {
            $response.ContentLength64 = $payload.Length
        }

        $headerBuilder = New-Object System.Text.StringBuilder
        [void]$headerBuilder.AppendFormat("HTTP/1.1 {0} {1}`r`n", [int]$response.StatusCode, (Get-TcpStatusText -StatusCode ([int]$response.StatusCode)))
        [void]$headerBuilder.AppendFormat("Content-Type: {0}`r`n", $response.ContentType)
        [void]$headerBuilder.AppendFormat("Content-Length: {0}`r`n", $payload.Length)
        [void]$headerBuilder.Append("Connection: close`r`n")
        foreach ($key in $response.Headers.Keys) {
            [void]$headerBuilder.AppendFormat("{0}: {1}`r`n", $key, $response.Headers[$key])
        }
        [void]$headerBuilder.Append("`r`n")

        $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($headerBuilder.ToString())
        $stream.Write($headerBytes, 0, $headerBytes.Length)
        if ($payload.Length -gt 0) {
            $stream.Write($payload, 0, $payload.Length)
        }
        $stream.Flush()
    } finally {
        $reader.Dispose()
        $stream.Dispose()
        $Client.Close()
    }
}

function Start-NetBoostTcpBackend {
    param([int]$Port = 47812)

    # Localized messages with English fallbacks
    $msgStarting = if ($T.WebStarting) { $T.WebStarting } else { "Starting local Web UI backend server..." }
    $msgRunning = if ($T.WebRunning) { $T.WebRunning } else { "NetBoost Command Center local backend is running." }
    $msgBrowserOpen = if ($T.WebBrowserOpen) { $T.WebBrowserOpen } else { "Opening your default web browser..." }
    $msgBrowserErr = if ($T.WebBrowserErr) { $T.WebBrowserErr } else { "Could not open browser automatically. Please open the URL manually." }
    $msgKeepOpen = if ($T.WebKeepOpen) { $T.WebKeepOpen } else { "Keep this command prompt window open while using the Web UI." }
    $msgAccessAt = if ($T.WebAccessAt) { $T.WebAccessAt } else { "You can access the Web UI at: {0}" }
    $msgPressToStop = if ($T.WebPressToStop) { $T.WebPressToStop } else { "Press Q or ESC to stop the Web UI and return to the main CLI menu." }

    Write-Status Info $msgStarting

    # Refuse to take over a port owned by another process. The backend should
    # never stop unrelated local software just because it uses the same port.
    try {
        $connections = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
        if ($connections.Count -gt 0) {
            $owningPid = $connections[0].OwningProcess
            if ($owningPid -and $owningPid -ne $PID) {
                Write-Status Warning "Port $Port is already in use by PID $owningPid. NetBoost will not stop that process."
                Write-Status Warning "Close the other app or restart NetBoost with another port."
                return
            }
        }
    } catch {
        # Fallback if Get-NetTCPConnection is not supported on the target OS version
    }

    $address = [System.Net.IPAddress]::Parse('127.0.0.1')
    $server = [System.Net.Sockets.TcpListener]::new($address, $Port)
    $server.Server.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::Socket, [System.Net.Sockets.SocketOptionName]::ReuseAddress, $true)
    try {
        $server.Start()
    } catch {
        Write-Status Error ("Failed to start TCP backend at http://127.0.0.1:{0}/: {1}" -f $Port, $_.Exception.Message)
        return
    }

    $prefix = ('http://127.0.0.1:{0}/' -f $Port)
    $script:WebAllowedOrigin = $prefix.TrimEnd('/')

    # Premium UI Frame
    Write-Line ''
    if ($UseFancyUi) {
        Write-Line '════════════════════════════════════════════════════════════' Cyan
        Write-Line "  🌐 $msgRunning" Green
        Write-Line '════════════════════════════════════════════════════════════' Cyan
        Write-Line ("  ➔ URL          : $prefix") White
        Write-Line ("  ➔ Bind Address : $script:WebBindAddress") White
        Write-Line ("  ➔ Runtime      : TcpListener Fallback") DarkGray
        Write-Line ("  ➔ Session Token: $script:WebSessionToken") DarkGray
        Write-Line '────────────────────────────────────────────────────────────' Gray
        Write-Line "  ⚠️  $msgKeepOpen" Yellow
        Write-Line "  💡  $($msgAccessAt -f $prefix)" White
        Write-Line "  🛑  $msgPressToStop" Yellow
        Write-Line '════════════════════════════════════════════════════════════' Cyan
    } else {
        Write-Line '+----------------------------------------------------------+' Cyan
        Write-Line "  [Web] $msgRunning" Green
        Write-Line '+----------------------------------------------------------+' Cyan
        Write-Line ("  - URL          : $prefix") White
        Write-Line ("  - Bind Address : $script:WebBindAddress") White
        Write-Line ("  - Runtime      : TcpListener Fallback") DarkGray
        Write-Line ("  - Session Token: $script:WebSessionToken") DarkGray
        Write-Line '------------------------------------------------------------' Gray
        Write-Line "  [!] $msgKeepOpen" Yellow
        Write-Line "  [*] $($msgAccessAt -f $prefix)" White
        Write-Line "  [x] $msgPressToStop" Yellow
        Write-Line '+----------------------------------------------------------+' Cyan
    }
    Write-Line ''

    # Launching default browser
    Write-Status Info $msgBrowserOpen
    try {
        Start-Process $prefix
        Write-Status Ok 'Browser opened successfully.'
    } catch {
        Write-Status Warning $msgBrowserErr
    }
    Write-Line ''

    Add-WebRecentLog -Event ([pscustomobject]@{
        timestamp = New-NetBoostTimestamp
        level = 'INFO'
        message = ('Local TCP backend started at {0}' -f $prefix)
    })

    try {
        while ($true) {
            Clear-WebCompletedBackgroundTasks

            # Non-blocking check for ESC or Q to stop
            try {
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    if ($key.Key -eq 'Escape' -or $key.Key -eq 'Q') {
                        Write-Line ''
                        Write-Status Info 'Stopping Web UI backend...'
                        break
                    }
                }
            } catch {
                # Stdin redirected or non-interactive console context
            }

            if ($server.Pending()) {
                $client = $server.AcceptTcpClient()
                Invoke-NetBoostTcpClient -Client $client -Port $Port
            } else {
                Start-Sleep -Milliseconds 100
            }
            Clear-WebCompletedBackgroundTasks
        }
    } finally {
        Stop-WebBackgroundTasks
        $server.Stop()
    }
}

function Start-NetBoostWebBackend {
    param([int]$Port = 47812)

    $script:WebBindAddress = '127.0.0.1'
    $script:WebSessionToken = [guid]::NewGuid().ToString('N')

    Start-NetBoostTcpBackend -Port $Port
}
