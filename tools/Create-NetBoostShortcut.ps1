#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ShortcutPath = '',
    [switch]$Desktop
)

$ErrorActionPreference = 'Stop'

if ($Desktop -and -not [string]::IsNullOrWhiteSpace($ShortcutPath)) {
    throw '-ShortcutPath and -Desktop cannot be used together.'
}

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$launcherPath = Join-Path $repoRoot 'NetBoost_Command_Center.bat'
$iconPath = Join-Path $repoRoot 'assets\brand\netboost-mochi-cat.ico'

if (-not (Test-Path -LiteralPath $launcherPath -PathType Leaf)) {
    throw "NetBoost launcher was not found: $launcherPath"
}

if (-not (Test-Path -LiteralPath $iconPath -PathType Leaf)) {
    throw "Mochi Cat icon was not found: $iconPath"
}

if ($Desktop) {
    $desktopPath = [Environment]::GetFolderPath([Environment+SpecialFolder]::DesktopDirectory)
    if ([string]::IsNullOrWhiteSpace($desktopPath)) {
        throw 'The Windows desktop directory could not be resolved.'
    }
    $resolvedShortcutPath = Join-Path $desktopPath 'NetBoost Command Center.lnk'
} elseif ([string]::IsNullOrWhiteSpace($ShortcutPath)) {
    $resolvedShortcutPath = Join-Path $repoRoot 'NetBoost Command Center.lnk'
} elseif ([IO.Path]::IsPathRooted($ShortcutPath)) {
    $resolvedShortcutPath = [IO.Path]::GetFullPath($ShortcutPath)
} else {
    $resolvedShortcutPath = [IO.Path]::GetFullPath((Join-Path (Get-Location).Path $ShortcutPath))
}

if ([IO.Path]::GetExtension($resolvedShortcutPath) -ine '.lnk') {
    throw 'The shortcut destination must use the .lnk extension.'
}

$destinationDirectory = Split-Path -Parent $resolvedShortcutPath
if (-not (Test-Path -LiteralPath $destinationDirectory -PathType Container)) {
    throw "The shortcut destination directory does not exist: $destinationDirectory"
}

$shell = $null
$shortcut = $null
try {
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($resolvedShortcutPath)
    $shortcut.TargetPath = $launcherPath
    $shortcut.WorkingDirectory = $repoRoot
    $shortcut.IconLocation = "$iconPath,0"
    $shortcut.Description = 'NetBoost Command Center 1.0.1 - Mochi Cat'
    $shortcut.WindowStyle = 1
    $shortcut.Save()
} finally {
    if ($null -ne $shortcut -and [Runtime.InteropServices.Marshal]::IsComObject($shortcut)) {
        $null = [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shortcut)
    }
    if ($null -ne $shell -and [Runtime.InteropServices.Marshal]::IsComObject($shell)) {
        $null = [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell)
    }
}

if (-not (Test-Path -LiteralPath $resolvedShortcutPath -PathType Leaf)) {
    throw "Windows did not create the requested shortcut: $resolvedShortcutPath"
}

[pscustomobject]@{
    ShortcutPath = $resolvedShortcutPath
    TargetPath = $launcherPath
    WorkingDirectory = $repoRoot
    IconLocation = "$iconPath,0"
    Version = '1.0.1'
}
