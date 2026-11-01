#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $repoRoot 'src\powershell\NetBoost_Command_Center.ps1') --lang vi --help | Out-Null
$ErrorActionPreference = 'Stop'
$script:assertions = 0
function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
    $script:assertions++
}
function Assert-Throws {
    param([scriptblock]$Action, [string]$Pattern)
    $message = $null
    try { & $Action | Out-Null } catch { $message = $_.Exception.Message }
    Assert-True ($message -and $message -like $Pattern) "Expected '$Pattern', received '$message'."
}
function New-ReleaseFixture {
    param([string]$Tag, [bool]$Prerelease = $false, [bool]$Draft = $false)
    [pscustomobject]@{
        tag_name = $Tag; prerelease = $Prerelease; draft = $Draft
        assets = @([pscustomobject]@{
            name = 'Win11Debloat.zip'; digest = 'sha256:' + ('a' * 64)
            browser_download_url = "https://github.com/Raphire/Win11Debloat/releases/download/$Tag/Win11Debloat.zip"
        })
    }
}
function New-PackageFixture {
    param([string]$Path, [string]$Version)
    [void](New-Item -ItemType Directory -Path (Join-Path $Path 'Config'), (Join-Path $Path 'Scripts\CLI'), (Join-Path $Path 'Scripts\ABC') -Force)
    $source = '[CmdletBinding(SupportsShouldProcess)]' + "`r`n" + 'param([switch]$CLI)' + "`r`n" +
        ('$script:Version = "{0}"' -f $Version) + "`r`n" + "throw 'Fixture scripts must never execute.'"
    Set-Content -LiteralPath (Join-Path $Path 'Win11Debloat.ps1') -Value $source
    Set-Content -LiteralPath (Join-Path $Path 'Config\DefaultSettings.json') -Value '{}'
    Set-Content -LiteralPath (Join-Path $Path 'Scripts\CLI\Show-CliMenuOptions.ps1') -Value "throw 'Must not run.'"
    Set-Content -LiteralPath (Join-Path $Path 'Scripts\ABC\helper.ps1') -Value "throw 'Must not run.'"
}

$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$testRoot = Join-Path $tempParent ('netboost-debloat-tests-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $testRoot)
$originalRoot = (Get-Command Get-NetBoostDebloatRoot).ScriptBlock
$originalLocalAppData = $env:LOCALAPPDATA
$script:managedRoot = Join-Path $testRoot 'managed [fixture] & spaces'
function Get-NetBoostDebloatRoot { return $script:managedRoot }
try {
    $env:LOCALAPPDATA = Join-Path $testRoot 'LocalAppData'
    $backup = Join-Path $env:LOCALAPPDATA 'Win11Debloat\Backups\keep.reg'
    [void](New-Item -ItemType Directory -Path (Split-Path -Parent $backup) -Force)
    Set-Content -LiteralPath $backup -Value 'User backup: keep'
    Assert-True ($null -eq (ConvertTo-NetBoostDebloatVersion '2026.02.30')) 'Invalid calendar tags must be rejected.'
    Assert-True ($null -eq (ConvertTo-NetBoostDebloatVersion '2026.10.30-rc1')) 'Prerelease strings must not become stable dates.'
    $apiReleases = @((New-ReleaseFixture '2026.08.24'), (New-ReleaseFixture '2026.10.30'),
        (New-ReleaseFixture '2026.12.01' $true), (New-ReleaseFixture '2027.01.01' $false $true), (New-ReleaseFixture 'invalid'))
    $latest = Select-NetBoostDebloatRelease $apiReleases
    Assert-True ($latest.Tag -ceq '2026.10.30') 'Select the latest valid stable dated release.'
    Assert-True ($latest.Sha256 -eq ('a' * 64)) 'Preserve the official ZIP SHA-256.'
    $bad = New-ReleaseFixture '2026.10.30'; $bad.assets[0].browser_download_url = 'https://example.com/Win11Debloat.zip'
    Assert-Throws { Select-NetBoostDebloatRelease @($bad) } '*official Win11Debloat ZIP URL*'
    $bad = New-ReleaseFixture '2026.10.30'; $bad.assets[0].digest = ''
    Assert-Throws { Select-NetBoostDebloatRelease @($bad) } '*SHA-256 digest*'
    $bad = New-ReleaseFixture '2026.10.30'; $bad.assets = @()
    Assert-Throws { Select-NetBoostDebloatRelease @($bad) } '*does not publish Win11Debloat.zip*'
    Assert-True ($null -eq (Select-NetBoostDebloatRelease @())) 'Empty releases must not produce an install candidate.'
    $script:apiReleases = $apiReleases
    function Invoke-RestMethod {
        param($Uri, $Headers, $TimeoutSec, $ErrorAction)
        Write-Output -NoEnumerate $script:apiReleases
    }
    Assert-True ((Get-NetBoostDebloatRelease).Tag -ceq '2026.10.30') 'Handle the actual REST cmdlet JSON-array output shape.'
    Remove-Item Function:Invoke-RestMethod

    $missing = Get-NetBoostDebloatInstallation -CandidateRoots @()
    Assert-True (-not $missing.Installed) 'No package is installed before downloading.'
    $externalRoot = Join-Path $testRoot 'external'
    New-PackageFixture $externalRoot '2026.08.24'
    $external = Get-NetBoostDebloatInstallation -CandidateRoots @($externalRoot)
    Assert-True ($external.Installed -and -not $external.Managed -and $external.VersionText -ceq '2026.08.24') 'Read external portable version without executing scripts.'
    Assert-True $external.PreviewSupported 'Recognize SupportsShouldProcess preview support.'
    Assert-True (@((Get-NetBoostDebloatActions $external $latest) | Where-Object Action -eq 'remove').Count -eq 0) 'Never offer removal for an external folder.'
    Assert-Throws { Invoke-NetBoostDebloatAction remove $external $latest } '*Only NetBoost-managed*'
    Assert-True (Test-NetBoostDebloatUpdate $external $latest) 'A newer release must enable downloading a managed update.'
    Assert-True (-not (Test-NetBoostDebloatUpdate $external ([pscustomobject]@{Version=[version]'2026.8.24'}))) 'Equal versions must not enable update.'
    Assert-True (-not (Test-NetBoostDebloatUpdate $external ([pscustomobject]@{Version=[version]'2026.7.11'}))) 'Do not downgrade.'
    Assert-True (-not (Test-NetBoostDebloatUpdate $external $null)) 'Offline state must disable update.'
    $unknown = [pscustomobject]@{Installed=$true;Version=$null;VersionText=$null;Managed=$false;PreviewSupported=$false}
    Assert-True (-not (Test-NetBoostDebloatUpdate $unknown $latest)) 'Unknown versions must not enable update.'
    Assert-True (((Get-NetBoostDebloatActions $unknown $latest).Action -join ',') -eq 'open,check') 'Unsupported preview and unsafe update must stay hidden.'

    $oldRelease = Select-NetBoostDebloatRelease @($apiReleases[0])
    $script:fixtureZip = Join-Path $testRoot 'old.zip'
    Compress-Archive -Path (Join-Path $externalRoot '*') -DestinationPath $script:fixtureZip
    $oldRelease.Sha256 = (Get-FileHash -LiteralPath $script:fixtureZip -Algorithm SHA256).Hash
    function Invoke-WebRequest {
        param($Uri, $OutFile, $TimeoutSec, $ErrorAction, [switch]$UseBasicParsing)
        Copy-Item -LiteralPath $script:fixtureZip -Destination $OutFile
    }
    Install-NetBoostDebloatRelease $oldRelease
    $installed = Get-NetBoostDebloatInstallation -CandidateRoots @()
    Assert-True ($installed.Managed -and $installed.VersionText -ceq '2026.08.24') 'Verified download must become an available managed package.'
    Assert-True (Test-Path -LiteralPath $backup) 'Installing must keep user backups.'
    Assert-Throws { Install-NetBoostDebloatRelease $oldRelease } '*Refusing to overwrite*'
    $script:fixtureZip = Join-Path $testRoot 'new.zip'
    $newSource = Join-Path $testRoot 'new-source'
    New-PackageFixture $newSource '2026.10.30'
    Compress-Archive -Path (Join-Path $newSource '*') -DestinationPath $script:fixtureZip
    $latest.Sha256 = '0' * 64
    Assert-Throws { Install-NetBoostDebloatRelease $latest } '*SHA-256 mismatch*'
    Assert-True ((Get-NetBoostDebloatInstallation -CandidateRoots @()).VersionText -ceq '2026.08.24') 'Hash failure must leave the old copy usable.'
    $mismatch = Select-NetBoostDebloatRelease @((New-ReleaseFixture '2026.11.01'))
    $mismatch.Sha256 = (Get-FileHash -LiteralPath $script:fixtureZip -Algorithm SHA256).Hash
    Assert-Throws { Install-NetBoostDebloatRelease $mismatch } '*package version does not match*'
    Assert-True ((Get-NetBoostDebloatInstallation -CandidateRoots @()).VersionText -ceq '2026.08.24') 'Version mismatch must not replace the active package.'
    $latest.Sha256 = $mismatch.Sha256
    Invoke-NetBoostDebloatAction update $installed $latest
    $installed = Get-NetBoostDebloatInstallation -CandidateRoots @()
    Assert-True ($installed.Managed -and $installed.VersionText -ceq '2026.10.30') 'Successful update must select the newer completed package.'
    Assert-True (@(Get-NetBoostDebloatManagedPackages).Count -eq 2) 'Keep older downloaded versions until explicit tool removal.'
    Assert-True (Test-Path -LiteralPath (Join-Path $externalRoot 'Win11Debloat.ps1')) 'Updating must not modify an external copy.'
    Remove-Item Function:Invoke-WebRequest

    $script:dispatches = [Collections.Generic.List[string]]::new()
    $fakeAction = {param($Action,$Install,$Release) $script:dispatches.Add($Action)}
    foreach ($case in @(@('1',$missing,'install'), @('1',$installed,'open'), @('4',$installed,'remove'), @('6',$external,'update'))) {
        $before = $script:dispatches.Count
        $result = Invoke-NetBoostDebloatSelection $case[0] $case[1] $latest -ReadInput {'n'} -ActionInvoker $fakeAction
        Assert-True ($result -eq 'cancelled' -and $before -eq $script:dispatches.Count) "$($case[2]) cancellation must do nothing."
        $result = Invoke-NetBoostDebloatSelection $case[0] $case[1] $latest -ReadInput {'y'} -ActionInvoker $fakeAction
        Assert-True ($result -eq 'completed' -and $script:dispatches[$before] -eq $case[2]) "$($case[2]) must run only after confirmation."
    }
    $before = $script:dispatches.Count
    Assert-True ((Invoke-NetBoostDebloatSelection '6' $installed $null -ActionInvoker $fakeAction) -eq 'invalid') 'Hidden offline update cannot run.'
    Assert-True ((Invoke-NetBoostDebloatSelection '0' $installed $latest -ActionInvoker $fakeAction) -eq 'back') 'Back must return immediately.'
    Assert-True ((Invoke-NetBoostDebloatSelection '5' $installed $latest -ActionInvoker $fakeAction) -eq 'check') 'Check must request a new lookup.'
    Assert-True ($before -eq $script:dispatches.Count) 'Invalid, back and check must not mutate anything.'
    $script:windows = [Collections.Generic.List[object]]::new()
    function Start-Process {
        param($FilePath,$ArgumentList,$WorkingDirectory,$WindowStyle,$ErrorAction)
        $script:windows.Add([pscustomobject]@{File=$FilePath;Args=$ArgumentList;Root=$WorkingDirectory})
    }
    Invoke-NetBoostDebloatAction open $installed $latest
    Invoke-NetBoostDebloatAction preview $installed $latest
    Assert-True ($script:windows[0].File -like '*\WindowsPowerShell\v1.0\powershell.exe') 'Use Windows PowerShell 5.1, not pwsh.'
    Assert-True ($script:windows[0].Args.EndsWith(' -CLI')) 'Open must explicitly select terminal mode.'
    Assert-True ($script:windows[1].Args.EndsWith(' -CLI -WhatIf')) 'Preview must preserve both CLI and WhatIf.'
    Assert-True (-not ($script:windows[0].Args -match 'RunDefaults|Silent|RunSavedSettings|RemoveApps|SkipRegistryBackup')) 'Do not auto-apply a preset or disable backups.'
    Assert-True ($script:windows[0].Args.Contains('-File "' + $installed.ScriptPath + '"')) 'Quote script paths containing spaces and shell metacharacters.'
    Remove-Item Function:Start-Process

    $script:choices = [Collections.Generic.Queue[string]]::new()
    foreach ($choice in @('2','5','0')) {$script:choices.Enqueue($choice)}
    $script:checks = 0; $script:dispatches.Clear()
    Show-NetBoostDebloatCenter -InputReader {$script:choices.Dequeue()} -InstallationReader {$installed}.GetNewClosure() `
        -ReleaseReader {$script:checks++;throw 'Offline fixture'} -ActionInvoker $fakeAction -PauseAction {}
    Assert-True ($script:checks -eq 2 -and ($script:dispatches -join ',') -eq 'preview') 'Offline preview remains available; recheck only on entry and request.'
    $script:choices.Enqueue('0'); $script:dispatches.Clear()
    Show-NetBoostDebloatCenter -InputReader {$script:choices.Dequeue()} -InstallationReader {$missing}.GetNewClosure() `
        -ReleaseReader {$latest}.GetNewClosure() -ActionInvoker $fakeAction -PauseAction {}
    Assert-True ($script:dispatches.Count -eq 0) 'Entering and leaving the manager must not auto-download or run debloat.'
    foreach ($lang in @('VI','EN')) { $Language=$lang; Assert-True ((Get-NetBoostDebloatText).DataNotice.Length -gt 0) 'Explain removal semantics in both languages.' }
    $RawArgs = @('--win11debloat')
    Assert-True ((Parse-Args).Mode -eq 'Win11Debloat') 'The direct CLI flag must route to the manager.'
    $script:choices.Enqueue('19'); $script:choices.Enqueue('0'); $script:opened=0
    function Ensure-Admin {}
    Show-Menu -InputReader {$script:choices.Dequeue()} -DebloatCenter {$script:opened++}
    Assert-True ($script:opened -eq 1) 'Main-menu option 19 must open this manager exactly once.'

    $marker = Join-Path $installed.Root '.netboost-package.json'
    $originalManifest = Get-Content -LiteralPath $marker -Raw
    $badManifest = $originalManifest | ConvertFrom-Json
    $badManifest.Files += '..\..\..\outside.txt'
    $badManifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $marker
    Assert-Throws {Remove-NetBoostDebloatPackages} '*escapes Win11Debloat scope*'
    Assert-True (Test-Path -LiteralPath (Join-Path $installed.Root 'Win11Debloat.ps1')) 'Validate all ownership paths before deleting any script.'
    Set-Content -LiteralPath $marker -Value $originalManifest
    $link = Join-Path $testRoot 'linked-package'
    [void](New-Item -ItemType Junction -Path $link -Target $externalRoot)
    Assert-Throws {Assert-NetBoostDebloatPath (Join-Path $link 'Win11Debloat.ps1') -Parent $testRoot} '*Refusing linked*'
    [IO.Directory]::Delete($link)
    $extraFile = Join-Path $installed.Root 'my-notes.txt'
    Set-Content -LiteralPath $extraFile -Value 'Keep this unowned file'
    Remove-NetBoostDebloatPackages
    Assert-True (Test-Path -LiteralPath $extraFile) 'Uninstall must preserve unknown user files inside a package.'
    Assert-True (Test-Path -LiteralPath $backup) 'Uninstall must preserve registry backups outside the tool.'
    Assert-True (Test-Path -LiteralPath (Join-Path $externalRoot 'Win11Debloat.ps1')) 'Uninstall must preserve an external copy.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $installed.Root 'Scripts'))) 'Remove all empty owned directories, including equal-length siblings.'
    Assert-True (@(Get-NetBoostDebloatManagedPackages).Count -eq 0) 'All downloaded versions must be removed from management.'
    Assert-True (-not (Get-NetBoostDebloatInstallation -CandidateRoots @()).Installed) 'Removed packages must not remain detected as installed.'
} finally {
    Set-Item Function:Get-NetBoostDebloatRoot -Value $originalRoot
    $env:LOCALAPPDATA = $originalLocalAppData
    foreach ($name in @('Invoke-WebRequest','Invoke-RestMethod','Start-Process')) { if (Test-Path "Function:$name") {Remove-Item "Function:$name"} }
    $full = [IO.Path]::GetFullPath($testRoot)
    if ([IO.Path]::GetDirectoryName($full) -ne $tempParent -or [IO.Path]::GetFileName($full) -notmatch '^netboost-debloat-tests-[a-f0-9]{32}$') {throw 'Unsafe test root.'}
    Remove-Item -LiteralPath $full -Recurse -Force
}
[pscustomobject]@{ok=$true;assertions=$script:assertions;realDebloatExecuted=$false;windowsTweaksApplied=$false} | ConvertTo-Json
