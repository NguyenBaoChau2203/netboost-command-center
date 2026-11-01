#Requires -Version 5.1
# Terminal cleanup policies, validation, dispatch and local console logging.
$script:DetailedCleanupLogs = $false

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

function Format-CleanupLogPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ''
    }

    if ($script:DetailedCleanupLogs) {
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

function Write-CleanupEvent {
    param(
        [ValidateSet('INFO', 'DELETE_OK', 'DELETE_DIR', 'SKIP_LOCKED', 'WARN', 'ERROR', 'SUMMARY')]
        [string]$Level,
        [string]$TargetId = '',
        [string]$TargetLabel = '',
        [string]$Path = '',
        [Nullable[int64]]$Bytes = $null,
        [string]$Message = ''
    )

    $event = [ordered]@{
        timestamp = (Get-Date).ToString('o')
        level = $Level
        message = $Message
    }

    if (-not [string]::IsNullOrWhiteSpace($TargetId)) {
        $event.targetId = $TargetId
    }
    if (-not [string]::IsNullOrWhiteSpace($TargetLabel)) {
        $event.targetLabel = $TargetLabel
    }
    $displayPath = Format-CleanupLogPath -Path $Path
    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        $event.path = $displayPath
    }
    if ($null -ne $Bytes) {
        $event.bytes = [int64]$Bytes
    }

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

function New-CleanupTargetDefinition {
    param(
        [string]$Id,
        [string]$Label,
        [string]$DisplayPath,
        [string[]]$Paths,
        [ValidateSet('low', 'medium', 'high')]
        [string]$Risk,
        [bool]$RequiresConfirmation,
        [ValidateSet('filesystem', 'recycle-bin', 'delivery-optimization', 'component-store', 'windows-update-downloads')]
        [string]$Action = 'filesystem',
        [bool]$DeepOnly = $false,
        [int]$SafeMinAgeMinutes = 0,
        [int]$DeepMinAgeMinutes = 0,
        [string[]]$IncludePatterns = @('*'),
        [string[]]$ExcludePathSegments = @(),
        [string]$Description = ''
    )

    return [pscustomobject]@{
        id = $Id
        label = $Label
        path = $DisplayPath
        paths = @($Paths)
        risk = $Risk
        requiresConfirmation = $RequiresConfirmation
        action = $Action
        deepOnly = $DeepOnly
        safeMinAgeMinutes = $SafeMinAgeMinutes
        deepMinAgeMinutes = $DeepMinAgeMinutes
        includePatterns = @($IncludePatterns)
        excludePathSegments = @($ExcludePathSegments)
        description = $Description
    }
}

function Get-CleanupSteamShaderCachePaths {
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
        New-CleanupTargetDefinition -Id 'user-temp' -Label 'Temp nguoi dung' -DisplayPath '%TEMP%' -Paths @($env:TEMP) -Risk 'low' -RequiresConfirmation $false -SafeMinAgeMinutes 1440 -DeepMinAgeMinutes 60 -Description 'User temporary files; safe mode preserves the newest 24 hours'
        New-CleanupTargetDefinition -Id 'windows-temp' -Label 'Windows Temp' -DisplayPath 'C:\Windows\Temp' -Paths @('C:\Windows\Temp') -Risk 'low' -RequiresConfirmation $false -SafeMinAgeMinutes 1440 -DeepMinAgeMinutes 60 -Description 'Windows temporary files; safe mode preserves the newest 24 hours'
        New-CleanupTargetDefinition -Id 'directx-cache' -Label 'DirectX Shader Cache' -DisplayPath (Join-Path $local 'D3DSCache') -Paths @((Join-Path $local 'D3DSCache')) -Risk 'medium' -RequiresConfirmation $false -Description 'DirectX shader cache'
        New-CleanupTargetDefinition -Id 'nvidia-cache' -Label 'NVIDIA DXCache / GLCache / NV_Cache' -DisplayPath (Join-Path $local 'NVIDIA') -Paths @((Join-Path $local 'NVIDIA\DXCache'), (Join-Path $local 'NVIDIA\GLCache'), (Join-Path $local 'NVIDIA\NV_Cache')) -Risk 'medium' -RequiresConfirmation $false -Description 'NVIDIA shader caches'
        New-CleanupTargetDefinition -Id 'steam-cache' -Label 'Steam shader cache' -DisplayPath 'Steam shader cache' -Paths @(Get-CleanupSteamShaderCachePaths) -Risk 'medium' -RequiresConfirmation $false -Description 'Steam shader cache'
        New-CleanupTargetDefinition -Id 'crash-dumps' -Label 'Crash dumps' -DisplayPath (Join-Path $local 'CrashDumps') -Paths @((Join-Path $local 'CrashDumps')) -Risk 'high' -RequiresConfirmation $true -Description 'Application crash dump files'
        New-CleanupTargetDefinition -Id 'thumbnails' -Label 'Thumbnail cache' -DisplayPath (Join-Path $local 'Microsoft\Windows\Explorer') -Paths @((Join-Path $local 'Microsoft\Windows\Explorer')) -Risk 'low' -RequiresConfirmation $false -Description 'Windows thumbnail cache'
        New-CleanupTargetDefinition -Id 'inet-cache' -Label 'INetCache' -DisplayPath (Join-Path $local 'Microsoft\Windows\INetCache') -Paths @((Join-Path $local 'Microsoft\Windows\INetCache')) -Risk 'low' -RequiresConfirmation $false -Description 'Windows INetCache'
        New-CleanupTargetDefinition -Id 'recycle-bin' -Label 'Recycle Bin' -DisplayPath 'Recycle Bin' -Paths @() -Risk 'high' -RequiresConfirmation $true -Action 'recycle-bin' -Description 'Windows Recycle Bin'
        New-CleanupTargetDefinition -Id 'component-store' -Label 'Windows Component Store' -DisplayPath 'DISM /StartComponentCleanup' -Paths @() -Risk 'medium' -RequiresConfirmation $true -Action 'component-store' -DeepOnly $true -Description 'Supported Windows component cleanup via DISM; ResetBase is never used'
        New-CleanupTargetDefinition -Id 'delivery-optimization' -Label 'Delivery Optimization cache' -DisplayPath 'Windows Delivery Optimization cache' -Paths @() -Risk 'low' -RequiresConfirmation $false -Action 'delivery-optimization' -Description 'Supported Delivery Optimization cache cleanup; pinned files are preserved'
        New-CleanupTargetDefinition -Id 'windows-update-downloads' -Label 'Windows Update downloads' -DisplayPath '%SystemRoot%\SoftwareDistribution\Download' -Paths @() -Risk 'high' -RequiresConfirmation $true -Action 'windows-update-downloads' -DeepOnly $true -Description 'Downloaded Windows Update packages; estimate unavailable; running wuauserv and BITS services are restored to their original states'
        New-CleanupTargetDefinition -Id 'windows-font-cache' -Label 'Windows Font Cache' -DisplayPath 'C:\Windows\ServiceProfiles\LocalService\AppData\Local\FontCache' -Paths @('C:\Windows\ServiceProfiles\LocalService\AppData\Local\FontCache') -Risk 'low' -RequiresConfirmation $false -Description 'Windows local font cache files'
        New-CleanupTargetDefinition -Id 'windows-prefetch' -Label 'Windows Prefetch (old .pf only)' -DisplayPath 'C:\Windows\Prefetch\*.pf' -Paths @('C:\Windows\Prefetch') -Risk 'medium' -RequiresConfirmation $true -DeepOnly $true -SafeMinAgeMinutes 43200 -DeepMinAgeMinutes 43200 -IncludePatterns @('*.pf') -ExcludePathSegments @('ReadyBoot') -Description 'Optional deep cleanup of .pf files older than 30 days; ReadyBoot and Layout.ini are preserved'
        New-CleanupTargetDefinition -Id 'windows-error-reports' -Label 'Windows Error Reports' -DisplayPath 'C:\ProgramData\Microsoft\Windows\WER' -Paths @('C:\ProgramData\Microsoft\Windows\WER') -Risk 'low' -RequiresConfirmation $false -SafeMinAgeMinutes 1440 -DeepMinAgeMinutes 60 -Description 'Windows error report files'
    )
}

function Resolve-CleanupTargetSelection {
    param(
        [string[]]$TargetIds,
        [bool]$Deep,
        [bool]$Confirmed
    )

    $definitions = @(Get-CleanupTargetDefinitions)
    $requestedIds = @($TargetIds | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    $selected = @($definitions | Where-Object { $requestedIds -contains $_.id })
    if ($selected.Count -eq 0) {
        throw 'No supported cleanup targets selected.'
    }
    if ($selected.Count -ne $requestedIds.Count) {
        throw 'One or more cleanup targets are unsupported.'
    }

    $deepOnlySelected = @($selected | Where-Object { $_.deepOnly })
    if (-not $Deep -and $deepOnlySelected.Count -gt 0) {
        throw ('Deep mode is required for: {0}' -f (($deepOnlySelected | ForEach-Object { $_.id }) -join ', '))
    }

    $requiresConfirm = $Deep -or @($selected | Where-Object { $_.requiresConfirmation }).Count -gt 0
    if ($requiresConfirm -and -not $Confirmed) {
        throw 'Confirmation is required for selected cleanup targets.'
    }

    return $selected
}

function Invoke-CleanupTargetSet {
    param(
        [string[]]$TargetIds,
        [bool]$Deep,
        [bool]$Confirmed,
        [scriptblock]$OnTargetStart = $null
    )

    $selected = @(Resolve-CleanupTargetSelection -TargetIds $TargetIds -Deep $Deep -Confirmed $Confirmed)
    $index = 0
    foreach ($target in $selected) {
        $index++
        if ($null -ne $OnTargetStart) {
            & $OnTargetStart $target $index $selected.Count
        }

        switch ($target.action) {
            'recycle-bin' {
                Write-CleanupEvent -Level INFO -TargetId $target.id -TargetLabel $target.label -Path 'Recycle Bin' -Message 'Clearing Recycle Bin'
                try {
                    Clear-RecycleBin -Force -ErrorAction Stop
                    Write-CleanupEvent -Level SUMMARY -TargetId $target.id -TargetLabel $target.label -Path 'Recycle Bin' -Message 'Recycle Bin cleanup completed'
                } catch {
                    Write-CleanupEvent -Level WARN -TargetId $target.id -TargetLabel $target.label -Path 'Recycle Bin' -Message $_.Exception.Message
                }
            }
            'delivery-optimization' {
                Invoke-DeliveryOptimizationCleanup -TargetId $target.id -TargetLabel $target.label
            }
            'component-store' {
                Invoke-ComponentStoreCleanup -TargetId $target.id -TargetLabel $target.label
            }
            'windows-update-downloads' {
                Invoke-WindowsUpdateDownloadCleanup -TargetId $target.id -TargetLabel $target.label
            }
            default {
                $minAgeMinutes = if ($Deep) { $target.deepMinAgeMinutes } else { $target.safeMinAgeMinutes }
                foreach ($path in @($target.paths)) {
                    Remove-FolderContents -Path $path -Label $target.label -MinAgeMinutes $minAgeMinutes -IncludePatterns $target.includePatterns -ExcludePathSegments $target.excludePathSegments -TargetId $target.id
                }
            }
        }
    }
}
