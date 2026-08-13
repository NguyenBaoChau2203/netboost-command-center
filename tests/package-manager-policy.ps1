#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$webRoot = Join-Path $repoRoot 'src\web'
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

$packageJsonPath = Join-Path $webRoot 'package.json'
$pnpmLockPath = Join-Path $webRoot 'pnpm-lock.yaml'
$npmLockPath = Join-Path $webRoot 'package-lock.json'
$gitIgnorePath = Join-Path $repoRoot '.gitignore'
$readmePath = Join-Path $repoRoot 'README.md'

$packageJson = Get-Content -Raw -LiteralPath $packageJsonPath | ConvertFrom-Json
$readme = Get-Content -Raw -LiteralPath $readmePath

Assert-True ($packageJson.version -eq '1.0.1') 'The Web package version must remain 1.0.1.'
Assert-True ($packageJson.packageManager -match '^pnpm@\d+\.\d+\.\d+$') 'package.json must pin pnpm through the packageManager field.'
Assert-True (Test-Path -LiteralPath $pnpmLockPath -PathType Leaf) 'pnpm-lock.yaml is required for reproducible pnpm installs.'
Assert-True (-not (Test-Path -LiteralPath $npmLockPath)) 'package-lock.json must be removed after the pnpm migration.'
Assert-True ((Get-Content -LiteralPath $gitIgnorePath) -contains '/.pnpm-store/') 'The project-local pnpm store must be ignored by Git.'
Assert-True (-not [regex]::IsMatch($readme, '(?im)^\s*npm(?:\s|$)')) 'README command examples must use pnpm instead of npm.'
Assert-True (-not $readme.Contains('Node.js + npm')) 'README requirements must not advertise npm.'

[pscustomobject]@{
    ok = $true
    assertions = $script:assertionCount
    version = $packageJson.version
    packageManager = $packageJson.packageManager
    npmLock = 'absent'
    pnpmLock = 'verified'
} | ConvertTo-Json
