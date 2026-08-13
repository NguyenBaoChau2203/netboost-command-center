#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$script:assertionCount = 0

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }

    $script:assertionCount++
}

function Read-BigEndianUInt32 {
    param(
        [byte[]]$Bytes,
        [int]$Offset
    )

    return [uint32](
        ([uint32]$Bytes[$Offset] -shl 24) -bor
        ([uint32]$Bytes[$Offset + 1] -shl 16) -bor
        ([uint32]$Bytes[$Offset + 2] -shl 8) -bor
        [uint32]$Bytes[$Offset + 3]
    )
}

$svgPath = Join-Path $repoRoot 'assets\brand\netboost-mochi-cat.svg'
$pngPath = Join-Path $repoRoot 'assets\brand\netboost-mochi-cat.png'
$icoPath = Join-Path $repoRoot 'assets\brand\netboost-mochi-cat.ico'

Assert-True (Test-Path -LiteralPath $svgPath -PathType Leaf) 'Mochi Cat SVG asset is missing.'
[xml]$svg = Get-Content -Raw -LiteralPath $svgPath
Assert-True ($svg.DocumentElement.LocalName -eq 'svg') 'Mochi Cat SVG root element is invalid.'
Assert-True ($svg.DocumentElement.GetAttribute('viewBox') -eq '0 0 1024 1024') 'Mochi Cat SVG must use the 0 0 1024 1024 viewBox.'
Assert-True ($svg.SelectNodes("//*[local-name()='text']").Count -eq 0) 'Mochi Cat SVG must not contain text elements.'
Assert-True ($svg.SelectNodes("//*[local-name()='script']").Count -eq 0) 'Mochi Cat SVG must not contain scripts.'

Assert-True (Test-Path -LiteralPath $pngPath -PathType Leaf) 'Mochi Cat PNG asset is missing.'
[byte[]]$pngBytes = [IO.File]::ReadAllBytes($pngPath)
[byte[]]$expectedPngSignature = @(137, 80, 78, 71, 13, 10, 26, 10)
Assert-True ($pngBytes.Length -ge 24) 'Mochi Cat PNG is too small to contain an IHDR chunk.'
Assert-True (($pngBytes[0..7] -join ',') -eq ($expectedPngSignature -join ',')) 'Mochi Cat PNG signature is invalid.'
Assert-True ((Read-BigEndianUInt32 -Bytes $pngBytes -Offset 16) -eq 1024) 'Mochi Cat PNG width must be 1024 pixels.'
Assert-True ((Read-BigEndianUInt32 -Bytes $pngBytes -Offset 20) -eq 1024) 'Mochi Cat PNG height must be 1024 pixels.'

Assert-True (Test-Path -LiteralPath $icoPath -PathType Leaf) 'Mochi Cat ICO asset is missing.'
[byte[]]$icoBytes = [IO.File]::ReadAllBytes($icoPath)
Assert-True ($icoBytes.Length -ge 118) 'Mochi Cat ICO is too small to contain seven directory entries.'
Assert-True ([BitConverter]::ToUInt16($icoBytes, 0) -eq 0) 'Mochi Cat ICO reserved field must be zero.'
Assert-True ([BitConverter]::ToUInt16($icoBytes, 2) -eq 1) 'Mochi Cat ICO type must be 1.'
$icoImageCount = [BitConverter]::ToUInt16($icoBytes, 4)
Assert-True ($icoImageCount -eq 7) 'Mochi Cat ICO must contain exactly seven image layers.'

$actualSizes = for ($index = 0; $index -lt $icoImageCount; $index++) {
    $entryOffset = 6 + ($index * 16)
    $width = if ($icoBytes[$entryOffset] -eq 0) { 256 } else { [int]$icoBytes[$entryOffset] }
    $height = if ($icoBytes[$entryOffset + 1] -eq 0) { 256 } else { [int]$icoBytes[$entryOffset + 1] }
    Assert-True ($width -eq $height) "Mochi Cat ICO layer $index must be square."
    $width
}

$expectedSizes = @(16, 24, 32, 48, 64, 128, 256)
Assert-True ((($actualSizes | Sort-Object) -join ',') -eq (($expectedSizes | Sort-Object) -join ',')) 'Mochi Cat ICO layers must be 16, 24, 32, 48, 64, 128, and 256 pixels.'

$shortcutHelperPath = Join-Path $repoRoot 'tools\Create-NetBoostShortcut.ps1'
$gitIgnorePath = Join-Path $repoRoot '.gitignore'
$expectedLauncherPath = Join-Path $repoRoot 'NetBoost_Command_Center.bat'
$testShortcutPath = Join-Path ([IO.Path]::GetTempPath()) ("NetBoost-Mochi-Cat-{0}.lnk" -f [guid]::NewGuid().ToString('N'))

Assert-True (Test-Path -LiteralPath $shortcutHelperPath -PathType Leaf) 'The branded shortcut helper is missing.'
Assert-True ((Get-Content -LiteralPath $gitIgnorePath) -contains '/NetBoost Command Center.lnk') 'The generated root shortcut must be ignored by Git.'

try {
    & $shortcutHelperPath -ShortcutPath $testShortcutPath | Out-Null
    Assert-True (Test-Path -LiteralPath $testShortcutPath -PathType Leaf) 'The shortcut helper did not create the requested shortcut.'

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($testShortcutPath)
    Assert-True ([IO.Path]::GetFullPath($shortcut.TargetPath) -eq [IO.Path]::GetFullPath($expectedLauncherPath)) 'The branded shortcut must target NetBoost_Command_Center.bat.'
    Assert-True ([IO.Path]::GetFullPath($shortcut.WorkingDirectory) -eq [IO.Path]::GetFullPath($repoRoot)) 'The branded shortcut working directory must be the repository root.'
    Assert-True ($shortcut.IconLocation -eq "$icoPath,0") 'The branded shortcut must use the Mochi Cat ICO at index zero.'
    Assert-True ($shortcut.Description -like '*1.0.1*') 'The branded shortcut description must identify version 1.0.1.'

    $conflictingDestinationRejected = $false
    try {
        & $shortcutHelperPath -ShortcutPath $testShortcutPath -Desktop | Out-Null
    } catch {
        $conflictingDestinationRejected = $_.Exception.Message -like '*cannot be used together*'
    }
    Assert-True $conflictingDestinationRejected 'The shortcut helper must reject simultaneous -ShortcutPath and -Desktop destinations.'

    $missingParentShortcut = Join-Path ([IO.Path]::GetTempPath()) ("NetBoost-Missing-{0}\NetBoost.lnk" -f [guid]::NewGuid().ToString('N'))
    $missingParentRejected = $false
    try {
        & $shortcutHelperPath -ShortcutPath $missingParentShortcut | Out-Null
    } catch {
        $missingParentRejected = $_.Exception.Message -like '*destination directory does not exist*'
    }
    Assert-True $missingParentRejected 'The shortcut helper must reject a destination whose parent directory does not exist.'
} finally {
    if (Test-Path -LiteralPath $testShortcutPath) {
        Remove-Item -LiteralPath $testShortcutPath -Force
    }
}

[pscustomobject]@{
    ok = $true
    assertions = $script:assertionCount
    svg = 'verified'
    png = '1024x1024'
    icoLayers = $actualSizes
    shortcut = 'verified'
} | ConvertTo-Json -Depth 4
