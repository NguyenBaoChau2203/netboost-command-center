#Requires -Version 5.1
# Optional portable Win11Debloat packages. Downloading never runs debloat.

function Get-NetBoostDebloatText {
    if ($Language -eq 'EN') {
        return @{
            Title = 'WIN11DEBLOAT MANAGER'; Source = 'Official source: https://github.com/Raphire/Win11Debloat'
            Missing = 'Win11Debloat is not downloaded.'; Installed = 'Local version'; Latest = 'Latest stable release'; Unknown = 'Unknown'
            Install = 'Download Win11Debloat (free)'; Open = 'Open interactive terminal menu'
            Preview = 'Preview selected changes (-WhatIf)'; Remove = 'Remove downloaded tool (does not undo Windows changes)'
            Check = 'Check GitHub for updates'; Update = 'Download newer version'; Back = 'Back to main menu'
            Confirm = 'Continue? Enter y to confirm (y/n)'; Cancelled = 'Operation cancelled.'
            InstallNotice = 'Download the official Win11Debloat package? No Windows tweaks will be applied.'
            OpenNotice = 'Win11Debloat can remove apps and change Windows settings. Open its interactive CLI?'
            UpdateNotice = 'Download the newer package? No Windows tweaks will be applied.'
            RemoveNotice = 'Remove only NetBoost-managed script files? Windows changes, registry backups, logs and saved settings are kept.'
            External = 'An existing external copy was found. Updates download a separate NetBoost-managed copy; the external folder is kept.'
            DataNotice = 'Removing the tool does not undo debloat. Backups and saved settings are kept.'
            Checking = 'Checking official GitHub releases...'; Downloading = 'Downloading and verifying Win11Debloat...'
            Offline = 'GitHub lookup failed. A downloaded copy can still be opened.'
            Failed = 'Win11Debloat action failed'; Done = 'Win11Debloat action completed.'
            UpToDate = 'No newer stable release is available.'; Location = 'Location'
            Kept = 'Kept files not owned by NetBoost in'; UnknownVersion = 'Cannot compare an unknown local version; update is unavailable.'
        }
    }
    return @{
        Title = 'QUAN LY WIN11DEBLOAT'; Source = 'Nguon chinh thuc: https://github.com/Raphire/Win11Debloat'
        Missing = 'Chua tai Win11Debloat.'; Installed = 'Phien ban tren may'; Latest = 'Ban on dinh moi nhat'; Unknown = 'Khong ro'
        Install = 'Tai Win11Debloat (mien phi)'; Open = 'Mo menu tuong tac tren terminal'
        Preview = 'Xem truoc thay doi (-WhatIf)'; Remove = 'Go bo cong cu (khong hoan tac thay doi Windows)'
        Check = 'Kiem tra cap nhat tren GitHub'; Update = 'Tai phien ban moi hon'; Back = 'Quay lai menu chinh'
        Confirm = 'Tiep tuc? Nhap y de xac nhan (y/n)'; Cancelled = 'Da huy thao tac.'
        InstallNotice = 'Tai goi Win11Debloat chinh thuc? Buoc nay khong ap dung thay doi Windows.'
        OpenNotice = 'Win11Debloat co the go ung dung va doi thiet lap Windows. Mo menu CLI tuong tac?'
        UpdateNotice = 'Tai goi moi hon? Buoc nay khong ap dung thay doi Windows.'
        RemoveNotice = 'Chi go tep script do NetBoost tai? Giu nguyen thay doi Windows, backup registry, log va cau hinh.'
        External = 'Tim thay ban co san ben ngoai. Cap nhat se tai ban rieng do NetBoost quan ly; giu nguyen thu muc cu.'
        DataNotice = 'Go cong cu khong hoan tac debloat. Backup va cau hinh duoc giu lai.'
        Checking = 'Dang kiem tra ban phat hanh GitHub chinh thuc...'; Downloading = 'Dang tai va kiem tra Win11Debloat...'
        Offline = 'Khong kiem tra duoc GitHub. Van co the mo ban da tai.'
        Failed = 'Thao tac Win11Debloat that bai'; Done = 'Da hoan tat thao tac Win11Debloat.'
        UpToDate = 'Khong co ban on dinh moi hon.'; Location = 'Vi tri'
        Kept = 'Giu lai tep khong thuoc NetBoost tai'; UnknownVersion = 'Khong doc duoc phien ban de so sanh; chua the cap nhat.'
    }
}

function ConvertTo-NetBoostDebloatVersion {
    param([string]$Value)
    $date = [datetime]::MinValue
    if ([datetime]::TryParseExact($Value, 'yyyy.MM.dd', [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::None, [ref]$date)) { return [version]$Value }
    return $null
}

function Get-NetBoostDebloatRoot {
    return Join-Path $env:LOCALAPPDATA 'Programs\NetBoost\Win11Debloat'
}

function Assert-NetBoostDebloatPath {
    param([string]$Path, [string]$Parent)
    $full = [IO.Path]::GetFullPath($Path)
    if ($Parent) {
        $prefix = [IO.Path]::GetFullPath($Parent).TrimEnd('\') + '\'
        if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Path escapes Win11Debloat scope: $Path" }
    }
    $current = $full
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            if ((Get-Item -LiteralPath $current -Force -ErrorAction Stop).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Refusing linked Win11Debloat path: $current"
            }
        }
        $parentPath = [IO.Path]::GetDirectoryName($current)
        if ($parentPath -eq $current) { break }
        $current = $parentPath
    }
}

function Get-NetBoostDebloatPackage {
    param([string]$Path)
    $entrypoint = Join-Path $Path 'Win11Debloat.ps1'
    foreach ($relative in @('Win11Debloat.ps1', 'Config\DefaultSettings.json', 'Scripts\CLI\Show-CliMenuOptions.ps1')) {
        if (-not (Test-Path -LiteralPath (Join-Path $Path $relative) -PathType Leaf)) { return $null }
    }
    $contents = Get-Content -LiteralPath $entrypoint -Raw -ErrorAction Stop
    $versionText = $null
    if ($contents -match '(?m)^\s*\$script:Version\s*=\s*["''](\d{4}\.\d{2}\.\d{2})["'']') { $versionText = $Matches[1] }
    # Older copies without CLI support must not accidentally open the GUI.
    if ($contents -notmatch '(?i)\[switch\]\s*\$CLI\b') { return $null }
    return [pscustomobject]@{
        Installed = $true; Root = [IO.Path]::GetFullPath($Path); ScriptPath = $entrypoint
        Version = (ConvertTo-NetBoostDebloatVersion $versionText); VersionText = $versionText; Managed = $false
        PreviewSupported = ($contents -match '(?i)CmdletBinding\s*\(\s*SupportsShouldProcess(?:\s*=\s*\$true)?\s*\)')
    }
}

function Get-NetBoostDebloatManagedPackages {
    $root = Get-NetBoostDebloatRoot
    $packages = Join-Path $root 'packages'
    if (-not (Test-Path -LiteralPath $packages -PathType Container)) { return }
    Assert-NetBoostDebloatPath $packages -Parent $root
    foreach ($directory in @(Get-ChildItem -LiteralPath $packages -Directory -ErrorAction Stop)) {
        if (-not (ConvertTo-NetBoostDebloatVersion $directory.Name)) { continue }
        Assert-NetBoostDebloatPath $directory.FullName -Parent $packages
        $marker = Join-Path $directory.FullName '.netboost-package.json'
        if (-not (Test-Path -LiteralPath $marker -PathType Leaf)) { continue }
        Assert-NetBoostDebloatPath $marker -Parent $directory.FullName
        $manifest = Get-Content -LiteralPath $marker -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ($manifest.Repository -ne 'Raphire/Win11Debloat' -or $manifest.Schema -ne 1 -or $manifest.Tag -cne $directory.Name -or
            @($manifest.Files).Count -eq 0 -or @($manifest.Files) -notcontains 'Win11Debloat.ps1') {
            throw "Invalid NetBoost Win11Debloat ownership record: $marker"
        }
        [pscustomobject]@{ Root = $directory.FullName; Manifest = $manifest }
    }
}

function Get-NetBoostDebloatInstallation {
    param([string[]]$CandidateRoots)
    foreach ($owned in @(Get-NetBoostDebloatManagedPackages | Sort-Object { ConvertTo-NetBoostDebloatVersion $_.Manifest.Tag } -Descending)) {
        $package = Get-NetBoostDebloatPackage $owned.Root
        if ($package -and $package.VersionText -ceq $owned.Manifest.Tag) { $package.Managed = $true; return $package }
    }
    if (-not $PSBoundParameters.ContainsKey('CandidateRoots')) {
        $CandidateRoots = @(
            (Join-Path $env:SystemDrive 'Win11Debloat'),
            (Join-Path ([IO.Path]::GetTempPath()) 'Win11Debloat'),
            (Join-Path $env:LOCALAPPDATA 'Win11Debloat'),
            (Join-Path $env:USERPROFILE 'Downloads\Win11Debloat')
        )
    }
    foreach ($path in $CandidateRoots) {
        if ([string]::IsNullOrWhiteSpace($path)) { continue }
        try { $package = Get-NetBoostDebloatPackage $path; if ($package) { return $package } } catch { continue }
    }
    return [pscustomobject]@{ Installed = $false; Root = (Get-NetBoostDebloatRoot); Version = $null; VersionText = $null; Managed = $false; PreviewSupported = $false }
}

function Select-NetBoostDebloatRelease {
    param([object[]]$Releases)
    $stable = @($Releases | Where-Object { -not $_.draft -and -not $_.prerelease -and (ConvertTo-NetBoostDebloatVersion $_.tag_name) } |
        Sort-Object { ConvertTo-NetBoostDebloatVersion $_.tag_name } -Descending)
    if ($stable.Count -eq 0) { return $null }
    $release = $stable[0]
    $assets = @($release.assets | Where-Object name -CEQ 'Win11Debloat.zip')
    if ($assets.Count -ne 1) { throw 'The latest stable release does not publish Win11Debloat.zip.' }
    $asset = $assets[0]
    $url = 'https://github.com/Raphire/Win11Debloat/releases/download/{0}/Win11Debloat.zip' -f $release.tag_name
    if ($asset.browser_download_url -cne $url -or $asset.digest -notmatch '^sha256:([a-fA-F0-9]{64})$') {
        throw 'The official Win11Debloat ZIP URL or SHA-256 digest is invalid.'
    }
    return [pscustomobject]@{ Tag = $release.tag_name; Version = (ConvertTo-NetBoostDebloatVersion $release.tag_name); AssetUrl = $url; Sha256 = $Matches[1].ToLowerInvariant() }
}

function Get-NetBoostDebloatRelease {
    for ($page = 1; $page -le 5; $page++) {
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/Raphire/Win11Debloat/releases?per_page=100&page=$page" `
            -Headers @{ 'User-Agent' = 'NetBoost-Command-Center'; Accept = 'application/vnd.github+json' } -TimeoutSec 15 -ErrorAction Stop
        $releases = @($response)
        $release = Select-NetBoostDebloatRelease -Releases $releases
        if ($release) { return $release }
        if ($releases.Count -lt 100) { break }
    }
    throw 'No stable Win11Debloat release was found on GitHub.'
}

function Test-NetBoostDebloatUpdate {
    param($Installation, $Release)
    return [bool]($Installation.Installed -and $Installation.Version -and $Release -and $Release.Version -gt $Installation.Version)
}

function Get-NetBoostDebloatActions {
    param($Installation, $Release)
    $text = Get-NetBoostDebloatText
    if ($Installation.Installed) {
        [pscustomobject]@{ Key = '1'; Action = 'open'; Label = $text.Open; Notice = $text.OpenNotice }
        if ($Installation.PreviewSupported) { [pscustomobject]@{ Key = '2'; Action = 'preview'; Label = $text.Preview; Notice = '' } }
        if ($Installation.Managed) { [pscustomobject]@{ Key = '4'; Action = 'remove'; Label = $text.Remove; Notice = $text.RemoveNotice } }
        if (Test-NetBoostDebloatUpdate $Installation $Release) {
            [pscustomobject]@{ Key = '6'; Action = 'update'; Label = ('{0} ({1} -> {2})' -f $text.Update, $Installation.VersionText, $Release.Tag); Notice = $text.UpdateNotice }
        }
    } elseif ($Release) {
        [pscustomobject]@{ Key = '1'; Action = 'install'; Label = $text.Install; Notice = $text.InstallNotice }
    }
    [pscustomobject]@{ Key = '5'; Action = 'check'; Label = $text.Check; Notice = '' }
}

function Invoke-NetBoostDebloatSelection {
    param([string]$Choice, $Installation, $Release,
        [scriptblock]$ReadInput = { param($Prompt) Read-UiInput $Prompt },
        [scriptblock]$ActionInvoker = { param($Action, $Install, $Latest) Invoke-NetBoostDebloatAction $Action $Install $Latest })
    if ($Choice -eq '0') { return 'back' }
    $action = Get-NetBoostDebloatActions $Installation $Release | Where-Object Key -eq $Choice | Select-Object -First 1
    if (-not $action) { return 'invalid' }
    if ($action.Action -eq 'check') { return 'check' }
    $text = Get-NetBoostDebloatText
    if ($action.Notice) {
        Write-Status Warning $action.Notice
        if ([string](& $ReadInput $text.Confirm) -ine 'y') { Write-Status Warning $text.Cancelled; return 'cancelled' }
    }
    & $ActionInvoker $action.Action $Installation $Release | Out-Null
    return 'completed'
}

function Remove-NetBoostDebloatTemporaryDirectory {
    param([string]$Path, [string]$Parent, [string]$Prefix)
    $full = [IO.Path]::GetFullPath($Path)
    if ([IO.Path]::GetDirectoryName($full) -ne [IO.Path]::GetFullPath($Parent).TrimEnd('\') -or
        [IO.Path]::GetFileName($full) -notmatch ('^' + [regex]::Escape($Prefix) + '[a-f0-9]{32}$')) { throw 'Unsafe Win11Debloat temporary directory.' }
    Assert-NetBoostDebloatPath $full -Parent $Parent
    if (Test-Path -LiteralPath $full) {
        # The scratch tree contains only archive data; refuse any linked entry.
        foreach ($item in @(Get-ChildItem -LiteralPath $full -Recurse -Force -ErrorAction Stop)) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Linked entry in Win11Debloat scratch directory.' }
        }
        Remove-Item -LiteralPath $full -Recurse -Force -ErrorAction Stop
    }
}

function Install-NetBoostDebloatRelease {
    param($Release)
    if (-not $Release -or -not (ConvertTo-NetBoostDebloatVersion $Release.Tag)) { throw 'Check for a stable Win11Debloat release first.' }
    $root = [IO.Path]::GetFullPath((Get-NetBoostDebloatRoot))
    $packages = Join-Path $root 'packages'
    $target = Join-Path $packages $Release.Tag
    Assert-NetBoostDebloatPath $target -Parent $packages
    if (Test-Path -LiteralPath $target) { throw "Refusing to overwrite an existing Win11Debloat package: $target" }
    $tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
    $work = Join-Path $tempParent ('netboost-debloat-' + [guid]::NewGuid().ToString('N'))
    $pending = Join-Path $packages ('.pending-' + [guid]::NewGuid().ToString('N'))
    Assert-NetBoostDebloatPath $work -Parent $tempParent
    [void](New-Item -ItemType Directory -Path $work -ErrorAction Stop)
    try {
        Write-Status Info (Get-NetBoostDebloatText).Downloading
        $archive = Join-Path $work 'Win11Debloat.zip'
        Invoke-WebRequest -UseBasicParsing -Uri $Release.AssetUrl -OutFile $archive -TimeoutSec 120 -ErrorAction Stop
        if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256 -ErrorAction Stop).Hash -ine $Release.Sha256) {
            throw 'Win11Debloat ZIP SHA-256 mismatch. No package was installed.'
        }
        $extract = Join-Path $work 'extracted'
        Expand-Archive -LiteralPath $archive -DestinationPath $extract -ErrorAction Stop
        $entries = @(Get-ChildItem -LiteralPath $extract -Filter Win11Debloat.ps1 -Recurse -File -ErrorAction Stop)
        if ($entries.Count -ne 1) { throw 'Unexpected Win11Debloat ZIP layout.' }
        $package = Get-NetBoostDebloatPackage $entries[0].DirectoryName
        if (-not $package -or $package.VersionText -cne $Release.Tag) { throw 'The Win11Debloat package version does not match its release.' }
        $files = @(Get-ChildItem -LiteralPath $package.Root -Recurse -File -Force -ErrorAction Stop | ForEach-Object {
            Assert-NetBoostDebloatPath $_.FullName -Parent $package.Root
            $_.FullName.Substring($package.Root.TrimEnd('\').Length + 1)
        })
        Assert-NetBoostDebloatPath $pending -Parent $packages
        [void](New-Item -ItemType Directory -Path $packages -Force -ErrorAction Stop)
        # Both resolved move targets are scoped above; old versions stay usable
        # until a complete package is committed by this final directory rename.
        Move-Item -LiteralPath $package.Root -Destination $pending -ErrorAction Stop
        $manifest = @{ Schema = 1; Repository = 'Raphire/Win11Debloat'; Tag = $Release.Tag; Files = $files }
        $manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $pending '.netboost-package.json') -Encoding UTF8 -ErrorAction Stop
        Assert-NetBoostDebloatPath $target -Parent $packages
        Move-Item -LiteralPath $pending -Destination $target -ErrorAction Stop
    } finally {
        Remove-NetBoostDebloatTemporaryDirectory $pending $packages '.pending-'
        Remove-NetBoostDebloatTemporaryDirectory $work $tempParent 'netboost-debloat-'
    }
}

function Remove-NetBoostDebloatPackages {
    $root = [IO.Path]::GetFullPath((Get-NetBoostDebloatRoot))
    $packages = Join-Path $root 'packages'
    $owned = @(Get-NetBoostDebloatManagedPackages)
    $plans = @()
    # Validate every ownership record and target before removing any files.
    foreach ($package in $owned) {
        $files = @()
        foreach ($relative in @($package.Manifest.Files)) {
            if ([string]::IsNullOrWhiteSpace($relative) -or [IO.Path]::IsPathRooted($relative) -or $relative.Contains(':')) { throw 'Invalid Win11Debloat ownership path.' }
            $path = [IO.Path]::GetFullPath((Join-Path $package.Root $relative))
            Assert-NetBoostDebloatPath $path -Parent $package.Root
            if (Test-Path -LiteralPath $path -PathType Container) { throw 'Ownership record contains a directory instead of a file.' }
            $files += $path
        }
        $files += Join-Path $package.Root '.netboost-package.json'
        $plans += [pscustomobject]@{ Root = $package.Root; Files = $files }
    }
    foreach ($plan in $plans) {
        $directories = @($plan.Root)
        foreach ($file in $plan.Files) {
            Assert-NetBoostDebloatPath $file -Parent $plan.Root
            if (Test-Path -LiteralPath $file -PathType Leaf) { Remove-Item -LiteralPath $file -Force -ErrorAction Stop }
            $parent = [IO.Path]::GetDirectoryName($file)
            while ($parent.Length -gt $plan.Root.Length) { $directories += $parent; $parent = [IO.Path]::GetDirectoryName($parent) }
        }
        foreach ($directory in @($directories | Sort-Object -Unique | Sort-Object Length -Descending)) {
            Assert-NetBoostDebloatPath $directory -Parent $packages
            if ((Test-Path -LiteralPath $directory -PathType Container) -and @(Get-ChildItem -LiteralPath $directory -Force).Count -eq 0) {
                [IO.Directory]::Delete($directory, $false)
            }
        }
        if (Test-Path -LiteralPath $plan.Root) { Write-Status Warning ('{0}: {1}' -f (Get-NetBoostDebloatText).Kept, $plan.Root) }
    }
    foreach ($directory in @($packages, $root)) {
        Assert-NetBoostDebloatPath $directory
        if ((Test-Path -LiteralPath $directory -PathType Container) -and @(Get-ChildItem -LiteralPath $directory -Force).Count -eq 0) {
            [IO.Directory]::Delete($directory, $false)
        }
    }
}

function Open-NetBoostDebloatWindow {
    param($Installation, [switch]$Preview)
    $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $arguments = '-NoLogo -NoProfile -NoExit -ExecutionPolicy Bypass -File "{0}" -CLI' -f $Installation.ScriptPath
    if ($Preview) { $arguments += ' -WhatIf' }
    Start-Process -FilePath $powershell -ArgumentList $arguments -WorkingDirectory $Installation.Root -WindowStyle Normal -ErrorAction Stop | Out-Null
}

function Invoke-NetBoostDebloatAction {
    param([ValidateSet('install', 'open', 'preview', 'update', 'remove')][string]$Action, $Installation, $Release)
    switch ($Action) {
        'install' {
            if ($Installation.Installed) { throw 'Win11Debloat is already available.' }
            Install-NetBoostDebloatRelease $Release
        }
        'update' {
            if (-not (Test-NetBoostDebloatUpdate $Installation $Release)) { throw 'No verified newer Win11Debloat release is available.' }
            Install-NetBoostDebloatRelease $Release
        }
        'remove' {
            if (-not $Installation.Managed) { throw 'Only NetBoost-managed Win11Debloat packages can be removed.' }
            Remove-NetBoostDebloatPackages
        }
        default {
            if (-not $Installation.Installed) { throw 'Win11Debloat is not available.' }
            if ($Action -eq 'preview' -and -not $Installation.PreviewSupported) { throw 'This copy does not support WhatIf preview.' }
            Open-NetBoostDebloatWindow $Installation -Preview:($Action -eq 'preview')
        }
    }
}

function Show-NetBoostDebloatCenter {
    param(
        [scriptblock]$InputReader = { param($Prompt) Read-UiInput $Prompt },
        [scriptblock]$InstallationReader = { Get-NetBoostDebloatInstallation },
        [scriptblock]$ReleaseReader = { Get-NetBoostDebloatRelease },
        [scriptblock]$ActionInvoker = { param($Action, $Install, $Latest) Invoke-NetBoostDebloatAction $Action $Install $Latest },
        [scriptblock]$PauseAction = { Pause-Back }
    )
    $release = $null; $checkError = $null; $checkRelease = $true
    while ($true) {
        $text = Get-NetBoostDebloatText
        if ($checkRelease) {
            Write-Status Info $text.Checking
            try { $release = & $ReleaseReader; $checkError = $null } catch { $release = $null; $checkError = $_.Exception.Message }
            $checkRelease = $false
        }
        try { $installation = & $InstallationReader } catch { Write-Status Error ('{0}: {1}' -f $text.Failed, $_.Exception.Message); return }
        Write-UiHeader $text.Title 'Tools'
        Write-Line $text.Source DarkGray
        Write-Line $text.DataNotice Yellow
        if ($installation.Installed) {
            $versionText = if ($installation.VersionText) { $installation.VersionText } else { $text.Unknown }
            Write-Line ('{0}: {1}' -f $text.Installed, $versionText) Green
            Write-Line ('{0}: {1}' -f $text.Location, $installation.Root) DarkGray
            if (-not $installation.Managed) { Write-Line $text.External Yellow }
            if (-not $installation.Version) { Write-Line $text.UnknownVersion Yellow }
        } else { Write-Status Info $text.Missing }
        if ($release) {
            Write-Line ('{0}: {1}' -f $text.Latest, $release.Tag) Cyan
            if ($installation.Version -and -not (Test-NetBoostDebloatUpdate $installation $release)) { Write-Line $text.UpToDate DarkGray }
        }
        if ($checkError) { Write-Status Warning ('{0} {1}' -f $text.Offline, $checkError) }
        foreach ($action in @(Get-NetBoostDebloatActions $installation $release)) { Write-MenuItem $action.Key $action.Label Cyan 'Tools' }
        Write-MenuItem '0' $text.Back Gray 'Exit'
        try {
            $result = Invoke-NetBoostDebloatSelection ([string](& $InputReader $T.PromptChoice)) $installation $release -ReadInput $InputReader -ActionInvoker $ActionInvoker
            if ($result -eq 'back') { return }
            if ($result -eq 'check') { $checkRelease = $true; continue }
            if ($result -eq 'invalid') { Write-Status Warning $T.InvalidChoice }
            if ($result -eq 'completed') { Write-Status Ok $text.Done }
        } catch { Write-Status Error ('{0}: {1}' -f $text.Failed, $_.Exception.Message) }
        & $PauseAction
    }
}
