#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$releaseBuilderPath = Join-Path $repoRoot 'tools\Build-NetBoostRelease.ps1'
$testRoot = Join-Path $repoRoot 'build\release-tests'
$extractRoot = Join-Path $testRoot 'extracted'
$assertions = 0

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw "Assertion failed: $Message"
    }
    $script:assertions++
}

function Assert-Equal {
    param(
        $Expected,
        $Actual,
        [string]$Message
    )

    if ($Expected -cne $Actual) {
        throw "Assertion failed: $Message. Expected '$Expected', got '$Actual'."
    }
    $script:assertions++
}

if (-not (Test-Path -LiteralPath $releaseBuilderPath -PathType Leaf)) {
    throw "Release builder is missing: $releaseBuilderPath"
}

if (Test-Path -LiteralPath $testRoot) {
    Remove-Item -LiteralPath $testRoot -Recurse -Force
}
[void](New-Item -ItemType Directory -Path $testRoot)

try {
    $release = & $releaseBuilderPath -OutputDirectory $testRoot
    $zipPath = Join-Path $testRoot 'NetBoost-Command-Center-v1.0.1.zip'
    $checksumPath = "$zipPath.sha256"

    Assert-True (Test-Path -LiteralPath $zipPath -PathType Leaf) 'release builder produces the v1.0.1 ZIP'
    Assert-True (Test-Path -LiteralPath $checksumPath -PathType Leaf) 'release builder produces the SHA-256 file'
    Assert-Equal ([IO.Path]::GetFullPath($zipPath)) ([IO.Path]::GetFullPath($release.ZipPath)) 'release metadata identifies the ZIP'

    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractRoot -Force

    $requiredFiles = @(
        'NetBoost Command Center.exe',
        'NetBoost_Command_Center.bat',
        'LICENSE',
        'README.md',
        'assets\brand\netboost-mochi-cat.ico',
        'assets\brand\netboost-mochi-cat.png',
        'docs\releases\v1.0.1.md',
        'src\backend\NetBoost.LocalWeb.ps1',
        'src\backend\README.md',
        'src\powershell\NetBoost_Command_Center.ps1',
        'src\powershell\README.md',
        'src\web\dist\index.html',
        'src\web\dist\favicon.svg',
        'src\web\dist\icons.svg',
        'tools\Create-NetBoostShortcut.ps1'
    )
    foreach ($relativePath in $requiredFiles) {
        Assert-True (Test-Path -LiteralPath (Join-Path $extractRoot $relativePath) -PathType Leaf) "release contains $relativePath"
    }

    $developmentFiles = @(Get-ChildItem -LiteralPath $extractRoot -Recurse -File | Where-Object {
        $_.Extension -in @('.ts', '.tsx') -or
        $_.Name -in @('package.json', 'package-lock.json', 'pnpm-lock.yaml') -or
        $_.FullName -match '[\\/]node_modules[\\/]'
    })
    Assert-Equal 0 $developmentFiles.Count 'release excludes development-only Web files'

    $exePath = Join-Path $extractRoot 'NetBoost Command Center.exe'
    $version = [Diagnostics.FileVersionInfo]::GetVersionInfo($exePath)
    Assert-Equal '1.0.1' $version.ProductVersion 'packaged EXE reports product version 1.0.1'

    foreach ($relativePath in @(
        'src\backend\NetBoost.LocalWeb.ps1',
        'src\powershell\NetBoost_Command_Center.ps1',
        'tools\Create-NetBoostShortcut.ps1'
    )) {
        $tokens = $null
        $errors = $null
        [void][Management.Automation.Language.Parser]::ParseFile(
            (Join-Path $extractRoot $relativePath),
            [ref]$tokens,
            [ref]$errors)
        Assert-Equal 0 $errors.Count "packaged $relativePath passes the PowerShell parser"
    }

    $shortcutPath = Join-Path $testRoot 'NetBoost Command Center.lnk'
    & (Join-Path $extractRoot 'tools\Create-NetBoostShortcut.ps1') -ShortcutPath $shortcutPath | Out-Null
    Assert-True (Test-Path -LiteralPath $shortcutPath -PathType Leaf) 'packaged shortcut helper creates a shortcut'

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    try {
        Assert-Equal ([IO.Path]::GetFullPath($exePath)) ([IO.Path]::GetFullPath($shortcut.TargetPath)) 'packaged shortcut targets the EXE'
    } finally {
        if ([Runtime.InteropServices.Marshal]::IsComObject($shortcut)) {
            [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shortcut)
        }
        if ([Runtime.InteropServices.Marshal]::IsComObject($shell)) {
            [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell)
        }
    }

    $actualHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $checksumLine = (Get-Content -LiteralPath $checksumPath -Raw).Trim()
    Assert-Equal "$actualHash  NetBoost-Command-Center-v1.0.1.zip" $checksumLine 'checksum file matches the release ZIP'
    Assert-Equal $actualHash $release.Sha256 'release metadata reports the ZIP checksum'
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}

[pscustomobject]@{
    ok = $true
    assertions = $assertions
    version = '1.0.1'
    exe = 'packaged'
    shortcut = 'verified'
    checksum = 'verified'
} | ConvertTo-Json -Depth 4
