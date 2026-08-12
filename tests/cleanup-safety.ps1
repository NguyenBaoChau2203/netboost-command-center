[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $repoRoot 'src\powershell\NetBoost_Command_Center.ps1'

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

. $scriptPath '--help' | Out-Null

Assert-True ($null -ne (Get-Command Test-SafeCleanupRoot -ErrorAction SilentlyContinue)) 'Test-SafeCleanupRoot is not implemented.'
Assert-True ($null -ne (Get-Command Test-CleanupCandidatePath -ErrorAction SilentlyContinue)) 'Test-CleanupCandidatePath is not implemented.'
Assert-True ($null -ne (Get-Command Test-CleanupFileEligible -ErrorAction SilentlyContinue)) 'Test-CleanupFileEligible is not implemented.'

$sandboxRoot = Join-Path ([IO.Path]::GetTempPath()) ("NetBoost-Cleanup-Safety-{0}" -f [guid]::NewGuid().ToString('N'))
$siblingRoot = "$sandboxRoot-sibling"

try {
    $null = New-Item -ItemType Directory -Path $sandboxRoot -Force
    $null = New-Item -ItemType Directory -Path $siblingRoot -Force
    $childPath = Join-Path $sandboxRoot 'nested\old.pf'
    $recentPath = Join-Path $sandboxRoot 'nested\recent.pf'
    $layoutPath = Join-Path $sandboxRoot 'nested\Layout.ini'
    $readyBootPath = Join-Path $sandboxRoot 'ReadyBoot\old.pf'
    $siblingPath = Join-Path $siblingRoot 'outside.pf'
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $childPath) -Force
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $readyBootPath) -Force
    $null = New-Item -ItemType File -Path $childPath -Force
    $null = New-Item -ItemType File -Path $recentPath -Force
    $null = New-Item -ItemType File -Path $layoutPath -Force
    $null = New-Item -ItemType File -Path $readyBootPath -Force
    $null = New-Item -ItemType File -Path $siblingPath -Force

    (Get-Item -LiteralPath $childPath).LastWriteTime = (Get-Date).AddDays(-31)
    (Get-Item -LiteralPath $recentPath).LastWriteTime = (Get-Date).AddDays(-1)
    (Get-Item -LiteralPath $layoutPath).LastWriteTime = (Get-Date).AddDays(-31)
    (Get-Item -LiteralPath $readyBootPath).LastWriteTime = (Get-Date).AddDays(-31)

    Assert-True (Test-SafeCleanupRoot -Path $sandboxRoot) 'A dedicated cleanup sandbox should be accepted as a safe root.'
    Assert-True (-not (Test-SafeCleanupRoot -Path ([IO.Path]::GetPathRoot($sandboxRoot)))) 'A drive root must never be accepted as a cleanup root.'
    Assert-True (-not (Test-SafeCleanupRoot -Path $env:USERPROFILE)) 'The user profile root must never be accepted as a cleanup root.'
    Assert-True (-not (Test-SafeCleanupRoot -Path $env:WINDIR)) 'The Windows root must never be accepted as a cleanup root.'

    Assert-True (Test-CleanupCandidatePath -Root $sandboxRoot -Candidate $childPath) 'A child file should stay within its cleanup root.'
    Assert-True (-not (Test-CleanupCandidatePath -Root $sandboxRoot -Candidate $siblingPath)) 'A sibling path must not pass the cleanup root boundary check.'

    Assert-True (Test-CleanupFileEligible -FileInfo (Get-Item -LiteralPath $childPath) -Root $sandboxRoot -MinAgeMinutes 43200 -IncludePatterns @('*.pf')) 'An old .pf file should be eligible for deep Prefetch cleanup.'
    Assert-True (-not (Test-CleanupFileEligible -FileInfo (Get-Item -LiteralPath $recentPath) -Root $sandboxRoot -MinAgeMinutes 43200 -IncludePatterns @('*.pf'))) 'A recent .pf file must be preserved.'
    Assert-True (-not (Test-CleanupFileEligible -FileInfo (Get-Item -LiteralPath $layoutPath) -Root $sandboxRoot -MinAgeMinutes 43200 -IncludePatterns @('*.pf'))) 'Layout.ini must not match the Prefetch cleanup pattern.'
    Assert-True (-not (Test-CleanupFileEligible -FileInfo (Get-Item -LiteralPath $readyBootPath) -Root $sandboxRoot -MinAgeMinutes 43200 -IncludePatterns @('*.pf') -ExcludePathSegments @('ReadyBoot'))) 'ReadyBoot must always be excluded from Prefetch cleanup.'

    $prefetchSafeModeRejected = $false
    try {
        Start-WebCleanupJob -TargetIds @('windows-prefetch') -Deep $false -Confirmed $true | Out-Null
    } catch {
        $prefetchSafeModeRejected = $_.Exception.Message -like 'Deep mode is required*'
    }
    Assert-True $prefetchSafeModeRejected 'A deep-only target must be rejected in safe mode.'

    $unsupportedTargetRejected = $false
    try {
        Start-WebCleanupJob -TargetIds @('not-a-cleanup-target') -Deep $false -Confirmed $true | Out-Null
    } catch {
        $unsupportedTargetRejected = $_.Exception.Message -like '*supported cleanup targets*'
    }
    Assert-True $unsupportedTargetRejected 'An unsupported cleanup target must be rejected before a job starts.'

    [pscustomobject]@{
        ok = $true
        rootGuard = 'verified'
        candidateBoundary = 'verified'
        prefetchPolicy = 'verified'
        deepOnlyGuard = 'verified'
        supportedTargetGuard = 'verified'
    } | ConvertTo-Json
} finally {
    Remove-Item -LiteralPath $sandboxRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $siblingRoot -Recurse -Force -ErrorAction SilentlyContinue
}
