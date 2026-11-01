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
    $caught = $null
    try { & $Action | Out-Null } catch { $caught = $_.Exception.Message }
    Assert-True ($caught -and $caught -like $Pattern) "Expected failure matching '$Pattern', received '$caught'."
}
function New-ReleaseFixture {
    param([string]$Version, [string]$Suffix = 'windows', [bool]$Prerelease = $false, [bool]$Draft = $false)
    $tag = "V$Version-$Suffix"
    [pscustomobject]@{
        tag_name = $tag; prerelease = $Prerelease; draft = $Draft
        assets = @([pscustomobject]@{
            name = "mole-$Version-x64.zip"
            browser_download_url = "https://github.com/tw93/Mole/releases/download/$tag/mole-$Version-x64.zip"
            digest = 'sha256:' + ('a' * 64)
        })
    }
}

$testParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$testRoot = Join-Path $testParent ('netboost-mole-tests-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $testRoot)
$originalRunner = (Get-Command Invoke-NetBoostMolePowerShell).ScriptBlock
try {
    $releases = @(
        (New-ReleaseFixture '99.0.0' 'macos'), (New-ReleaseFixture '1.9.0'),
        (New-ReleaseFixture '1.10.0'), (New-ReleaseFixture '2.0.0' 'windows' $true),
        (New-ReleaseFixture '3.0.0' 'windows' $false $true)
    )
    $release = Select-NetBoostMoleRelease -Releases $releases -Architecture x64
    Assert-True ($release.Version -eq [version]'1.10.0') 'Must choose the newest stable Windows version numerically.'
    Assert-True ($release.Sha256 -eq ('a' * 64)) 'Must retain the official asset SHA-256 digest.'
    Assert-True ($null -eq (Select-NetBoostMoleRelease -Releases @($releases[0]) -Architecture x64)) 'macOS must not be used as a Windows fallback.'
    $bad = New-ReleaseFixture '1.10.0'
    $bad.assets[0].browser_download_url = 'https://example.com/mole.zip'
    Assert-Throws { Select-NetBoostMoleRelease @($bad) x64 } '*official download URL*'
    $bad = New-ReleaseFixture '1.10.0'
    $bad.assets[0].digest = ''
    Assert-Throws { Select-NetBoostMoleRelease @($bad) x64 } '*SHA-256 digest*'
    Assert-Throws { Select-NetBoostMoleRelease @($releases[2]) arm64 } '*No official arm64*'
    Assert-True ($null -eq (ConvertTo-NetBoostMoleVersion '1.2.3-rc1')) 'Unknown prerelease strings must not become stable versions.'
    $script:releaseApiFixture = $releases
    function Invoke-RestMethod {
        param($Uri, $Headers, $TimeoutSec, $ErrorAction)
        # Match the real cmdlet's non-enumerated JSON-array pipeline behavior.
        Write-Output -NoEnumerate $script:releaseApiFixture
    }
    Assert-True ((Get-NetBoostMoleRelease).Version -eq [version]'1.10.0') 'GitHub JSON arrays must be flattened before filtering releases.'
    Remove-Item Function:Invoke-RestMethod

    $fixtureRoot = Join-Path $testRoot 'package with spaces'
    [void](New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'lib\core') -Force)
    Set-Content -LiteralPath (Join-Path $fixtureRoot 'mole.ps1') -Value '# fixture only'
    Set-Content -LiteralPath (Join-Path $fixtureRoot 'lib\core\base.ps1') -Value '# fixture only'
    Set-Content -LiteralPath (Join-Path $fixtureRoot 'VERSION') -Value '1.9.0'
    $installation = Get-NetBoostMoleInstallation -CandidateRoots @($fixtureRoot)
    Assert-True ($installation.Installed -and $installation.Version -eq [version]'1.9.0') 'Must read installed version without running Mole.'
    Assert-True ($installation.Channel -eq 'release') 'A release install must be recognized.'
    [void](New-Item -ItemType Directory -Path (Join-Path $fixtureRoot '.git'))
    Assert-True ((Get-NetBoostMoleInstallation -CandidateRoots @($fixtureRoot)).Channel -eq 'git') 'Source installs must retain their Git update channel.'
    Remove-Item -LiteralPath (Join-Path $fixtureRoot '.git')
    $scoopFixture = Join-Path $testRoot 'scoop\apps\mole\current'
    [void](New-Item -ItemType Directory -Path $scoopFixture -Force)
    Copy-Item -Path (Join-Path $fixtureRoot '*') -Destination $scoopFixture -Recurse
    Assert-True ((Get-NetBoostMoleInstallation -CandidateRoots @($scoopFixture)).Channel -eq 'scoop') 'Scoop ownership must be preserved.'
    $wingetFixture = Join-Path $testRoot 'Microsoft\WinGet\Packages\tw93.MoleCLI_test'
    [void](New-Item -ItemType Directory -Path $wingetFixture -Force)
    Copy-Item -Path (Join-Path $fixtureRoot '*') -Destination $wingetFixture -Recurse
    Assert-True ((Get-NetBoostMoleInstallation -CandidateRoots @($wingetFixture)).Channel -eq 'winget') 'WinGet ownership must be preserved.'
    $missing = Get-NetBoostMoleInstallation -CandidateRoots @((Join-Path $testRoot 'Mole-GUI-only'))
    Assert-True (-not $missing.Installed) 'Missing CLI or GUI-only data must not count as an installed CLI.'
    Remove-Item -LiteralPath (Join-Path $fixtureRoot 'VERSION')
    Assert-True ($null -eq (Get-NetBoostMoleInstallation -CandidateRoots @($fixtureRoot)).Version) 'Unreadable versions must stay unknown.'
    Set-Content -LiteralPath (Join-Path $fixtureRoot 'lib\core\version.ps1') -Value '$script:MoleDefaultVersion = "1.9.0"'
    Assert-True ((Get-NetBoostMoleInstallation -CandidateRoots @($fixtureRoot)).Version -eq [version]'1.9.0') 'Legacy helper version must be read as text.'
    Set-Content -LiteralPath (Join-Path $fixtureRoot 'VERSION') -Value '1.9.0'

    Assert-True (Test-NetBoostMoleUpdate $installation $release) 'A newer Windows release must enable update.'
    $same = [pscustomobject]@{ Version = [version]'1.9.0' }
    Assert-True (-not (Test-NetBoostMoleUpdate $installation $same)) 'An equal release must not enable update.'
    $old = [pscustomobject]@{ Version = [version]'1.8.0' }
    Assert-True (-not (Test-NetBoostMoleUpdate $installation $old)) 'Update must not downgrade.'
    Assert-True (-not (Test-NetBoostMoleUpdate $installation $null)) 'Offline state must not enable update.'
    $unknown = [pscustomobject]@{ Installed = $true; Version = $null }
    Assert-True (-not (Test-NetBoostMoleUpdate $unknown $release)) 'An unknown installed version must not enable update.'
    Assert-True (((Get-NetBoostMoleActions $installation $release).Action -join ',') -eq 'open,preview,analyze,remove,update,check') 'Installed actions must include optional update.'
    Assert-True (((Get-NetBoostMoleActions $missing $release).Action -join ',') -eq 'install,check') 'Missing CLI must offer install without installed-only actions.'
    Assert-True (((Get-NetBoostMoleActions $missing $null).Action -join ',') -eq 'check') 'An offline first install must require a successful recheck.'

    $script:dispatches = [Collections.Generic.List[object]]::new()
    $fakeAction = { param($Action, $Install, $Latest) $script:dispatches.Add($Action) }
    foreach ($case in @(@('1', $missing, 'install'), @('4', $installation, 'remove'), @('6', $installation, 'update'))) {
        $before = $script:dispatches.Count
        $result = Invoke-NetBoostMoleSelection $case[0] $case[1] $release -ReadInput { 'n' } -ActionInvoker $fakeAction
        Assert-True ($result -eq 'cancelled' -and $script:dispatches.Count -eq $before) "$($case[2]) cancellation must have no side effects."
        $result = Invoke-NetBoostMoleSelection $case[0] $case[1] $release -ReadInput { 'y' } -ActionInvoker $fakeAction
        Assert-True ($result -eq 'completed' -and $script:dispatches[$before] -eq $case[2]) "$($case[2]) must run only after confirmation."
    }
    $before = $script:dispatches.Count
    Assert-True ((Invoke-NetBoostMoleSelection '6' $installation $null -ActionInvoker $fakeAction) -eq 'invalid') 'Hidden update must not dispatch while offline.'
    Assert-True ((Invoke-NetBoostMoleSelection '0' $missing $release -ActionInvoker $fakeAction) -eq 'back') 'Back must leave the menu.'
    Assert-True ((Invoke-NetBoostMoleSelection '5' $missing $release -ActionInvoker $fakeAction) -eq 'check') 'Check must request a fresh release lookup.'
    Assert-True ($before -eq $script:dispatches.Count) 'Back, invalid update and check must not mutate the installation.'

    $script:processes = [Collections.Generic.List[object]]::new()
    function Invoke-NetBoostMolePowerShell {
        param($ScriptPath, [string[]]$Arguments, [switch]$OpenWindow)
        $script:processes.Add([pscustomobject]@{ Path = $ScriptPath; Args = @($Arguments); Window = [bool]$OpenWindow })
    }
    foreach ($action in @('open', 'preview', 'analyze')) { Invoke-NetBoostMoleAction $action $installation $release }
    Assert-True ($script:processes[0].Args.Count -eq 0 -and $script:processes[0].Window) 'Opening Mole must only open its interactive menu.'
    Assert-True (($script:processes[1].Args -join ',') -eq 'clean,--dry-run' -and $script:processes[1].Window) 'Preview must always include --dry-run.'
    Assert-True (($script:processes[2].Args -join ',') -eq 'analyze') 'Analyze must not dispatch cleanup.'
    $sourceInstall = [pscustomobject]@{ Installed = $true; Version = $installation.Version; Root = $installation.Root; ScriptPath = $installation.ScriptPath; Channel = 'git' }
    Invoke-NetBoostMoleAction update $sourceInstall $release
    Assert-True (($script:processes[3].Args -join ',') -eq 'update') 'Git installs must use the upstream updater.'
    Invoke-NetBoostMoleAction remove $installation $release
    Assert-True (($script:processes[4].Args -join ',') -eq ('-InstallDir,' + $installation.Root + ',-Uninstall')) 'Uninstall must use the original installer with its exact root.'
    Assert-Throws { Invoke-NetBoostMoleAction update $installation $same } '*No verified newer*'
    $script:managerCalls = [Collections.Generic.List[string]]::new()
    function scoop {
        param($Verb, $Package)
        $script:managerCalls.Add("scoop,$Verb,$Package")
        $global:LASTEXITCODE = 0
    }
    function winget.exe {
        $script:managerCalls.Add('winget,' + ($args -join ','))
        $global:LASTEXITCODE = 0
    }
    $scoopInstall = Get-NetBoostMoleInstallation -CandidateRoots @($scoopFixture)
    $wingetInstall = Get-NetBoostMoleInstallation -CandidateRoots @($wingetFixture)
    Invoke-NetBoostMoleAction update $scoopInstall $release
    Invoke-NetBoostMoleAction remove $scoopInstall $release
    Invoke-NetBoostMoleAction update $wingetInstall $release
    Invoke-NetBoostMoleAction remove $wingetInstall $release
    Assert-True ($script:managerCalls[0] -eq 'scoop,update,mole') 'Scoop update must go through Scoop.'
    Assert-True ($script:managerCalls[1] -eq 'scoop,uninstall,mole') 'Scoop uninstall must go through Scoop.'
    Assert-True ($script:managerCalls[2] -eq 'winget,upgrade,--id,tw93.MoleCLI,--exact,--source,winget') 'WinGet update must target only the official CLI package.'
    Assert-True ($script:managerCalls[3] -eq 'winget,uninstall,--id,tw93.MoleCLI,--exact,--source,winget') 'WinGet uninstall must target only the official CLI package.'
    Remove-Item Function:scoop
    Remove-Item Function:winget.exe
    Set-Item -Path Function:Invoke-NetBoostMolePowerShell -Value $originalRunner

    $script:windowArguments = $null
    function Start-Process {
        param($FilePath, $ArgumentList, $WindowStyle, $ErrorAction)
        $script:windowArguments = $ArgumentList
    }
    Invoke-NetBoostMolePowerShell -ScriptPath 'D:\Mole folder & [test]\mole.ps1' -Arguments @('clean', '--dry-run') -OpenWindow
    Assert-True ($script:windowArguments -like '*-File "D:\Mole folder & `[test`]\mole.ps1" clean --dry-run') 'Interactive launch must quote the script path and preserve preview mode.'
    Remove-Item Function:Start-Process
    $failingChild = Join-Path $testRoot 'fail.ps1'
    Set-Content -LiteralPath $failingChild -Value 'exit 7'
    Assert-Throws { Invoke-NetBoostMolePowerShell -ScriptPath $failingChild } '*exited with code 7*'

    # Real child PowerShell, but a disposable installer fixture and fake download.
    # This verifies ZIP validation and -File argument handling without installing Mole.
    Set-Content -LiteralPath (Join-Path $fixtureRoot 'VERSION') -Value '1.10.0'
    $stubInstaller = @'
param([string]$InstallDir, [switch]$AddToPath, [switch]$Force)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Copy-Item -Path (Join-Path $PSScriptRoot '*') -Destination $InstallDir -Recurse -Force
@{ addToPath = [bool]$AddToPath; force = [bool]$Force } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $InstallDir 'fixture-result.json')
exit 0
'@
    Set-Content -LiteralPath (Join-Path $fixtureRoot 'install.ps1') -Value $stubInstaller
    $script:fixtureZip = Join-Path $testRoot 'fixture.zip'
    Compress-Archive -Path (Join-Path $fixtureRoot '*') -DestinationPath $script:fixtureZip
    function Invoke-WebRequest {
        param($Uri, $OutFile, $TimeoutSec, $ErrorAction, [switch]$UseBasicParsing)
        Copy-Item -LiteralPath $script:fixtureZip -Destination $OutFile
    }
    $release.Sha256 = (Get-FileHash -LiteralPath $script:fixtureZip -Algorithm SHA256).Hash
    $installTarget = [pscustomobject]@{ Installed = $false; Root = (Join-Path $testRoot "installed [fixture] & spaces"); Version = $null; Channel = 'release' }
    Install-NetBoostMoleRelease -Release $release -Installation $installTarget
    $verified = Get-NetBoostMoleInstallation -CandidateRoots @($installTarget.Root)
    Assert-True ($verified.Version -eq $release.Version) 'Verified ZIP fixture must install the selected version.'
    $receipt = Get-Content -LiteralPath (Join-Path $installTarget.Root 'fixture-result.json') -Raw | ConvertFrom-Json
    Assert-True ($receipt.addToPath -and -not $receipt.force) 'First install must request PATH without force.'
    Install-NetBoostMoleRelease -Release $release -Installation $verified
    $receipt = Get-Content -LiteralPath (Join-Path $installTarget.Root 'fixture-result.json') -Raw | ConvertFrom-Json
    Assert-True $receipt.force 'Updating a release install must explicitly overwrite the old version.'
    $release.Sha256 = '0' * 64
    $tamperTarget = [pscustomobject]@{ Installed = $false; Root = (Join-Path $testRoot 'tampered'); Version = $null }
    Assert-Throws { Install-NetBoostMoleRelease $release $tamperTarget } '*SHA-256 mismatch*'
    Assert-True (-not (Test-Path -LiteralPath $tamperTarget.Root)) 'A hash mismatch must not create an installation.'
    $unowned = [pscustomobject]@{ Installed = $false; Root = (Join-Path $testRoot 'unowned'); Version = $null }
    [void](New-Item -ItemType Directory -Path $unowned.Root)
    Assert-Throws { Install-NetBoostMoleRelease $release $unowned } '*Refusing to overwrite*'
    $linkedRoot = Join-Path $testRoot 'linked-install'
    [void](New-Item -ItemType Junction -Path $linkedRoot -Target $fixtureRoot)
    Assert-Throws { Assert-NetBoostMolePhysicalPath (Join-Path $linkedRoot 'child') } '*Refusing linked path*'
    [IO.Directory]::Delete($linkedRoot)
    Remove-Item Function:Invoke-WebRequest

    $script:choices = [Collections.Generic.Queue[string]]::new()
    foreach ($choice in @('1', '5', '0')) { $script:choices.Enqueue($choice) }
    $script:checks = 0
    $script:dispatches.Clear()
    Show-NetBoostMoleCenter -InputReader { $script:choices.Dequeue() } -InstallationReader { $installation }.GetNewClosure() `
        -ReleaseReader { $script:checks++; throw 'Offline fixture' } -ActionInvoker $fakeAction -PauseAction { }
    Assert-True ($script:checks -eq 2) 'Menu must recheck only on entry and explicit refresh.'
    Assert-True (($script:dispatches -join ',') -eq 'open') 'Offline menu must still open installed Mole without running cleanup.'
    $script:choices.Enqueue('0')
    $script:dispatches.Clear()
    Show-NetBoostMoleCenter -InputReader { $script:choices.Dequeue() } -InstallationReader { $missing }.GetNewClosure() `
        -ReleaseReader { $release }.GetNewClosure() -ActionInvoker $fakeAction -PauseAction { }
    Assert-True ($script:dispatches.Count -eq 0) 'Entering and leaving a missing-install menu must not auto-install.'
    foreach ($lang in @('VI', 'EN')) {
        $Language = $lang
        Assert-True ((Get-NetBoostMoleText).Install.Length -gt 0) 'Both languages must provide Mole labels.'
    }
    $RawArgs = @('--mole')
    Assert-True ((Parse-Args).Mode -eq 'Mole') '--mole must route to the management menu.'
    $script:choices.Enqueue('18'); $script:choices.Enqueue('0')
    $script:centerOpened = 0
    function Ensure-Admin { }
    Show-Menu -InputReader { $script:choices.Dequeue() } -MoleCenter { $script:centerOpened++ }
    Assert-True ($script:centerOpened -eq 1) 'Main-menu option 18 must open the Mole center exactly once.'
} finally {
    Set-Item -Path Function:Invoke-NetBoostMolePowerShell -Value $originalRunner
    if (Test-Path Function:Invoke-WebRequest) { Remove-Item Function:Invoke-WebRequest }
    if (Test-Path Function:Invoke-RestMethod) { Remove-Item Function:Invoke-RestMethod }
    foreach ($fake in @('Start-Process', 'scoop', 'winget.exe')) {
        if (Test-Path "Function:$fake") { Remove-Item "Function:$fake" }
    }
    $resolvedRoot = [IO.Path]::GetFullPath($testRoot)
    if ([IO.Path]::GetDirectoryName($resolvedRoot) -ne $testParent -or [IO.Path]::GetFileName($resolvedRoot) -notmatch '^netboost-mole-tests-[a-f0-9]{32}$') { throw 'Unsafe test fixture path.' }
    Remove-Item -LiteralPath $resolvedRoot -Recurse -Force
}
[pscustomobject]@{ ok = $true; assertions = $script:assertions; installedRealMole = $false; cleanupExecuted = $false } | ConvertTo-Json
