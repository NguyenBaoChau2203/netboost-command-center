#Requires -Version 5.1
# Optional integration with the free Windows CLI. No upstream code is bundled.

function Get-NetBoostMoleText {
    if ($Language -eq 'EN') {
        return @{
            Title = 'MOLE CLI FOR WINDOWS'; Missing = 'Mole CLI is not installed.'
            Installed = 'Installed version'; Latest = 'Latest Windows release'; Unknown = 'Unknown'
            Install = 'Install Mole CLI (free)'; Open = 'Open Mole interactive menu'
            Preview = 'Preview cleanup (no deletion)'; Analyze = 'Explore disk usage'
            Remove = 'Uninstall Mole CLI'; Check = 'Check GitHub for updates'
            Update = 'Update Mole CLI'; Back = 'Back to main menu'
            Confirm = 'Continue? Enter y to confirm (y/n)'; Cancelled = 'Operation cancelled.'
            InstallNotice = 'Download and install the official Windows release from tw93/Mole?'
            UpdateNotice = 'Update this installation? Close other Mole windows first.'
            RemoveNotice = 'Uninstall Mole CLI? Mole may separately ask whether to keep its settings.'
            Source = 'Official source: https://github.com/tw93/Mole/tree/windows'
            Offline = 'Could not check GitHub. Installed Mole is still available.'
            Failed = 'Mole action failed'; Done = 'Mole action completed.'
            Location = 'Location'; UpToDate = 'No newer stable Windows release is available.'
            UnknownVersion = 'Cannot compare versions. Update is unavailable until the installed version can be read.'
            External = 'Updates and removal use the original installation method.'
            OpenNotice = 'Opening a separate Mole window. Choose any cleanup inside Mole yourself.'
            Download = 'Downloading and verifying the Windows release...'
            Checking = 'Checking official Windows releases on GitHub...'
        }
    }
    return @{
        Title = 'MOLE CLI CHO WINDOWS'; Missing = 'Chua cai dat Mole CLI.'
        Installed = 'Phien ban da cai'; Latest = 'Ban Windows moi nhat'; Unknown = 'Khong ro'
        Install = 'Cai dat Mole CLI (mien phi)'; Open = 'Mo menu tuong tac Mole'
        Preview = 'Xem truoc don dep (khong xoa tep)'; Analyze = 'Phan tich dung luong o dia'
        Remove = 'Go cai dat Mole CLI'; Check = 'Kiem tra cap nhat tren GitHub'
        Update = 'Cap nhat Mole CLI'; Back = 'Quay lai menu chinh'
        Confirm = 'Tiep tuc? Nhap y de xac nhan (y/n)'; Cancelled = 'Da huy thao tac.'
        InstallNotice = 'Tai va cai ban Windows chinh thuc tu tw93/Mole?'
        UpdateNotice = 'Cap nhat ban da cai? Hay dong cac cua so Mole khac truoc.'
        RemoveNotice = 'Go Mole CLI? Mole co the hoi rieng ve viec giu cau hinh.'
        Source = 'Nguon chinh thuc: https://github.com/tw93/Mole/tree/windows'
        Offline = 'Khong kiem tra duoc GitHub. Van co the mo Mole da cai.'
        Failed = 'Thao tac Mole that bai'; Done = 'Da hoan tat thao tac Mole.'
        Location = 'Vi tri'; UpToDate = 'Khong co ban Windows on dinh moi hon.'
        UnknownVersion = 'Khong doc duoc phien ban da cai de so sanh. Chua the cap nhat.'
        External = 'Cap nhat va go cai dat theo phuong thuc cai ban dau.'
        OpenNotice = 'Dang mo cua so Mole rieng. Ban tu chon thao tac don dep trong Mole.'
        Download = 'Dang tai va kiem tra ban phat hanh Windows...'
        Checking = 'Dang kiem tra ban Windows chinh thuc tren GitHub...'
    }
}

function ConvertTo-NetBoostMoleVersion {
    param([string]$Value)
    if ($Value -match '^[vV]?(\d+\.\d+\.\d+)(?:-windows)?$') {
        return [version]$Matches[1]
    }
    return $null
}

function Get-NetBoostMoleInstallRoot {
    return Join-Path $env:LOCALAPPDATA 'Programs\NetBoost\MoleCLI'
}

function Get-NetBoostMoleInstallation {
    param([string[]]$CandidateRoots)
    $scoopRoot = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $env:USERPROFILE 'scoop' }
    $globalScoop = if ($env:SCOOP_GLOBAL) { $env:SCOOP_GLOBAL } else { Join-Path $env:ProgramData 'scoop' }
    if (-not $PSBoundParameters.ContainsKey('CandidateRoots')) {
        $CandidateRoots = @(
            (Get-NetBoostMoleInstallRoot),
            (Join-Path $env:LOCALAPPDATA 'Programs\mole-cli'),
            (Join-Path $env:LOCALAPPDATA 'Mole')
        )
        # Read PATH entries without executing an unrelated command named mo.
        foreach ($entry in ($env:PATH -split ';')) {
            $entry = [Environment]::ExpandEnvironmentVariables($entry.Trim().Trim('"'))
            if ($entry -and [IO.Path]::IsPathRooted($entry)) { $CandidateRoots += $entry }
        }
        $CandidateRoots += Join-Path $scoopRoot 'apps\mole\current'
        $CandidateRoots += Join-Path $globalScoop 'apps\mole\current'
        foreach ($wingetRoot in @((Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'), (Join-Path $env:ProgramFiles 'WinGet\Packages'))) {
            if (Test-Path -LiteralPath $wingetRoot -PathType Container) {
                $CandidateRoots += @(Get-ChildItem -LiteralPath $wingetRoot -Directory -Filter 'tw93.MoleCLI_*' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
            }
        }
    }
    foreach ($root in @($CandidateRoots | Select-Object -Unique)) {
        if ([string]::IsNullOrWhiteSpace($root)) { continue }
        try {
            $root = [IO.Path]::GetFullPath($root)
            $entrypoint = Join-Path $root 'mole.ps1'
            if (-not (Test-Path -LiteralPath $entrypoint -PathType Leaf) -or
                -not (Test-Path -LiteralPath (Join-Path $root 'lib\core\base.ps1') -PathType Leaf)) { continue }
            $version = $null
            $versionPath = Join-Path $root 'VERSION'
            if (Test-Path -LiteralPath $versionPath -PathType Leaf) {
                try { $version = ConvertTo-NetBoostMoleVersion ((Get-Content -LiteralPath $versionPath -Raw -ErrorAction Stop).Trim()) } catch { $version = $null }
            }
            if (-not $version) {
                $versionHelper = Join-Path $root 'lib\core\version.ps1'
                if (Test-Path -LiteralPath $versionHelper -PathType Leaf) {
                    $contents = Get-Content -LiteralPath $versionHelper -Raw -ErrorAction SilentlyContinue
                    if ($contents -match '\$script:MoleDefaultVersion\s*=\s*"(\d+\.\d+\.\d+)"') {
                        $version = ConvertTo-NetBoostMoleVersion $Matches[1]
                    }
                }
            }
            $channel = 'release'
            if ($root -match '[\\/]scoop[\\/]apps[\\/]mole[\\/]' -or
                $root -like "$scoopRoot\apps\mole\*" -or $root -like "$globalScoop\apps\mole\*") { $channel = 'scoop' }
            elseif ($root -match '[\\/]WinGet[\\/]Packages[\\/]tw93\.MoleCLI_') { $channel = 'winget' }
            elseif (Test-Path -LiteralPath (Join-Path $root '.git')) { $channel = 'git' }
            return [pscustomobject]@{ Installed = $true; Root = $root; ScriptPath = $entrypoint; Version = $version; Channel = $channel }
        } catch { continue }
    }
    return [pscustomobject]@{ Installed = $false; Root = (Get-NetBoostMoleInstallRoot); ScriptPath = $null; Version = $null; Channel = 'release' }
}

function Select-NetBoostMoleRelease {
    param([object[]]$Releases, [string]$Architecture)
    $windowsReleases = @($Releases | Where-Object {
        -not $_.draft -and -not $_.prerelease -and $_.tag_name -match '^[vV]?\d+\.\d+\.\d+-windows$'
    } | Sort-Object { ConvertTo-NetBoostMoleVersion $_.tag_name } -Descending)
    if ($windowsReleases.Count -eq 0) { return $null }
    $release = $windowsReleases[0]
    $version = ConvertTo-NetBoostMoleVersion $release.tag_name
    $assetName = 'mole-{0}-{1}.zip' -f $version, $Architecture
    $assets = @($release.assets | Where-Object { $_.name -ceq $assetName })
    if ($assets.Count -ne 1) { throw "No official $Architecture Windows ZIP in $($release.tag_name)." }
    $asset = $assets[0]
    $expectedUrl = 'https://github.com/tw93/Mole/releases/download/{0}/{1}' -f $release.tag_name, $assetName
    if ($asset.browser_download_url -cne $expectedUrl -or $asset.digest -notmatch '^sha256:([a-fA-F0-9]{64})$') {
        throw 'The Windows release has no valid official download URL or SHA-256 digest.'
    }
    return [pscustomobject]@{
        Version = $version; Tag = $release.tag_name; AssetName = $assetName
        AssetUrl = $expectedUrl; Sha256 = $Matches[1].ToLowerInvariant()
    }
}

function Get-NetBoostMoleRelease {
    $processor = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
    $architecture = switch ($processor) {
        'AMD64' { 'x64' }; 'ARM64' { 'arm64' }; default { throw "Unsupported Windows architecture: $processor" }
    }
    # /releases/latest normally points to macOS. Search published Windows tags.
    for ($page = 1; $page -le 5; $page++) {
        # Invoke-RestMethod returns a JSON array as one pipeline object. Assign
        # before normalizing it, otherwise @(...command...) creates a nested array.
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/tw93/Mole/releases?per_page=100&page=$page" `
            -Headers @{ 'User-Agent' = 'NetBoost-Command-Center'; Accept = 'application/vnd.github+json' } -TimeoutSec 15 -ErrorAction Stop
        $releases = @($response)
        $release = Select-NetBoostMoleRelease -Releases $releases -Architecture $architecture
        if ($release) { return $release }
        if ($releases.Count -lt 100) { break }
    }
    throw 'No stable Windows release was found on GitHub.'
}

function Test-NetBoostMoleUpdate {
    param($Installation, $Release)
    return [bool]($Installation.Installed -and $Installation.Version -and $Release -and $Release.Version -gt $Installation.Version)
}

function Get-NetBoostMoleActions {
    param($Installation, $Release)
    $text = Get-NetBoostMoleText
    $actions = @()
    if ($Installation.Installed) {
        $actions += [pscustomobject]@{ Key = '1'; Action = 'open'; Label = $text.Open; Notice = '' }
        $actions += [pscustomobject]@{ Key = '2'; Action = 'preview'; Label = $text.Preview; Notice = '' }
        $actions += [pscustomobject]@{ Key = '3'; Action = 'analyze'; Label = $text.Analyze; Notice = '' }
        $actions += [pscustomobject]@{ Key = '4'; Action = 'remove'; Label = $text.Remove; Notice = $text.RemoveNotice }
        if (Test-NetBoostMoleUpdate -Installation $Installation -Release $Release) {
            $actions += [pscustomobject]@{ Key = '6'; Action = 'update'; Label = ('{0} ({1} -> {2})' -f $text.Update, $Installation.Version, $Release.Version); Notice = $text.UpdateNotice }
        }
    } elseif ($Release) {
        $actions += [pscustomobject]@{ Key = '1'; Action = 'install'; Label = $text.Install; Notice = $text.InstallNotice }
    }
    $actions += [pscustomobject]@{ Key = '5'; Action = 'check'; Label = $text.Check; Notice = '' }
    return $actions
}

function Invoke-NetBoostMoleSelection {
    param(
        [string]$Choice, $Installation, $Release,
        [scriptblock]$ReadInput = { param($Prompt) Read-UiInput $Prompt },
        [scriptblock]$ActionInvoker = { param($Action, $Install, $Latest) Invoke-NetBoostMoleAction -Action $Action -Installation $Install -Release $Latest }
    )
    if ($Choice -eq '0') { return 'back' }
    $action = Get-NetBoostMoleActions -Installation $Installation -Release $Release | Where-Object Key -eq $Choice | Select-Object -First 1
    if (-not $action) { return 'invalid' }
    if ($action.Action -eq 'check') { return 'check' }
    $text = Get-NetBoostMoleText
    if ($action.Notice) {
        Write-Status Warning $action.Notice
        if ([string](& $ReadInput $text.Confirm) -ine 'y') {
            Write-Status Warning $text.Cancelled
            return 'cancelled'
        }
    }
    & $ActionInvoker $action.Action $Installation $Release | Out-Null
    return 'completed'
}

function Assert-NetBoostMolePhysicalPath {
    param([string]$Path)
    $current = [IO.Path]::GetFullPath($Path)
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Refusing linked path: $current" }
        }
        $parent = [IO.Path]::GetDirectoryName($current)
        if ($parent -eq $current) { break }
        $current = $parent
    }
}

function Invoke-NetBoostMolePowerShell {
    param([string]$ScriptPath, [string[]]$Arguments = @(), [switch]$OpenWindow)
    $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if ($OpenWindow) {
        # Arguments here are fixed internal commands; paths go only to -File.
        $argumentLine = '-NoLogo -NoProfile -NoExit -ExecutionPolicy Bypass -File "{0}" {1}' -f $ScriptPath, ($Arguments -join ' ')
        Start-Process -FilePath $powershell -ArgumentList $argumentLine -WindowStyle Normal -ErrorAction Stop | Out-Null
        return
    }
    & $powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Arguments | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Mole exited with code $LASTEXITCODE." }
}

function Install-NetBoostMoleRelease {
    param($Release, $Installation)
    if (-not $Release) { throw 'Check GitHub for a Windows release first.' }
    $root = [IO.Path]::GetFullPath($Installation.Root)
    Assert-NetBoostMolePhysicalPath $root
    if (Test-Path -LiteralPath $root) {
        $existing = Get-NetBoostMoleInstallation -CandidateRoots @($root)
        if (-not $existing.Installed) { throw "Refusing to overwrite a folder without a Mole installation: $root" }
    }
    $tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
    $work = Join-Path $tempParent ('netboost-mole-' + [guid]::NewGuid().ToString('N'))
    Assert-NetBoostMolePhysicalPath $work
    [void](New-Item -ItemType Directory -Path $work -ErrorAction Stop)
    try {
        Write-Status Info (Get-NetBoostMoleText).Download
        $archive = Join-Path $work $Release.AssetName
        Invoke-WebRequest -UseBasicParsing -Uri $Release.AssetUrl -OutFile $archive -TimeoutSec 120 -ErrorAction Stop
        $hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256 -ErrorAction Stop).Hash
        if ($hash -ine $Release.Sha256) { throw 'Mole ZIP SHA-256 mismatch. Nothing was installed.' }
        $extract = Join-Path $work 'extracted'
        Expand-Archive -LiteralPath $archive -DestinationPath $extract -ErrorAction Stop
        $installers = @(Get-ChildItem -LiteralPath $extract -Filter install.ps1 -Recurse -File -ErrorAction Stop | Where-Object {
            Test-Path -LiteralPath (Join-Path $_.DirectoryName 'mole.ps1') -PathType Leaf
        })
        if ($installers.Count -ne 1) { throw 'The release ZIP has an unexpected installer layout.' }
        $package = Get-NetBoostMoleInstallation -CandidateRoots @($installers[0].DirectoryName)
        if (-not $package.Installed -or $package.Version -ne $Release.Version) { throw 'The ZIP version does not match the selected Windows release.' }
        $arguments = @('-InstallDir', $root, '-AddToPath')
        if ($Installation.Installed) { $arguments += '-Force' }
        Invoke-NetBoostMolePowerShell -ScriptPath $installers[0].FullName -Arguments $arguments
        $installed = Get-NetBoostMoleInstallation -CandidateRoots @($root)
        if (-not $installed.Installed -or $installed.Version -ne $Release.Version) { throw 'The installed Mole version could not be verified.' }
    } finally {
        # Only this invocation's resolved temporary directory may be removed.
        $resolvedWork = [IO.Path]::GetFullPath($work)
        if ([IO.Path]::GetDirectoryName($resolvedWork) -ne $tempParent -or
            [IO.Path]::GetFileName($resolvedWork) -notmatch '^netboost-mole-[a-f0-9]{32}$') { throw 'Unsafe Mole temporary directory.' }
        Assert-NetBoostMolePhysicalPath $resolvedWork
        Remove-Item -LiteralPath $resolvedWork -Recurse -Force -ErrorAction Stop
    }
}

function Invoke-NetBoostMoleAction {
    param([ValidateSet('install', 'open', 'preview', 'analyze', 'update', 'remove')][string]$Action, $Installation, $Release)
    if ($Action -eq 'install') {
        if ($Installation.Installed) { throw 'Mole is already installed.' }
        Install-NetBoostMoleRelease -Release $Release -Installation $Installation
        return
    }
    if (-not $Installation.Installed) { throw 'Mole CLI is not installed.' }
    switch ($Action) {
        { $_ -in @('open', 'preview', 'analyze') } {
            $arguments = switch ($Action) { 'preview' { @('clean', '--dry-run') }; 'analyze' { @('analyze') }; default { @() } }
            Write-Status Info (Get-NetBoostMoleText).OpenNotice
            Invoke-NetBoostMolePowerShell -ScriptPath $Installation.ScriptPath -Arguments @($arguments) -OpenWindow
            return
        }
        'update' {
            if (-not (Test-NetBoostMoleUpdate -Installation $Installation -Release $Release)) { throw 'No verified newer Windows release is available.' }
        }
    }
    if ($Installation.Channel -in @('scoop', 'winget')) {
        if ($Installation.Channel -eq 'scoop') {
            $manager = Get-Command scoop -ErrorAction Stop
            $verb = if ($Action -eq 'remove') { 'uninstall' } else { 'update' }
            & $manager $verb mole | Out-Host
        } else {
            $verb = if ($Action -eq 'remove') { 'uninstall' } else { 'upgrade' }
            & winget.exe $verb --id tw93.MoleCLI --exact --source winget | Out-Host
        }
        if ($LASTEXITCODE -ne 0) { throw "$($Installation.Channel) exited with code $LASTEXITCODE." }
    } elseif ($Action -eq 'remove') {
        Invoke-NetBoostMolePowerShell -ScriptPath (Join-Path $Installation.Root 'install.ps1') -Arguments @('-InstallDir', $Installation.Root, '-Uninstall')
    } elseif ($Installation.Channel -eq 'git') {
        Invoke-NetBoostMolePowerShell -ScriptPath $Installation.ScriptPath -Arguments @('update')
    } else {
        Install-NetBoostMoleRelease -Release $Release -Installation $Installation
    }
}

function Show-NetBoostMoleCenter {
    param(
        [scriptblock]$InputReader = { param($Prompt) Read-UiInput $Prompt },
        [scriptblock]$InstallationReader = { Get-NetBoostMoleInstallation },
        [scriptblock]$ReleaseReader = { Get-NetBoostMoleRelease },
        [scriptblock]$ActionInvoker = { param($Action, $Install, $Latest) Invoke-NetBoostMoleAction -Action $Action -Installation $Install -Release $Latest },
        [scriptblock]$PauseAction = { Pause-Back }
    )
    $release = $null
    $checkRelease = $true
    $checkError = $null
    while ($true) {
        $text = Get-NetBoostMoleText
        if ($checkRelease) {
            Write-Status Info $text.Checking
            try { $release = & $ReleaseReader; $checkError = $null }
            catch { $release = $null; $checkError = $_.Exception.Message }
            $checkRelease = $false
        }
        $installation = & $InstallationReader
        Write-UiHeader $text.Title 'Tools'
        Write-Line $text.Source DarkGray
        if ($installation.Installed) {
            $label = if ($installation.Version) { [string]$installation.Version } else { $text.Unknown }
            Write-Line ('{0}: {1}' -f $text.Installed, $label) Green
            Write-Line ('{0}: {1}' -f $text.Location, $installation.Root) DarkGray
            if ($installation.Channel -ne 'release') { Write-Line $text.External DarkGray }
            if (-not $installation.Version) { Write-Status Warning $text.UnknownVersion }
        } else { Write-Status Info $text.Missing }
        if ($release) {
            Write-Line ('{0}: {1}' -f $text.Latest, $release.Version) Cyan
            if ($installation.Version -and -not (Test-NetBoostMoleUpdate -Installation $installation -Release $release)) { Write-Line $text.UpToDate DarkGray }
        }
        if ($checkError) { Write-Status Warning ("{0} {1}" -f $text.Offline, $checkError) }
        foreach ($action in @(Get-NetBoostMoleActions -Installation $installation -Release $release)) {
            Write-MenuItem $action.Key $action.Label Cyan 'Tools'
        }
        Write-MenuItem '0' $text.Back Gray 'Exit'
        try {
            $choice = [string](& $InputReader $T.PromptChoice)
            $result = Invoke-NetBoostMoleSelection -Choice $choice -Installation $installation -Release $release -ReadInput $InputReader -ActionInvoker $ActionInvoker
            if ($result -eq 'back') { return }
            if ($result -eq 'check') { $checkRelease = $true; continue }
            if ($result -eq 'invalid') { Write-Status Warning $T.InvalidChoice }
            if ($result -eq 'completed') { Write-Status Ok $text.Done }
        } catch { Write-Status Error ('{0}: {1}' -f $text.Failed, $_.Exception.Message) }
        & $PauseAction
    }
}
