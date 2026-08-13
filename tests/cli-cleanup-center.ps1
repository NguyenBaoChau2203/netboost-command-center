#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$scriptPath = Join-Path $repoRoot 'src\powershell\NetBoost_Command_Center.ps1'
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

. $scriptPath '--lang' 'vi' '--help' | Out-Null

Assert-True ($null -ne (Get-Command Get-CliCleanupActionDefinitions -ErrorAction SilentlyContinue)) 'CLI cleanup action definitions are missing.'
Assert-True ($null -ne (Get-Command Invoke-CliCleanupSelection -ErrorAction SilentlyContinue)) 'CLI cleanup selection dispatcher is missing.'
Assert-True ($T.CliCleanupDescription8 -like '*SoftwareDistribution\Download*') 'Windows Update description must show the canonical path with one separator.'

$actions = @(Get-CliCleanupActionDefinitions)
Assert-True ($actions.Count -eq 9) 'Cleanup Center must expose exactly nine actions plus Back.'

$safe = $actions | Where-Object key -eq '4'
$expectedSafeIds = 'user-temp,windows-temp,directx-cache,nvidia-cache,steam-cache,thumbnails,inet-cache,delivery-optimization,windows-font-cache,windows-error-reports'
Assert-True (($safe.targetIds -join ',') -eq $expectedSafeIds) 'Recommended safe cleanup contains the wrong targets.'
Assert-True (-not ($safe.targetIds -contains 'recycle-bin')) 'Recommended safe cleanup must exclude Recycle Bin.'
Assert-True (-not ($safe.targetIds -contains 'crash-dumps')) 'Recommended safe cleanup must exclude crash dumps.'
Assert-True (-not ($safe.targetIds -contains 'component-store')) 'Recommended safe cleanup must exclude Component Store.'
Assert-True (-not ($safe.targetIds -contains 'windows-update-downloads')) 'Recommended safe cleanup must exclude Windows Update downloads.'
Assert-True (-not ($safe.targetIds -contains 'windows-prefetch')) 'Recommended safe cleanup must exclude Prefetch.'

$advanced = @($actions | Where-Object { $_.confirmation -eq 'CONFIRM' })
Assert-True (($advanced.key -join ',') -eq '7,8,9') 'Advanced actions must be keys 7, 8, and 9.'
Assert-True (@($advanced | Where-Object { -not $_.deep }).Count -eq 0) 'Every advanced action must use deep mode.'
Assert-True ((($actions | Where-Object key -eq '7').targetIds -join ',') -eq 'component-store') 'Advanced key 7 must target Component Store only.'
Assert-True ((($actions | Where-Object key -eq '8').targetIds -join ',') -eq 'windows-update-downloads') 'Advanced key 8 must target Windows Update downloads only.'
Assert-True ((($actions | Where-Object key -eq '9').targetIds -join ',') -eq 'windows-prefetch') 'Advanced key 9 must target Prefetch only.'

$dispatches = [Collections.Generic.List[object]]::new()
$fakeInvoker = {
    param([string[]]$TargetIds, [bool]$Deep, [bool]$Confirmed)
    $dispatches.Add([pscustomobject]@{
        targetIds = @($TargetIds)
        deep = $Deep
        confirmed = $Confirmed
    }) | Out-Null
}.GetNewClosure()

$result = Invoke-CliCleanupSelection -Choice '8' -ReadInput { param($Prompt) 'no' } -CleanupInvoker $fakeInvoker
Assert-True ($result -eq 'cancelled' -and $dispatches.Count -eq 0) 'Invalid advanced confirmation must cancel without dispatch.'

$result = Invoke-CliCleanupSelection -Choice '8' -ReadInput { param($Prompt) 'confirm' } -CleanupInvoker $fakeInvoker
Assert-True ($result -eq 'cancelled' -and $dispatches.Count -eq 0) 'Advanced confirmation must be case-sensitive.'

$result = Invoke-CliCleanupSelection -Choice '8' -ReadInput { param($Prompt) 'CONFIRM' } -CleanupInvoker $fakeInvoker
Assert-True ($result -eq 'completed') 'Exact advanced confirmation must complete.'
Assert-True (($dispatches[0].targetIds -join ',') -eq 'windows-update-downloads') 'Advanced key 8 must dispatch only Windows Update downloads.'
Assert-True ($dispatches[0].deep -and $dispatches[0].confirmed) 'Advanced cleanup must dispatch as deep and confirmed.'

$dispatches.Clear()
$result = Invoke-CliCleanupSelection -Choice '6' -ReadInput { param($Prompt) 'n' } -CleanupInvoker $fakeInvoker
Assert-True ($result -eq 'cancelled' -and $dispatches.Count -eq 0) 'Recycle Bin cancellation must not dispatch.'
$result = Invoke-CliCleanupSelection -Choice '6' -ReadInput { param($Prompt) 'y' } -CleanupInvoker $fakeInvoker
Assert-True ($result -eq 'completed') 'Recycle Bin must run after y confirmation.'
Assert-True (($dispatches[0].targetIds -join ',') -eq 'recycle-bin') 'Confirmed key 6 must dispatch Recycle Bin only.'
Assert-True (-not $dispatches[0].deep -and $dispatches[0].confirmed) 'Recycle Bin must remain non-deep but explicitly confirmed.'

$dispatches.Clear()
$safePrompted = $false
$result = Invoke-CliCleanupSelection -Choice '4' -ReadInput {
    param($Prompt)
    $safePrompted = $true
    return 'unexpected'
}.GetNewClosure() -CleanupInvoker $fakeInvoker
Assert-True ($result -eq 'completed' -and -not $safePrompted) 'Recommended safe cleanup must not prompt.'
Assert-True ($dispatches.Count -eq 1 -and -not $dispatches[0].deep -and -not $dispatches[0].confirmed) 'Recommended safe cleanup must dispatch in safe unconfirmed mode.'

$dispatches.Clear()
$result = Invoke-CliCleanupSelection -Choice '0' -ReadInput { param($Prompt) throw 'Back must not prompt.' } -CleanupInvoker $fakeInvoker
Assert-True ($result -eq 'back' -and $dispatches.Count -eq 0) 'Back must return without dispatch.'
$result = Invoke-CliCleanupSelection -Choice 'invalid' -ReadInput { param($Prompt) throw 'Invalid choice must not prompt.' } -CleanupInvoker $fakeInvoker
Assert-True ($result -eq 'invalid' -and $dispatches.Count -eq 0) 'Invalid choice must return without dispatch.'

. $scriptPath '--lang' 'en' '--help' | Out-Null
Assert-True ($T.HeaderSubtitle -eq 'Quick view: dashboard does not auto-run, view it by selecting option 15.') 'English Dashboard hint must point to option 15.'
Assert-True ($T.Menu9 -eq 'Open CLI Cleanup Center (Safe / Advanced)') 'English option 9 must identify the Cleanup Center.'
Assert-True ($T.Menu10 -eq 'Clean Windows & User Temp files older than 24 hours') 'English Temp shortcut must describe its 24-hour retention.'
Assert-True ($T.Menu12 -eq 'Clean basic Windows system cache') 'English system shortcut must not claim to clean every system cache.'
Assert-True ($T.Menu13 -eq 'Empty Recycle Bin (confirmation required)') 'English Recycle Bin shortcut must advertise confirmation.'

. $scriptPath '--lang' 'vi' '--help' | Out-Null
Assert-True ($T.HeaderSubtitle -eq 'Mo nhanh: dashboard khong tu chay, chi xem khi ban chon muc 15.') 'Vietnamese Dashboard hint must point to option 15.'
Assert-True ($T.Menu9 -eq 'Mo Trung tam don dep CLI (An toan / Nang cao)') 'Vietnamese option 9 must identify the Cleanup Center.'
Assert-True ($T.Menu10 -eq 'Don tep tam Windows & Nguoi dung cu hon 24 gio') 'Vietnamese Temp shortcut must describe its 24-hour retention.'
Assert-True ($T.Menu12 -eq 'Don cache Windows co ban') 'Vietnamese system shortcut must not claim to clean every system cache.'
Assert-True ($T.Menu13 -eq 'Lam trong Thung rac (can xac nhan)') 'Vietnamese Recycle Bin shortcut must advertise confirmation.'

$showMenuCommand = Get-Command Show-Menu
Assert-True $showMenuCommand.Parameters.ContainsKey('InputReader') 'Main menu must accept an injected input reader for behavior tests.'
Assert-True $showMenuCommand.Parameters.ContainsKey('CleanupCenter') 'Main menu must accept an injected Cleanup Center action for behavior tests.'

$script:menuChoices = [Collections.Generic.Queue[string]]::new()
$script:menuChoices.Enqueue('9')
$script:menuChoices.Enqueue('0')
$script:cleanupCenterOpenCount = 0
function Ensure-Admin { }
Show-Menu `
    -InputReader { param($Prompt) $script:menuChoices.Dequeue() } `
    -CleanupCenter { $script:cleanupCenterOpenCount++ }
Assert-True ($script:cleanupCenterOpenCount -eq 1) 'Main-menu option 9 must open Cleanup Center exactly once.'

foreach ($shortcutName in @('Clean-Temp', 'Clean-Game', 'Clean-System', 'Clean-RecycleBin')) {
    Assert-True (Get-Command $shortcutName).Parameters.ContainsKey('CleanupInvoker') "$shortcutName must dispatch through the shared cleanup target invoker."
}
Assert-True (Get-Command Clean-RecycleBin).Parameters.ContainsKey('ReadInput') 'Recycle Bin shortcut must accept confirmation input.'

$dispatches.Clear()
Clean-Temp -CleanupInvoker $fakeInvoker | Out-Null
Clean-Game -CleanupInvoker $fakeInvoker | Out-Null
Clean-System -CleanupInvoker $fakeInvoker | Out-Null
Assert-True (($dispatches[0].targetIds -join ',') -eq 'user-temp,windows-temp') 'Temp shortcut must use the two canonical Temp targets.'
Assert-True (($dispatches[1].targetIds -join ',') -eq 'directx-cache,nvidia-cache,steam-cache') 'Game shortcut must use the three canonical shader-cache targets.'
Assert-True (($dispatches[2].targetIds -join ',') -eq 'thumbnails,inet-cache,delivery-optimization,windows-font-cache,windows-error-reports') 'System shortcut must use only basic Windows cache targets.'
Assert-True (@($dispatches | Where-Object confirmed).Count -eq 0) 'Safe shortcuts must not claim confirmation.'

$dispatches.Clear()
$result = Clean-RecycleBin -ReadInput { param($Prompt) 'n' } -CleanupInvoker $fakeInvoker
Assert-True ($result -eq 'cancelled' -and $dispatches.Count -eq 0) 'Recycle Bin shortcut cancellation must not dispatch.'
$result = Clean-RecycleBin -ReadInput { param($Prompt) 'y' } -CleanupInvoker $fakeInvoker
Assert-True ($result -eq 'completed' -and ($dispatches[0].targetIds -join ',') -eq 'recycle-bin') 'Recycle Bin shortcut must dispatch only after y confirmation.'

[pscustomobject]@{
    ok = $true
    assertions = $script:assertionCount
    actions = $actions.Count
    safeGroup = 'verified'
    advancedConfirmation = 'verified'
    recycleBinConfirmation = 'verified'
} | ConvertTo-Json
