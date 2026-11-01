#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$OutputDirectory = ''
)

$ErrorActionPreference = 'Stop'

$version = '1.1.0'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$launcherBuilderPath = Join-Path $repoRoot 'tools\Build-NetBoostLauncher.ps1'

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $resolvedOutputDirectory = Join-Path $repoRoot 'build\release'
} elseif ([IO.Path]::IsPathRooted($OutputDirectory)) {
    $resolvedOutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
} else {
    $resolvedOutputDirectory = [IO.Path]::GetFullPath((Join-Path (Get-Location).Path $OutputDirectory))
}

if ($resolvedOutputDirectory -eq [IO.Path]::GetPathRoot($resolvedOutputDirectory)) {
    throw 'The release output directory cannot be a drive root.'
}

if (-not (Test-Path -LiteralPath $resolvedOutputDirectory -PathType Container)) {
    [void](New-Item -ItemType Directory -Path $resolvedOutputDirectory -Force)
}

$releaseName = "NetBoost-Command-Center-v$version"
$stagePath = [IO.Path]::GetFullPath((Join-Path $resolvedOutputDirectory $releaseName))
$zipPath = [IO.Path]::GetFullPath((Join-Path $resolvedOutputDirectory "$releaseName.zip"))
$checksumPath = "$zipPath.sha256"
$outputPrefix = $resolvedOutputDirectory.TrimEnd('\') + '\'

foreach ($targetPath in @($stagePath, $zipPath, $checksumPath)) {
    if (-not $targetPath.StartsWith($outputPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Unsafe release output path: $targetPath"
    }
}

$requiredInputs = @(
    $launcherBuilderPath,
    (Join-Path $repoRoot 'NetBoost_Command_Center.bat'),
    (Join-Path $repoRoot 'LICENSE'),
    (Join-Path $repoRoot 'README.md'),
    (Join-Path $repoRoot 'assets\brand\netboost-mochi-cat.ico'),
    (Join-Path $repoRoot 'assets\brand\netboost-mochi-cat.png'),
    (Join-Path $repoRoot 'docs\releases\v1.1.0.md'),
    (Join-Path $repoRoot 'docs\mole-cli.md'),
    (Join-Path $repoRoot 'docs\win11debloat-cli.md'),
    (Join-Path $repoRoot 'src\powershell\NetBoost_Command_Center.ps1'),
    (Join-Path $repoRoot 'src\powershell\NetBoost.Cleanup.ps1'),
    (Join-Path $repoRoot 'src\powershell\NetBoost.Mole.ps1'),
    (Join-Path $repoRoot 'src\powershell\NetBoost.Win11Debloat.ps1'),
    (Join-Path $repoRoot 'tools\Create-NetBoostShortcut.ps1')
)
foreach ($requiredInput in $requiredInputs) {
    if (-not (Test-Path -LiteralPath $requiredInput -PathType Leaf)) {
        throw "Required release input was not found: $requiredInput"
    }
}

if (Test-Path -LiteralPath $stagePath) {
    Remove-Item -LiteralPath $stagePath -Recurse -Force
}
foreach ($filePath in @($zipPath, $checksumPath)) {
    if (Test-Path -LiteralPath $filePath) {
        Remove-Item -LiteralPath $filePath -Force
    }
}

$stageDirectories = @(
    '',
    'assets\brand',
    'docs\releases',
    'src\powershell',
    'tools'
)
foreach ($relativeDirectory in $stageDirectories) {
    $directoryPath = if ([string]::IsNullOrEmpty($relativeDirectory)) {
        $stagePath
    } else {
        Join-Path $stagePath $relativeDirectory
    }
    [void](New-Item -ItemType Directory -Path $directoryPath -Force)
}

Copy-Item -LiteralPath `
    (Join-Path $repoRoot 'NetBoost_Command_Center.bat'), `
    (Join-Path $repoRoot 'LICENSE'), `
    (Join-Path $repoRoot 'README.md') `
    -Destination $stagePath

Copy-Item -LiteralPath `
    (Join-Path $repoRoot 'assets\brand\netboost-mochi-cat.ico'), `
    (Join-Path $repoRoot 'assets\brand\netboost-mochi-cat.png') `
    -Destination (Join-Path $stagePath 'assets\brand')

Copy-Item -LiteralPath (Join-Path $repoRoot 'docs\releases\v1.1.0.md') `
    -Destination (Join-Path $stagePath 'docs\releases')

Copy-Item -LiteralPath (Join-Path $repoRoot 'docs\mole-cli.md') `
    -Destination (Join-Path $stagePath 'docs')

Copy-Item -LiteralPath (Join-Path $repoRoot 'docs\win11debloat-cli.md') `
    -Destination (Join-Path $stagePath 'docs')

Copy-Item -LiteralPath `
    (Join-Path $repoRoot 'src\powershell\NetBoost_Command_Center.ps1'), `
    (Join-Path $repoRoot 'src\powershell\NetBoost.Cleanup.ps1'), `
    (Join-Path $repoRoot 'src\powershell\NetBoost.Mole.ps1'), `
    (Join-Path $repoRoot 'src\powershell\NetBoost.Win11Debloat.ps1'), `
    (Join-Path $repoRoot 'src\powershell\README.md') `
    -Destination (Join-Path $stagePath 'src\powershell')

Copy-Item -LiteralPath (Join-Path $repoRoot 'tools\Create-NetBoostShortcut.ps1') `
    -Destination (Join-Path $stagePath 'tools')

& $launcherBuilderPath -OutputPath (Join-Path $stagePath 'NetBoost Command Center.exe') | Out-Null

Compress-Archive `
    -Path (Join-Path $stagePath '*') `
    -DestinationPath $zipPath `
    -CompressionLevel Optimal

$sha256 = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content `
    -LiteralPath $checksumPath `
    -Value "$sha256  $releaseName.zip" `
    -Encoding ascii

[pscustomobject]@{
    Version = $version
    StagePath = $stagePath
    ZipPath = $zipPath
    ChecksumPath = $checksumPath
    Sha256 = $sha256
    ZipBytes = (Get-Item -LiteralPath $zipPath).Length
    FileCount = (Get-ChildItem -LiteralPath $stagePath -Recurse -File).Count
}
