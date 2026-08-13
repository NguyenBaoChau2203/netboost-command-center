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

[pscustomobject]@{
    ok = $true
    assertions = $script:assertionCount
    svg = 'verified'
    png = '1024x1024'
    icoLayers = $actualSizes
} | ConvertTo-Json -Depth 4
