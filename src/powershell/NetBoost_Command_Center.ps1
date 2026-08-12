#Requires -Version 5.1
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new()

$AppName = 'NetBoost Command Center'
$TaskName = 'NetBoost Auto DNS Optimizer'
$ScriptPath = $PSCommandPath
$RawArgs = @($args)
$DefaultScanRoot = $env:USERPROFILE
$UseFancyUi = $false
$UseAsciiUi = -not $UseFancyUi

# Global Language Configuration (VI: Vietnamese without accents, EN: English)
$Language = 'VI'

# Rapid command-line argument scanning for dynamic language selection
for ($i = 0; $i -lt $RawArgs.Count; $i++) {
    $arg = $RawArgs[$i].ToLowerInvariant()
    if ($arg -eq '--lang' -or $arg -eq '-lang') {
        if ($i + 1 -lt $RawArgs.Count) {
            $val = $RawArgs[$i + 1].ToUpperInvariant()
            if ($val -eq 'EN' -or $val -eq 'VI') {
                $Language = $val
            }
        }
    }
}

# Translation Dictionary (Localizations strictly in clean, accentless strings)
$T = @{}
if ($Language -eq 'EN') {
    $T.HeaderSubtitle = "Quick view: dashboard does not auto-run, view it by selecting option 16."
    $T.NetworkSec     = "Network / DNS"
    $T.CleanupSec     = "Cleanup"
    $T.ToolsSec       = "Tools"
    $T.PromptChoice   = "Select option"
    $T.InvalidChoice  = "Invalid option."
    $T.PressAnyKey    = "Press any key to return to menu..."

    # Menu Items
    $T.Menu1  = "Auto-select lowest ping DNS right now"
    $T.Menu2  = "Force Google DNS (8.8.8.8 / 8.8.4.4)"
    $T.Menu3  = "Force Cloudflare DNS (1.1.1.1 / 1.0.0.1)"
    $T.Menu4  = "View current DNS status"
    $T.Menu5  = "Create scheduled task for Auto DNS at logon"
    $T.Menu6  = "Remove scheduled task for Auto DNS"
    $T.Menu7  = "Flush DNS cache"
    $T.Menu8  = "Reset DNS to DHCP/Auto"
    $T.Menu9  = "Clear ALL system caches & Recycle Bin"
    $T.Menu10 = "Clean Windows & User temporary files"
    $T.Menu11 = "Clean Game & Graphics cache"
    $T.Menu12 = "Clean System cache"
    $T.Menu13 = "Empty Recycle Bin"
    $T.Menu14 = "Open Chris Titus WinUtil"
    $T.Menu15 = "Scan npm projects for pnpm migration"
    $T.Menu16 = "View telemetry Dashboard"
    $T.Menu17 = "Switch interface language to Vietnamese"
    $T.Menu18 = "Open Web UI (local browser)"
    $T.Menu0  = "Exit program"

    # Task Outputs & Alerts
    $T.AdminRequired  = "Administrator privileges required. Relaunching..."
    $T.NoAdapter      = "No online network adapter found."
    $T.DnsStatusHead  = "DNS STATUS"
    $T.DnsStatusAuto  = "DHCP/Auto or no IPv4 DNS configured"
    $T.CardAdapter    = "Adapter"
    $T.CardStatus     = "Status"
    $T.CardDns        = "DNS IPv4"
    $T.CardTask       = "Auto DNS Task"
    $T.CardRuntime    = "Environment"
    $T.CardTime       = "Time"

    $T.PingTestStart  = "Pinging 6 samples each. Lowest average will be set."
    $T.PingTimeout    = "timeout / no ping samples"
    $T.PingFailBoth   = "Both Google and Cloudflare timed out. DNS unmodified."
    $T.DnsWin         = "{0} is faster: {1} ms vs {2} ms"
    $T.DnsTie         = "Both providers tied at {0} ms. Keeping current DNS."

    $T.ApplyDns       = "Applying DNS configuration for: {0}"
    $T.ApplyProvider  = "Provider"
    $T.ApplyDone      = "DNS successfully updated and cache flushed."
    $T.ResetDns       = "Resetting DNS configuration for: {0}"
    $T.ResetDone      = "DNS successfully reset to DHCP/Auto and cache flushed."

    $T.TaskCreated    = "Scheduled task created: {0} (delayed 30s at logon)"
    $T.TaskNoTask     = "No scheduled Auto DNS task exists to remove."
    $T.TaskRemoved    = "Scheduled task successfully removed: {0}"

    $T.WinUtilWarn    = "WARNING: This will download and run winutil from GitHub."
    $T.WinUtilSource  = "Source: https://github.com/ChrisTitusTech/winutil"
    $T.ConfirmPrompt  = "Continue? Enter y to confirm (y/n)"
    $T.ConfirmAll     = "This clears ALL caches + Recycle Bin. Continue? (y/n)"
    $T.ActionSkipped  = "Operation skipped."
    $T.OpeningWinUtil = "Opening Chris Titus WinUtil..."

    $T.CleanRunHead   = "Cleaning: {0}"
    $T.CleanFolderNotFound = "Folder not found: {0}"
    $T.CleanSummary   = "CLEANUP SUMMARY: {0}"
    $T.CleanFilesDel  = "Files deleted"
    $T.CleanDirsDel   = "Folders deleted"
    $T.CleanFilesLock = "Locked files"
    $T.CleanDirsLock  = "Locked folders"
    $T.NotMeasurable  = "cannot measure"

    $T.CleanRecycleBin = "EMPTYING RECYCLE BIN"
    $T.CleanBinDone   = "Recycle Bin successfully emptied."
    $T.CleanBinEmpty  = "Recycle Bin is empty or some items are locked."

    $T.DashHead       = "NETBOOST DASHBOARD"
    $T.ScanHead       = "NPM TO PNPM MIGRATION SCAN"
    $T.ScanInfo       = "This mode scans and reports only. No files are deleted."
    $T.ScanNodeMissing = "Node : not found in PATH"
    $T.ScanNpmMissing  = "npm  : not found in PATH"
    $T.ScanPnpmMissing = "pnpm : not found in PATH"
    $T.ScanGlobalRoot = "Global root"
    $T.ScanCacheSize  = "Cache size"
    $T.ScanGlobalHead = "NPM GLOBAL CONFIG"
    $T.ScanGlobPack   = "NPM GLOBAL PACKAGES"
    $T.ScanNoPack     = "No global packages found."
    $T.ScanReadError  = "Failed to read npm global packages list."
    $T.ScanProjRoot   = "PROJECT SCAN - Root: {0}"
    $T.ScanProjNone   = "No Node/npm projects found in this root."
    $T.ScanProjFound  = "Found: {0} Node-related projects/folders"
    $T.ScanScanned    = "Folders scanned"
    $T.ScanLimit      = "Warning: hit 50000 limit, please scan smaller paths."
    $T.ScanMoreItems  = "... and {0} more items"

    $T.MigrateHead    = "MIGRATION ADVICE"
    $T.MigrateLock    = "Projects with package-lock/shrinkwrap"
    $T.MigrateNm      = "Projects with node_modules"
    $T.MigrateStep1   = "In each project folder: run 'pnpm import', then run 'pnpm install'."
    $T.MigrateStep2   = "Global tools: reinstall using 'pnpm add -g <package-name>' when needed."
    $T.MigrateStep3   = "Safe tip: only delete node_modules/package-lock manually after verifying builds."
    $T.WebStarting      = "Starting local Web UI backend server..."
    $T.WebRunning       = "NetBoost Command Center local backend is running."
    $T.WebBrowserOpen   = "Opening your default web browser..."
    $T.WebBrowserErr    = "Could not open browser automatically. Please open the URL manually."
    $T.WebKeepOpen      = "Keep this command prompt window open while using the Web UI."
    $T.WebAccessAt      = "You can access the Web UI at: {0}"
    $T.WebPressToStop   = "Press Q or ESC to stop the Web UI and return to the main CLI menu."
} else {
    # Default: VI (Vietnamese without accents)
    $T.HeaderSubtitle = "Mo nhanh: dashboard khong tu chay, chi xem khi ban chon muc 16."
    $T.NetworkSec     = "Network / DNS"
    $T.CleanupSec     = "Cleanup"
    $T.ToolsSec       = "Tools"
    $T.PromptChoice   = "Chon muc (Select option)"
    $T.InvalidChoice  = "Lua chon khong hop le."
    $T.PressAnyKey    = "Nhan phim bat ky de quay lai menu..."

    # Menu Items
    $T.Menu1  = "Auto chon DNS ping thap hon ngay bay gio"
    $T.Menu2  = "Ep Google DNS (8.8.8.8 / 8.8.4.4)"
    $T.Menu3  = "Ep Cloudflare DNS (1.1.1.1 / 1.0.0.1)"
    $T.Menu4  = "Xem DNS hien tai"
    $T.Menu5  = "Tao lich auto DNS khi dang nhap"
    $T.Menu6  = "Xoa lich auto DNS"
    $T.Menu7  = "Xoa bo nho dem DNS (Flush DNS)"
    $T.Menu8  = "Dat lai DNS ve DHCP/Auto"
    $T.Menu9  = "Xoa TAT CA bo nho dem (Cache)"
    $T.Menu10 = "Don dep tep tin tam Windows & Nguoi dung"
    $T.Menu11 = "Don dep bo nho dem Game & Do hoa"
    $T.Menu12 = "Don dep bo nho dem He thong"
    $T.Menu13 = "Lam trong Thung rac (Recycle Bin)"
    $T.Menu14 = "Mo Chris Titus WinUtil"
    $T.Menu15 = "Quet cac du an npm de chuyen sang pnpm"
    $T.Menu16 = "Xem bang thong tin (Dashboard)"
    $T.Menu17 = "Switch interface language to English"
    $T.Menu18 = "Mo giao dien Web UI (trinh duyet local)"
    $T.Menu0  = "Thoat chuong trinh"

    # Task Outputs & Alerts
    $T.AdminRequired  = "Can quyen Administrator cho tac vu nay. Dang mo lai..."
    $T.NoAdapter      = "Khong tim thay adapter mang dang online."
    $T.DnsStatusHead  = "TRANG THAI DNS (DNS STATUS)"
    $T.DnsStatusAuto  = "DHCP/Auto hoac chua co IPv4 DNS"
    $T.CardAdapter    = "Bo chuyen hop"
    $T.CardStatus     = "Trang thai"
    $T.CardDns        = "DNS IPv4"
    $T.CardTask       = "Auto DNS Task"
    $T.CardRuntime    = "Moi truong"
    $T.CardTime       = "Thoi gian"

    $T.PingTestStart  = "Do ping 6 mau moi ben. Ben nao thap hon thi doi ngay."
    $T.PingTimeout    = "timeout / khong co mau ping"
    $T.PingFailBoth   = "Ca Google va Cloudflare deu khong ping duoc. Khong doi DNS."
    $T.DnsWin         = "{0} thap hon: {1} ms vs {2} ms"
    $T.DnsTie         = "Hai ben bang nhau o {0} ms. Giu DNS hien tai."

    $T.ApplyDns       = "Ap dung cau hinh DNS cho: {0}"
    $T.ApplyProvider  = "Nha cung cap"
    $T.ApplyDone      = "Da doi DNS va flush DNS cache thanh cong."
    $T.ResetDns       = "Dat lai DNS cho Adapter: {0}"
    $T.ResetDone      = "Da reset DNS ve DHCP/Auto va flush DNS cache."

    $T.TaskCreated    = "Da tao lich: {0} (cho 30s sau logon de network san sang)"
    $T.TaskNoTask     = "Chua co lich Auto DNS de xoa."
    $T.TaskRemoved    = "Da xoa lich thanh cong: {0}"

    $T.WinUtilWarn    = "CANH BAO: Lenh nay se tai va chay script tu GitHub (winutil)."
    $T.WinUtilSource  = "Nguon: https://github.com/ChrisTitusTech/winutil"
    $T.ConfirmPrompt  = "Tiep tuc? Nhap y de xac nhan (y/n)"
    $T.ConfirmAll     = "Hanh dong nay se xoa sach cache + Recycle Bin. Tiep tuc? (y/n)"
    $T.ActionSkipped  = "Da huy thao tac."
    $T.OpeningWinUtil = "Dang mo Chris Titus WinUtil..."

    $T.CleanRunHead   = "Dang don dep: {0}"
    $T.CleanFolderNotFound = "Khong tim thay thu muc: {0}"
    $T.CleanSummary   = "TOM TAT: {0}"
    $T.CleanFilesDel  = "Tep tin da xoa"
    $T.CleanDirsDel   = "Thu muc da xoa"
    $T.CleanFilesLock = "Tep tin bi khoa"
    $T.CleanDirsLock  = "Thu muc bi khoa"
    $T.NotMeasurable  = "khong do duoc"

    $T.CleanRecycleBin = "DON DEP THUNG RAC"
    $T.CleanBinDone   = "Da don sach Recycle Bin."
    $T.CleanBinEmpty  = "Recycle Bin trong hoac co muc dang bi khoa."

    $T.DashHead       = "BANG THONG TIN (NETBOOST DASHBOARD)"
    $T.ScanHead       = "QUET DU AN NPM SANG PNPM (NPM TO PNPM SCAN)"
    $T.ScanInfo       = "Che do nay chi quet va bao cao, khong xoa file."
    $T.ScanNodeMissing = "Node : chua tim thay trong PATH"
    $T.ScanNpmMissing  = "npm  : chua tim thay trong PATH"
    $T.ScanPnpmMissing = "pnpm : chua tim thay trong PATH"
    $T.ScanGlobalRoot = "Global root"
    $T.ScanCacheSize  = "Cache size"
    $T.ScanGlobalHead = "CAU HINH NPM GLOBAL / CACHE"
    $T.ScanGlobPack   = "THU VIEN NPM GLOBAL PACKAGES"
    $T.ScanNoPack     = "Khong thay package global nao."
    $T.ScanReadError  = "Khong doc duoc danh sach npm global packages."
    $T.ScanProjRoot   = "QUET DU AN / PROJECT SCAN - Thu muc: {0}"
    $T.ScanProjNone   = "Khong thay dau vet npm/project Node nao trong thu muc nay."
    $T.ScanProjFound  = "Tim thay: {0} project/thu muc lien quan Node"
    $T.ScanScanned    = "Da quet"
    $T.ScanLimit      = "Canh bao: dat gioi han 50000 thu muc, nen quet tung thu muc nho hon."
    $T.ScanMoreItems  = "... con {0} muc nua"

    $T.MigrateHead    = "GOI Y CHUYEN DOI / MIGRATE ADVICE"
    $T.MigrateLock    = "Project co package-lock/npm-shrinkwrap"
    $T.MigrateNm      = "Project co node_modules"
    $T.MigrateStep1   = "Trong tung project: chay 'pnpm import', sau do pnpm install."
    $T.MigrateStep2   = "Global tool: cai lai bang pnpm add -g <ten-package> khi can."
    $T.MigrateStep3   = "Sau khi test OK moi tu tay xoa node_modules/package-lock de giai phong dung luong."
    $T.WebStarting      = "Dang khoi dong server Web UI local..."
    $T.WebRunning       = "NetBoost Command Center local backend dang hoat dong."
    $T.WebBrowserOpen   = "Dang tu dong mo trinh duyet..."
    $T.WebBrowserErr    = "Khong the tu dong mo trinh duyet. Vui long tu truy cap URL."
    $T.WebKeepOpen      = "Giu nguyen cua so nay (command prompt) khi dang dung Web UI."
    $T.WebAccessAt      = "Ban co the truy cap Web UI tai: {0}"
    $T.WebPressToStop   = "Nhan phim Q hoac ESC de dung Web UI va quay lai menu."
}

$Providers = @{
    Google = @{
        Label = 'Google'
        Primary = '8.8.8.8'
        Secondary = '8.8.4.4'
    }
    Cloudflare = @{
        Label = 'Cloudflare'
        Primary = '1.1.1.1'
        Secondary = '1.0.0.1'
    }
}

function Write-Line {
    param(
        [string]$Text = '',
        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )
    Write-Host (Convert-UiText $Text) -ForegroundColor $Color
}

function Convert-UiText {
    param([string]$Text)

    if (-not $UseAsciiUi -or [string]::IsNullOrEmpty($Text)) {
        return $Text
    }

    $normalized = $Text.Normalize([Text.NormalizationForm]::FormD)
    $builder = [Text.StringBuilder]::new()

    foreach ($char in $normalized.ToCharArray()) {
        $category = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($char)
        if ($category -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$builder.Append($char)
        }
    }

    return $builder.ToString().
        Replace([string][char]0x0111, 'd').
        Replace([string][char]0x0110, 'D')
}

function Read-UiInput {
    param([string]$Prompt)

    return Read-Host (Convert-UiText $Prompt)
}

function Get-UiIcon {
    param([string]$IconName)

    if (-not $UseFancyUi) {
        switch ($IconName) {
            'Network'      { return '[Net]' }
            'AutoDns'      { return '[Auto]' }
            'Dns'          { return '[DNS]' }
            'Cleanup'      { return '[Clean]' }
            'Tools'        { return '[Tools]' }
            'Ok'           { return '[OK]' }
            'Warning'      { return '[!]' }
            'Error'        { return '[ERR]' }
            'Scan'         { return '[Scan]' }
            'Test'         { return '[Test]' }
            'Reset'        { return '[Reset]' }
            'RecycleBin'   { return '[Bin]' }
            'Adapter'      { return '[Adapter]' }
            'Task'         { return '[Task]' }
            'Runtime'      { return '[Env]' }
            'Arrow'        { return '->' }
            'Bullet'       { return '-' }
            'Header'       { return '===' }
            'AllCache'     { return '[All]' }
            'TempCache'    { return '[Temp]' }
            'GameCache'    { return '[Game]' }
            'SysCache'     { return '[Sys]' }
            'WinUtil'      { return '[Tool]' }
            'NpmScan'      { return '[Npm]' }
            'Dashboard'    { return '[Dash]' }
            'Web'          { return '[Web]' }
            'Exit'         { return '[Exit]' }
            default        { return '' }
        }
    } else {
        switch ($IconName) {
            'Network'      { return '🌐' }
            'AutoDns'      { return '⚡' }
            'Dns'          { return '🧬' }
            'Cleanup'      { return '🧹' }
            'Tools'        { return '🧰' }
            'Ok'           { return '✅' }
            'Warning'      { return '⚠️' }
            'Error'        { return '❌' }
            'Scan'         { return '🔍' }
            'Test'         { return '🧪' }
            'Reset'        { return '🔄' }
            'RecycleBin'   { return '🗑️' }
            'Adapter'      { return '🔌' }
            'Task'         { return '📅' }
            'Runtime'      { return '🚀' }
            'Arrow'        { return '➔' }
            'Bullet'       { return '•' }
            'Header'       { return '✨' }
            'AllCache'     { return '💥' }
            'TempCache'    { return '📁' }
            'GameCache'    { return '🎮' }
            'SysCache'     { return '⚙️' }
            'WinUtil'      { return '🛠️' }
            'NpmScan'      { return '📦' }
            'Dashboard'    { return '📊' }
            'Web'          { return '🌐' }
            'Exit'         { return '🚪' }
            default        { return '' }
        }
    }
}

function Write-MenuItem {
    param(
        [string]$Number,
        [string]$Text,
        [ConsoleColor]$Color,
        [string]$IconName = ''
    )

    $icon = ''
    if ($UseFancyUi -and $IconName) {
        $icon = "$(Get-UiIcon $IconName) "
    }

    if ($UseFancyUi) {
        Write-Host "  [" -NoNewline -ForegroundColor Gray
        Write-Host ("{0,2}" -f $Number) -NoNewline -ForegroundColor White
        Write-Host "]  " -NoNewline -ForegroundColor Gray
        Write-Line "$icon$Text" $Color
    } else {
        Write-Line ("  [{0,-2}] {1}" -f $Number, $Text) $Color
    }
}

function Write-UiHeader {
    param(
        [string]$Title,
        [string]$IconName = ''
    )

    if ($UseFancyUi) {
        $icon = ''
        if ($IconName) {
            $icon = "$(Get-UiIcon $IconName) "
        }
        Write-Line '════════════════════════════════════════════════════════════════════' Cyan
        Write-Line "  $icon$Title" White
        Write-Line '════════════════════════════════════════════════════════════════════' Cyan
    } else {
        Write-Line '+--------------------------------------------------------------------+' Cyan
        Write-Line ("| {0,-66} |" -f $Title) White
        Write-Line '+--------------------------------------------------------------------+' Cyan
    }
}

function Write-Status {
    param(
        [ValidateSet('Ok', 'Warning', 'Error', 'Info', 'Test', 'Reset', 'Scan')]
        [string]$Type,
        [string]$Text,
        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )

    $icon = ''
    $prefix = ''
    if ($UseFancyUi) {
        switch ($Type) {
            'Ok'       { $icon = "$(Get-UiIcon Ok) "; $Color = [ConsoleColor]::Green }
            'Warning'  { $icon = "$(Get-UiIcon Warning) "; $Color = [ConsoleColor]::Yellow }
            'Error'    { $icon = "$(Get-UiIcon Error) "; $Color = [ConsoleColor]::Red }
            'Info'     { $icon = "💡 "; $Color = [ConsoleColor]::Cyan }
            'Test'     { $icon = "$(Get-UiIcon Test) "; $Color = [ConsoleColor]::Magenta }
            'Reset'    { $icon = "$(Get-UiIcon Reset) "; $Color = [ConsoleColor]::DarkCyan }
            'Scan'     { $icon = "$(Get-UiIcon Scan) "; $Color = [ConsoleColor]::Blue }
        }
        Write-Line "  $icon$Text" $Color
    } else {
        switch ($Type) {
            'Ok'       { $prefix = '[OK] '; $Color = [ConsoleColor]::Green }
            'Warning'  { $prefix = '[!] '; $Color = [ConsoleColor]::Yellow }
            'Error'    { $prefix = '[LOI] '; $Color = [ConsoleColor]::Red }
            'Info'     { $prefix = '[INFO] '; $Color = [ConsoleColor]::Cyan }
            'Test'     { $prefix = '[TEST] '; $Color = [ConsoleColor]::Yellow }
            'Reset'    { $prefix = '[RESET] '; $Color = [ConsoleColor]::DarkCyan }
            'Scan'     { $prefix = '[SCAN] '; $Color = [ConsoleColor]::Blue }
        }
        Write-Line "  $prefix$Text" $Color
    }
}

function Write-CardLine {
    param(
        [string]$IconName,
        [string]$Label,
        [string]$Value,
        [ConsoleColor]$ValueColor = [ConsoleColor]::White
    )

    if ($UseFancyUi) {
        $icon = "$(Get-UiIcon $IconName) "
        Write-Host "  $icon" -NoNewline
        Write-Host ("{0,-15}: " -f $Label) -ForegroundColor Gray -NoNewline
        Write-Line "$Value" $ValueColor
    } else {
        Write-Line ("  {0,-15}: {1}" -f $Label, $Value) $ValueColor
    }
}

function Write-Header {
    Clear-Host
    if ($UseFancyUi) {
        Write-Line '====================================================================' Cyan
        Write-Line '   🚀  N E T B O O S T   C O M M A N D   C E N T E R  🚀' White
        Write-Line '====================================================================' Cyan
        Write-Line "  💡 $($T.HeaderSubtitle)" DarkGray
        Write-Line ''
    } else {
        Write-Line '+--------------------------------------------------------------------+' Cyan
        Write-Line '|                         NETBOOST COMMAND CENTER                    |' White
        Write-Line '+--------------------------------------------------------------------+' Cyan
        Write-Line "  $($T.HeaderSubtitle)" DarkGray
        Write-Line ''
    }
}

function Write-Section {
    param([string]$Title, [ConsoleColor]$Color)
    Write-Line ''

    $displayTitle = $Title
    if ($Title -eq 'Network / DNS') { $displayTitle = $T.NetworkSec }
    elseif ($Title -eq 'Cleanup') { $displayTitle = $T.CleanupSec }
    elseif ($Title -eq 'Tools') { $displayTitle = $T.ToolsSec }

    if ($UseFancyUi) {
        $icon = ''
        if ($Title -match 'Network') { $icon = "$(Get-UiIcon Network) " }
        elseif ($Title -match 'Cleanup') { $icon = "$(Get-UiIcon Cleanup) " }
        elseif ($Title -match 'Tools') { $icon = "$(Get-UiIcon Tools) " }
        Write-Line ("  $icon{0}" -f $displayTitle.ToUpperInvariant()) $Color
    } else {
        Write-Line ("  {0}" -f $displayTitle.ToUpperInvariant()) $Color
    }
}

function Pause-Back {
    Write-Line ''
    if ($UseFancyUi) {
        Write-Line "  💡 $($T.PressAnyKey)" Green
    } else {
        Write-Line "  [READY] $($T.PressAnyKey)" Green
    }
    try { [void][Console]::ReadKey($true) }
    catch { Start-Sleep -Seconds 2 }
}

function Is-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-Admin {
    if (Is-Admin) { return }
    Write-Status Warning $T.AdminRequired
    $quotedScript = '"{0}"' -f ($ScriptPath.Replace('"', '\"'))
    $quotedArgs = $RawArgs | ForEach-Object { '"{0}"' -f ($_.Replace('"', '\"')) }
    $fullArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $quotedScript) + @($quotedArgs)
    Start-Process -FilePath 'powershell.exe' -ArgumentList ($fullArgs -join ' ') -WorkingDirectory $PSScriptRoot -Verb RunAs
    exit 0
}

function Get-GameAdapter {
    $route = Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        Where-Object { $_.NextHop -and $_.NextHop -ne '0.0.0.0' } |
        Sort-Object RouteMetric, InterfaceMetric |
        Select-Object -First 1

    if ($route) {
        $adapter = Get-NetAdapter -InterfaceIndex $route.InterfaceIndex -ErrorAction SilentlyContinue
        if ($adapter) {
            return $adapter
        }
    }

    return Get-NetAdapter -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Status -eq 'Up' -and
            $_.Name -notmatch 'Loopback|Bluetooth|VMware|Virtual|Hyper-V|TAP|Tailscale|WireGuard|VPN'
        } |
        Select-Object -First 1
}

function Get-CurrentDnsText {
    param([int]$InterfaceIndex)

    $dns = Get-DnsClientServerAddress -InterfaceIndex $InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
    if ($dns -and $dns.ServerAddresses -and $dns.ServerAddresses.Count -gt 0) {
        return ($dns.ServerAddresses -join ', ')
    }

    return 'DHCP/Auto'
}

function Show-DnsStatus {
    $adapter = Get-GameAdapter
    Write-UiHeader $T.DnsStatusHead 'Network'

    if (-not $adapter) {
        Write-Status Error $T.NoAdapter
        return
    }

    Write-CardLine 'Adapter' $T.CardAdapter ("{0} (Index {1})" -f $adapter.Name, $adapter.InterfaceIndex) White
    Write-CardLine 'Network' $T.CardStatus $adapter.Status White

    $dnsValue = Get-CurrentDnsText -InterfaceIndex $adapter.InterfaceIndex
    if ($dnsValue -match 'DHCP') { $dnsValue = $T.DnsStatusAuto }
    Write-CardLine 'Dns' $T.CardDns $dnsValue Green
}

function Test-AvgLatency {
    param(
        [string]$Label,
        [string]$Target,
        [int]$Count = 6
    )

    if ($UseFancyUi) {
        Write-Host ("  $(Get-UiIcon Test) {0,-10} {1,-15} " -f $Label, $Target) -NoNewline -ForegroundColor Gray
    } else {
        Write-Host ("  {0,-10} {1,-15} " -f $Label, $Target) -NoNewline -ForegroundColor Gray
    }

    $samples = @()
    try {
        $raw = @(Test-Connection -ComputerName $Target -Count $Count -ErrorAction SilentlyContinue)
    } catch {
        $raw = @()
    }

    foreach ($item in $raw) {
        $latency = $null
        if ($item.PSObject.Properties.Match('ResponseTime').Count -gt 0) {
            $latency = $item.ResponseTime
        } elseif ($item.PSObject.Properties.Match('Latency').Count -gt 0) {
            $latency = $item.Latency
        }

        if ($null -ne $latency) {
            $samples += [double]$latency
        }
    }

    if ($samples.Count -eq 0) {
        Write-Status Error $T.PingTimeout
        return [pscustomobject]@{
            Label = $Label
            Target = $Target
            Average = [double]::PositiveInfinity
            Min = [double]::PositiveInfinity
            Count = 0
            Loss = 100
        }
    }

    $avg = [math]::Round(($samples | Measure-Object -Average).Average, 1)
    $min = [math]::Round(($samples | Measure-Object -Minimum).Minimum, 1)
    $loss = [math]::Round((($Count - $samples.Count) / $Count) * 100, 0)

    if ($UseFancyUi) {
        Write-Line ("⚡ avg {0,5} ms | 📉 min {1,5} ms | 📊 loss {2,3}%" -f $avg, $min, $loss) Green
    } else {
        Write-Line ("avg {0,5} ms | min {1,5} ms | loss {2,3}%" -f $avg, $min, $loss) Green
    }

    return [pscustomobject]@{
        Label = $Label
        Target = $Target
        Average = $avg
        Min = $min
        Count = $samples.Count
        Loss = $loss
    }
}

function Set-DnsProvider {
    param(
        [ValidateSet('Google', 'Cloudflare')]
        [string]$ProviderName
    )

    Ensure-Admin
    $adapter = Get-GameAdapter
    if (-not $adapter) {
        Write-Status Error $T.NoAdapter
        return
    }

    $provider = $Providers[$ProviderName]
    $servers = @($provider.Primary, $provider.Secondary)

    if ($UseFancyUi) {
        Write-Status Reset ($T.ApplyDns -f $adapter.Name)
        Write-Line ("        ⚡ $($T.ApplyProvider): {0}" -f $provider.Label) White
        Write-Line ("        🌐 DNS           : {0}" -f ($servers -join ', ')) White
    } else {
        Write-Line ''
        Write-Line ("[APPLY] Adapter : {0}" -f $adapter.Name) Cyan
        Write-Line ("        Provider: {0}" -f $provider.Label) White
        Write-Line ("        DNS     : {0}" -f ($servers -join ', ')) White
    }

    Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses $servers -ErrorAction Stop
    Clear-DnsClientCache -ErrorAction SilentlyContinue

    Write-Status Ok $T.ApplyDone
}

function Reset-DnsToAuto {
    Ensure-Admin
    $adapter = Get-GameAdapter
    if (-not $adapter) {
        Write-Status Error $T.NoAdapter
        return
    }

    if ($UseFancyUi) {
        Write-Status Reset ($T.ResetDns -f $adapter.Name)
    } else {
        Write-Line ''
        Write-Line ('[RESET] Adapter: {0}' -f $adapter.Name) Cyan
    }

    Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ResetServerAddresses -ErrorAction Stop
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    Write-Status Ok $T.ResetDone
}

function Invoke-AutoDns {
    Ensure-Admin
    $adapter = Get-GameAdapter
    if (-not $adapter) {
        Write-Status Error $T.NoAdapter
        return
    }

    Write-UiHeader $T.Menu1 'AutoDns'
    Write-CardLine 'Adapter' $T.CardAdapter ("{0} (Index {1})" -f $adapter.Name, $adapter.InterfaceIndex) White

    $dnsVal = Get-CurrentDnsText -InterfaceIndex $adapter.InterfaceIndex
    if ($dnsVal -match 'DHCP') { $dnsVal = $T.DnsStatusAuto }
    Write-CardLine 'Dns' $T.CardDns $dnsVal White
    Write-Line ''
    Write-Status Test $T.PingTestStart

    $google = Test-AvgLatency -Label 'Google' -Target $Providers.Google.Primary
    $cloudflare = Test-AvgLatency -Label 'Cloudflare' -Target $Providers.Cloudflare.Primary

    if ([double]::IsPositiveInfinity($google.Average) -and [double]::IsPositiveInfinity($cloudflare.Average)) {
        Write-Line ''
        Write-Status Error $T.PingFailBoth
        return
    }

    Write-Line ''
    if ($google.Average -lt $cloudflare.Average) {
        Write-Status Ok ($T.DnsWin -f 'Google', $google.Average, $cloudflare.Average)
        Set-DnsProvider -ProviderName Google
    } elseif ($cloudflare.Average -lt $google.Average) {
        Write-Status Ok ($T.DnsWin -f 'Cloudflare', $cloudflare.Average, $google.Average)
        Set-DnsProvider -ProviderName Cloudflare
    } else {
        Write-Status Warning ($T.DnsTie -f $google.Average)
    }
}

function Install-AutoDnsTask {
    Ensure-Admin
    $taskScriptPath = $ScriptPath.Replace('"', '\"')
    $langParam = if ($Language -eq 'EN') { ' -Lang EN' } else { '' }
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -ExecutionPolicy Bypass -File "{0}" -AutoDns{1}' -f $taskScriptPath, $langParam)
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $trigger.Delay = 'PT30S'
    $userId = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $principal = New-ScheduledTaskPrincipal -UserId $userId -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
    Write-Status Ok ($T.TaskCreated -f $TaskName)
}

function Remove-AutoDnsTask {
    Ensure-Admin
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if (-not $task) {
        Write-Status Warning $T.TaskNoTask
        return
    }

    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Status Ok ($T.TaskRemoved -f $TaskName)
}

function Flush-Dns {
    Ensure-Admin
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    ipconfig /flushdns | Out-Host
}

function Open-ChrisTitus {
    Ensure-Admin
    Write-Line ''
    Write-Status Warning $T.WinUtilWarn
    Write-Line "  $($T.WinUtilSource)" DarkGray
    $confirm = Read-UiInput $T.ConfirmPrompt
    if ($confirm -ne 'y') {
        Write-Status Warning $T.ActionSkipped
        return
    }

    Write-Status Info $T.OpeningWinUtil
    Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command "irm https://christitus.com/win | iex"' -Verb RunAs
}

function Remove-FolderContents {
    param(
        [string]$Path,
        [string]$Label,
        [int]$MinAgeMinutes = 0,
        [string]$TargetId = '',
        [string]$JobId = ''
    )

    Ensure-Admin
    $filesDeleted = 0
    $dirsDeleted = 0
    $filesFailed = 0
    $dirsFailed = 0

    Write-UiHeader ($T.CleanRunHead -f $Label) 'Cleanup'
    Write-CleanupEvent -Level INFO -TargetId $TargetId -TargetLabel $Label -Path $Path -Message 'Starting cleanup target' -JobId $JobId

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Status Warning ($T.CleanFolderNotFound -f $Path)
        Write-CleanupEvent -Level WARN -TargetId $TargetId -TargetLabel $Label -Path $Path -Message 'Cleanup folder not found' -JobId $JobId
        return
    }

    $cutoff = if ($MinAgeMinutes -gt 0) { (Get-Date).AddMinutes(-$MinAgeMinutes) } else { $null }

    $files = Get-ChildItem -LiteralPath $Path -Force -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object {
            ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0 -and
            ($null -eq $cutoff -or $_.LastWriteTime -lt $cutoff)
        }
    foreach ($file in $files) {
        try {
            $bytes = [int64]$file.Length
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
            $filesDeleted++
            Write-CleanupEvent -Level DELETE_OK -TargetId $TargetId -TargetLabel $Label -Path $file.FullName -Bytes $bytes -Message 'Deleted file' -JobId $JobId
        } catch {
            if (Test-CleanupLockedError -ErrorRecord $_) {
                $filesFailed++
                Write-CleanupEvent -Level SKIP_LOCKED -TargetId $TargetId -TargetLabel $Label -Path $file.FullName -Bytes ([int64]$file.Length) -Message $_.Exception.Message -JobId $JobId
            } else {
                $filesFailed++
                Write-CleanupEvent -Level ERROR -TargetId $TargetId -TargetLabel $Label -Path $file.FullName -Bytes ([int64]$file.Length) -Message $_.Exception.Message -JobId $JobId
            }
        }
    }

    $dirs = Get-ChildItem -LiteralPath $Path -Force -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object { ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0 } |
        Sort-Object { $_.FullName.Length } -Descending

    foreach ($dir in $dirs) {
        $remaining = @(Get-ChildItem -LiteralPath $dir.FullName -Force -ErrorAction SilentlyContinue)
        if ($remaining.Count -gt 0) {
            continue
        }

        try {
            Remove-Item -LiteralPath $dir.FullName -Force -ErrorAction Stop
            $dirsDeleted++
            Write-CleanupEvent -Level DELETE_DIR -TargetId $TargetId -TargetLabel $Label -Path $dir.FullName -Message 'Deleted empty directory' -JobId $JobId
        } catch {
            if (Test-CleanupLockedError -ErrorRecord $_) {
                $dirsFailed++
                Write-CleanupEvent -Level SKIP_LOCKED -TargetId $TargetId -TargetLabel $Label -Path $dir.FullName -Message $_.Exception.Message -JobId $JobId
            } else {
                $dirsFailed++
                Write-CleanupEvent -Level ERROR -TargetId $TargetId -TargetLabel $Label -Path $dir.FullName -Message $_.Exception.Message -JobId $JobId
            }
        }
    }

    if ($UseFancyUi) {
        Write-Line ("  ✨ $($T.CleanSummary -f $Label)") Magenta
        Write-Line ("    ✅ $($T.CleanFilesDel)   : {0}" -f $filesDeleted) Green
        Write-Line ("    ✅ $($T.CleanDirsDel)   : {0}" -f $dirsDeleted) Green
        Write-Line ("    ❌ $($T.CleanFilesLock)  : {0}" -f $filesFailed) Red
        Write-Line ("    ❌ $($T.CleanDirsLock)  : {0}" -f $dirsFailed) Red
    } else {
        Write-Line ("[SUMMARY] {0}" -f $Label) Magenta
        Write-Line ("  {0}: {1}" -f $T.CleanFilesDel, $filesDeleted) Green
        Write-Line ("  {0}: {1}" -f $T.CleanDirsDel, $dirsDeleted) Green
        Write-Line ("  {0}: {1}" -f $T.CleanFilesLock, $filesFailed) Red
        Write-Line ("  {0}: {1}" -f $T.CleanDirsLock, $dirsFailed) Red
    }

    Write-CleanupEvent -Level SUMMARY -TargetId $TargetId -TargetLabel $Label -Path $Path -Message ("FilesDeleted={0};DirsDeleted={1};SkippedOrFailedFiles={2};SkippedOrFailedDirs={3}" -f $filesDeleted, $dirsDeleted, $filesFailed, $dirsFailed) -JobId $JobId
}

function Clean-Temp {
    Remove-FolderContents -Path $env:TEMP -Label 'Temp cua nguoi dung' -MinAgeMinutes 60 -TargetId 'user-temp'
    Remove-FolderContents -Path 'C:\Windows\Temp' -Label 'Windows Temp' -MinAgeMinutes 60 -TargetId 'windows-temp'
}

function Get-SteamInstallPaths {
    $paths = [System.Collections.Generic.List[string]]::new()

    $registryKeys = @(
        'HKCU:\Software\Valve\Steam',
        'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam',
        'HKLM:\SOFTWARE\Valve\Steam'
    )

    foreach ($key in $registryKeys) {
        try {
            $props = Get-ItemProperty -Path $key -ErrorAction Stop
            foreach ($name in @('SteamPath', 'InstallPath')) {
                if ($props.$name -and (Test-Path -LiteralPath $props.$name)) {
                    [void]$paths.Add((Resolve-Path -LiteralPath $props.$name).Path)
                }
            }
        } catch {
        }
    }

    $defaultPaths = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Steam'),
        (Join-Path $env:ProgramFiles 'Steam')
    )

    foreach ($path in $defaultPaths) {
        if ($path -and (Test-Path -LiteralPath $path)) {
            [void]$paths.Add((Resolve-Path -LiteralPath $path).Path)
        }
    }

    return @($paths.ToArray() | Sort-Object -Unique)
}

function Get-SteamLibraryPaths {
    $libraryPaths = [System.Collections.Generic.List[string]]::new()

    foreach ($steamPath in Get-SteamInstallPaths) {
        [void]$libraryPaths.Add($steamPath)

        $libraryFile = Join-Path $steamPath 'steamapps\libraryfolders.vdf'
        if (-not (Test-Path -LiteralPath $libraryFile)) {
            continue
        }

        try {
            $content = Get-Content -LiteralPath $libraryFile -Raw -ErrorAction Stop
            $vdfMatches = [regex]::Matches($content, '"path"\s+"([^"]+)"')
            foreach ($match in $vdfMatches) {
                $path = $match.Groups[1].Value -replace '\\\\', '\'
                if (Test-Path -LiteralPath $path) {
                    [void]$libraryPaths.Add((Resolve-Path -LiteralPath $path).Path)
                }
            }
        } catch {
            Write-Status Warning ("Failed to read Steam library folders file: " + $libraryFile)
        }
    }

    return @($libraryPaths.ToArray() | Sort-Object -Unique)
}

function Clean-SteamShaderCache {
    param(
        [string]$AppId = '730',
        [string]$Label = 'Steam shader cache'
    )

    $libraryPaths = @(Get-SteamLibraryPaths)
    if ($libraryPaths.Count -eq 0) {
        Write-Line ''
        Write-Status Warning "No Steam installation / libraries found."
        return
    }

    $targets = [System.Collections.Generic.List[string]]::new()
    foreach ($libraryPath in $libraryPaths) {
        $target = Join-Path $libraryPath ("steamapps\shadercache\{0}" -f $AppId)
        if (Test-Path -LiteralPath $target) {
            [void]$targets.Add((Resolve-Path -LiteralPath $target).Path)
        }
    }

    $uniqueTargets = @($targets.ToArray() | Sort-Object -Unique)
    if ($uniqueTargets.Count -eq 0) {
        Write-Line ''
        Write-Status Warning ("Shader cache folder not found for app ID: " + $AppId)
        return
    }

    foreach ($target in $uniqueTargets) {
        Remove-FolderContents -Path $target -Label ("{0} app {1}: {2}" -f $Label, $AppId, $target) -TargetId 'steam-cache'
    }
}

function Clean-Game {
    Remove-FolderContents -Path (Join-Path $env:LOCALAPPDATA 'D3DSCache') -Label 'DirectX Shader Cache' -TargetId 'directx-cache'
    Remove-FolderContents -Path (Join-Path $env:LOCALAPPDATA 'NVIDIA\DXCache') -Label 'NVIDIA DXCache' -TargetId 'nvidia-cache'
    Remove-FolderContents -Path (Join-Path $env:LOCALAPPDATA 'NVIDIA\GLCache') -Label 'NVIDIA GLCache' -TargetId 'nvidia-cache'
    Remove-FolderContents -Path (Join-Path $env:LOCALAPPDATA 'NVIDIA\NV_Cache') -Label 'NVIDIA NV_Cache' -TargetId 'nvidia-cache'
    Remove-FolderContents -Path (Join-Path $env:LOCALAPPDATA 'Steam\shadercache\730') -Label 'Steam shader cache CS2 (LocalAppData)' -TargetId 'steam-cache'
    Clean-SteamShaderCache -AppId '730' -Label 'Steam shader cache CS2'
}

function Clean-System {
    Remove-FolderContents -Path (Join-Path $env:LOCALAPPDATA 'CrashDumps') -Label 'Crash dumps cua ung dung' -TargetId 'crash-dumps'
    Remove-FolderContents -Path (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer') -Label 'Thumbnail cache cua Windows' -TargetId 'thumbnails'
    Remove-FolderContents -Path (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\INetCache') -Label 'Web cache cua Windows INetCache' -TargetId 'inet-cache'
}

function Clean-RecycleBin {
    Ensure-Admin
    Write-UiHeader $T.CleanRecycleBin 'RecycleBin'
    Write-CleanupEvent -Level INFO -TargetId 'recycle-bin' -TargetLabel 'Recycle Bin' -Path 'Recycle Bin' -Message 'Starting Recycle Bin cleanup'

    try {
        Clear-RecycleBin -Force -ErrorAction Stop
        Write-Status Ok $T.CleanBinDone
        Write-CleanupEvent -Level SUMMARY -TargetId 'recycle-bin' -TargetLabel 'Recycle Bin' -Path 'Recycle Bin' -Message 'Recycle Bin cleanup completed'
    } catch {
        Write-Status Warning $T.CleanBinEmpty
        Write-CleanupEvent -Level WARN -TargetId 'recycle-bin' -TargetLabel 'Recycle Bin' -Path 'Recycle Bin' -Message $_.Exception.Message
    }
}

function Clean-All {
    Write-Status Warning $T.ConfirmAll
    $confirm = Read-UiInput $T.ConfirmPrompt
    if ($confirm -ne 'y') {
        Write-Status Warning $T.ActionSkipped
        return
    }

    Clean-Temp
    Clean-Game
    Clean-System
    Clean-RecycleBin
}

function Format-Bytes {
    param([Nullable[double]]$Bytes)

    if ($null -eq $Bytes) {
        return $T.NotMeasurable
    }

    if ($Bytes -ge 1GB) {
        return ('{0:N2} GB' -f ($Bytes / 1GB))
    }

    if ($Bytes -ge 1MB) {
        return ('{0:N2} MB' -f ($Bytes / 1MB))
    }

    if ($Bytes -ge 1KB) {
        return ('{0:N2} KB' -f ($Bytes / 1KB))
    }

    return ('{0:N0} B' -f $Bytes)
}

function Get-PathSize {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    try {
        $sum = (Get-ChildItem -LiteralPath $Path -Force -File -Recurse -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum

        if ($null -eq $sum) {
            return 0
        }

        return [double]$sum
    } catch {
        return $null
    }
}

function Test-DirectChild {
    param(
        [string]$Base,
        [string]$Name
    )

    return Test-Path -LiteralPath (Join-Path $Base $Name)
}

function Find-NpmProjects {
    param(
        [string]$Root,
        [int]$MaxDirs = 50000
    )

    $resolved = (Resolve-Path -LiteralPath $Root -ErrorAction Stop).Path
    $skipNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    @('node_modules', '.git', '.hg', '.svn', '.pnpm', '.next', 'dist', 'build', 'out', 'coverage', '.cache') |
        ForEach-Object { [void]$skipNames.Add($_) }

    $items = New-Object 'System.Collections.Generic.List[object]'
    $stack = New-Object 'System.Collections.Generic.Stack[string]'
    $stack.Push($resolved)
    $scanned = 0

    while ($stack.Count -gt 0 -and $scanned -lt $MaxDirs) {
        $dir = $stack.Pop()
        $scanned++

        $allChildren = @(Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue)
        $childNames = [System.Collections.Generic.HashSet[string]]::new(
            [string[]]($allChildren | ForEach-Object { $_.Name }),
            [StringComparer]::OrdinalIgnoreCase
        )
        $hasPackageJson = $childNames.Contains('package.json')
        $hasPackageLock = $childNames.Contains('package-lock.json')
        $hasShrinkwrap = $childNames.Contains('npm-shrinkwrap.json')
        $hasPnpmLock = $childNames.Contains('pnpm-lock.yaml')
        $hasYarnLock = $childNames.Contains('yarn.lock')
        $hasNodeModules = $childNames.Contains('node_modules')

        if ($hasPackageJson -or $hasPackageLock -or $hasShrinkwrap -or $hasNodeModules) {
            [void]$items.Add([pscustomobject]@{
                Path = $dir
                PackageJson = $hasPackageJson
                PackageLock = $hasPackageLock
                Shrinkwrap = $hasShrinkwrap
                PnpmLock = $hasPnpmLock
                YarnLock = $hasYarnLock
                NodeModules = $hasNodeModules
            })
        }

        foreach ($child in $allChildren) {
            if (-not $child.PSIsContainer) {
                continue
            }

            if ($skipNames.Contains($child.Name)) {
                continue
            }

            if (($child.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                continue
            }

            $stack.Push($child.FullName)
        }
    }

    return [pscustomobject]@{
        Root = $resolved
        Items = @($items.ToArray())
        Scanned = $scanned
        HitLimit = ($scanned -ge $MaxDirs)
    }
}

function Get-ToolVersionText {
    param([string]$CommandName)

    $cmd = Get-Command $CommandName -ErrorAction SilentlyContinue
    if (-not $cmd) {
        return 'missing'
    }

    try {
        return (((& $cmd.Source --version 2>$null) -join '').Trim())
    } catch {
        return 'found'
    }
}

function Get-TaskStatusText {
    try {
        $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
        return $task.State.ToString()
    } catch {
        return 'Not installed'
    }
}

function Write-DashboardLine {
    param(
        [string]$Text = '',
        [ConsoleColor]$Color = [ConsoleColor]::DarkCyan
    )

    $width = 66
    if ($Text.Length -gt $width) {
        $Text = $Text.Substring(0, $width - 3) + '...'
    }

    Write-Line ('| {0,-66} |' -f $Text) $Color
}

function Show-Dashboard {
    $adapterText = 'No online adapter'
    $dnsText = 'Unknown'
    $adapter = Get-GameAdapter

    if ($adapter) {
        $adapterText = ('{0} ({1})' -f $adapter.Name, $adapter.Status)
        $dnsText = Get-CurrentDnsText -InterfaceIndex $adapter.InterfaceIndex
    }

    Write-UiHeader $T.DashHead 'Runtime'

    Write-CardLine 'Header' $T.CardTime (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') DarkGray
    Write-CardLine 'Adapter' $T.CardAdapter $adapterText Gray

    $dnsVal = $dnsText
    if ($dnsVal -match 'DHCP') { $dnsVal = $T.DnsStatusAuto }
    Write-CardLine 'Dns' $T.CardDns $dnsVal Green

    Write-CardLine 'Task' $T.CardTask (Get-TaskStatusText) Yellow
    Write-CardLine 'Runtime' $T.CardRuntime ('node {0} | npm {1} | pnpm {2}' -f (Get-ToolVersionText 'node'), (Get-ToolVersionText 'npm'), (Get-ToolVersionText 'pnpm')) Magenta

    if ($UseFancyUi) {
        Write-Line '════════════════════════════════════════════════════════════════════' Cyan
    } else {
        Write-Line '+--------------------------------------------------------------------+' Cyan
    }
}

function Show-NpmScan {
    param([string]$Root = $DefaultScanRoot)

    Write-UiHeader $T.ScanHead 'Scan'
    Write-Status Info $T.ScanInfo
    Write-Line ''

    $node = Get-Command node -ErrorAction SilentlyContinue
    $npm = Get-Command npm -ErrorAction SilentlyContinue
    $pnpm = Get-Command pnpm -ErrorAction SilentlyContinue

    Write-Line "  [$($T.CardRuntime.ToUpper())]" Cyan
    if ($node) { Write-Line ("    " + (Get-UiIcon Runtime) + " Node : {0}" -f ((& $node.Source --version 2>$null) -join '')) White } else { Write-Line "    $($T.ScanNodeMissing)" Yellow }
    if ($npm) { Write-Line ("    " + (Get-UiIcon Runtime) + " npm  : {0}" -f ((& $npm.Source --version 2>$null) -join '')) White } else { Write-Line "    $($T.ScanNpmMissing)" Yellow }
    if ($pnpm) { Write-Line ("    " + (Get-UiIcon Runtime) + " pnpm : {0}" -f ((& $pnpm.Source --version 2>$null) -join '')) White } else { Write-Line "    $($T.ScanPnpmMissing)" Yellow }

    if ($npm) {
        Write-Line ''
        Write-Line "  [$($T.ScanGlobalHead)]" Cyan

        $prefix = ((& $npm.Source config get prefix 2>$null) -join '').Trim()
        $globalRoot = ((& $npm.Source root -g 2>$null) -join '').Trim()
        $cache = ((& $npm.Source config get cache 2>$null) -join '').Trim()

        Write-Line ("    Prefix     : {0}" -f $prefix) White
        Write-Line ("    $($T.ScanGlobalRoot): {0}" -f $globalRoot) White
        Write-Line ("    Cache      : {0}" -f $cache) White
        Write-Line ("    $($T.ScanCacheSize) : {0}" -f (Format-Bytes (Get-PathSize -Path $cache))) White

        Write-Line ''
        Write-Line "  [$($T.ScanGlobPack)]" Cyan
        try {
            $json = ((& $npm.Source list -g --depth=0 --json 2>$null) -join "`n")
            $globalInfo = $json | ConvertFrom-Json -ErrorAction Stop
            $deps = @()

            if ($globalInfo.dependencies) {
                $deps = @($globalInfo.dependencies.PSObject.Properties | Sort-Object Name | ForEach-Object {
                    [pscustomobject]@{
                        Name = $_.Name
                        Version = $_.Value.version
                    }
                })
            }

            if ($deps.Count -eq 0) {
                Write-Line "    $($T.ScanNoPack)" Yellow
            } else {
                foreach ($dep in ($deps | Select-Object -First 80)) {
                    Write-Line ("    - {0}@{1}" -f $dep.Name, $dep.Version) White
                }

                if ($deps.Count -gt 80) {
                    Write-Line ("    " + ($T.ScanMoreItems -f ($deps.Count - 80))) Yellow
                }
            }
        } catch {
            Write-Line "    $($T.ScanReadError)" Yellow
        }
    }

    Write-Line ''
    Write-Line ("$($T.ScanProjRoot -f $Root)") Cyan

    if (-not (Test-Path -LiteralPath $Root)) {
        Write-Status Error $T.CleanFolderNotFound
        return
    }

    $scan = Find-NpmProjects -Root $Root
    $projects = @($scan.Items | Sort-Object Path)

    Write-Line ("    $($T.ScanScanned) : {0} folders" -f $scan.Scanned) White
    if ($scan.HitLimit) {
        Write-Status Warning $T.ScanLimit
    }

    if ($projects.Count -eq 0) {
        Write-Status Warning $T.ScanProjNone
    } else {
        Write-Line ("    $($T.ScanProjFound -f $projects.Count)") White
        Write-Line ''
        Write-Line '    Flags: pkg=package.json | lock=package-lock/npm-shrinkwrap | nm=node_modules | pnpm=pnpm-lock' DarkGray

        foreach ($project in ($projects | Select-Object -First 120)) {
            $flags = @()
            if ($project.PackageJson) { $flags += 'pkg' }
            if ($project.PackageLock -or $project.Shrinkwrap) { $flags += 'lock' }
            if ($project.NodeModules) { $flags += 'nm' }
            if ($project.PnpmLock) { $flags += 'pnpm' }
            if ($project.YarnLock) { $flags += 'yarn' }

            Write-Line ("    [{0,-18}] {1}" -f ($flags -join ','), $project.Path) White
        }

        if ($projects.Count -gt 120) {
            Write-Line ("    " + ($T.ScanMoreItems -f ($projects.Count - 120))) Yellow
        }
    }

    $npmLockProjects = @($projects | Where-Object { $_.PackageLock -or $_.Shrinkwrap })
    $nodeModulesProjects = @($projects | Where-Object { $_.NodeModules })

    Write-Line ''
    Write-Line "[$($T.MigrateHead)]" Cyan
    Write-Line ("  " + (Get-UiIcon Arrow) + " $($T.MigrateLock): {0}" -f $npmLockProjects.Count) White
    Write-Line ("  " + (Get-UiIcon Arrow) + " $($T.MigrateNm): {0}" -f $nodeModulesProjects.Count) White
    Write-Line ("  " + (Get-UiIcon Bullet) + " $($T.MigrateStep1)") Green
    Write-Line ("  " + (Get-UiIcon Bullet) + " $($T.MigrateStep2)") Green
    Write-Line ("  " + (Get-UiIcon Warning) + " $($T.MigrateStep3)") Yellow
}

function Show-Help {
    Write-Line ''
    Write-Line $AppName White
    Write-Line ''
    Write-Line 'Usage:' Cyan
    Write-Line '  NetBoost_Command_Center.bat' Green
    Write-Line '  NetBoost_Command_Center.bat --auto-dns' Green
    Write-Line '  NetBoost_Command_Center.bat --google' Green
    Write-Line '  NetBoost_Command_Center.bat --cloudflare' Green
    Write-Line '  NetBoost_Command_Center.bat --reset-dns' Green
    Write-Line '  NetBoost_Command_Center.bat --status' Green
    Write-Line '  NetBoost_Command_Center.bat --dashboard' Green
    Write-Line '  NetBoost_Command_Center.bat --scan-npm D:\Code' Green
    Write-Line '  NetBoost_Command_Center.bat --web --port 47812' Green
    Write-Line '  NetBoost_Command_Center.bat --lang en' Green
    Write-Line '  NetBoost_Command_Center.bat --lang vi' Green
    Write-Line ''
}

function Switch-UiLanguage {
    $targetLanguage = if ($Language -eq 'EN') { 'VI' } else { 'EN' }
    $targetLabel = if ($targetLanguage -eq 'EN') { 'English' } else { 'Vietnamese' }

    Write-Status Info ("Switching interface language to {0}..." -f $targetLabel)
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$ScriptPath" --lang $targetLanguage
    exit $LASTEXITCODE
}

function Show-Menu {
    Ensure-Admin
    [Console]::Title = $AppName

    while ($true) {
        Write-Header

        Write-Section 'Network / DNS' Cyan
        Write-MenuItem '1' $T.Menu1 Green 'AutoDns'
        Write-MenuItem '2' $T.Menu2 Green 'Dns'
        Write-MenuItem '3' $T.Menu3 Green 'Dns'
        Write-MenuItem '4' $T.Menu4 Green 'Scan'
        Write-MenuItem '5' $T.Menu5 Green 'Task'
        Write-MenuItem '6' $T.Menu6 Green 'Reset'
        Write-MenuItem '7' $T.Menu7 Green 'Cleanup'
        Write-MenuItem '8' $T.Menu8 Green 'Reset'

        Write-Section 'Cleanup' Magenta
        Write-MenuItem '9' $T.Menu9 Yellow 'AllCache'
        Write-MenuItem '10' $T.Menu10 Yellow 'TempCache'
        Write-MenuItem '11' $T.Menu11 Yellow 'GameCache'
        Write-MenuItem '12' $T.Menu12 Yellow 'SysCache'
        Write-MenuItem '13' $T.Menu13 Yellow 'RecycleBin'

        Write-Section 'Tools' Blue
        Write-MenuItem '14' $T.Menu14 Cyan 'WinUtil'
        Write-MenuItem '15' $T.Menu15 Cyan 'NpmScan'
        Write-MenuItem '16' $T.Menu16 Cyan 'Dashboard'
        Write-MenuItem '17' $T.Menu17 Cyan 'Tools'
        Write-MenuItem '18' $T.Menu18 Green 'Web'
        Write-MenuItem '0' $T.Menu0 Red 'Exit'
        Write-Line ''

        $choice = Read-UiInput $T.PromptChoice

        try {
            switch ($choice) {
                '1' { Invoke-AutoDns; Pause-Back }
                '2' { Set-DnsProvider -ProviderName Google; Pause-Back }
                '3' { Set-DnsProvider -ProviderName Cloudflare; Pause-Back }
                '4' { Show-DnsStatus; Pause-Back }
                '5' { Install-AutoDnsTask; Pause-Back }
                '6' { Remove-AutoDnsTask; Pause-Back }
                '7' { Flush-Dns; Pause-Back }
                '8' { Reset-DnsToAuto; Pause-Back }
                '9' { Clean-All; Pause-Back }
                '10' { Clean-Temp; Pause-Back }
                '11' { Clean-Game; Pause-Back }
                '12' { Clean-System; Pause-Back }
                '13' { Clean-RecycleBin; Pause-Back }
                '14' { Open-ChrisTitus; Pause-Back }
                '15' {
                    $root = Read-UiInput ("$($T.ScanProjRoot -f $DefaultScanRoot) (Enter = $DefaultScanRoot)")
                    if ([string]::IsNullOrWhiteSpace($root)) { $root = $DefaultScanRoot }
                    Show-NpmScan -Root $root
                    Pause-Back
                }
                '16' { Show-Dashboard; Pause-Back }
                '17' { Switch-UiLanguage }
                '18' {
                    $webPort = 47812
                    if (Get-Command Start-NetBoostWebBackend -ErrorAction SilentlyContinue) {
                        Start-NetBoostWebBackend -Port $webPort
                    } else {
                        Write-Status Error 'Local backend module not found.'
                    }
                    Pause-Back
                }
                '0' { return }
                default { Write-Status Error $T.InvalidChoice; Start-Sleep -Milliseconds 700 }
            }
        } catch {
            Write-Line ''
            Write-Status Error ("$($T.InvalidChoice): {0}" -f $_.Exception.Message)
            Pause-Back
        }
    }
}

function Parse-Args {
    $mode = 'Menu'
    $scanRoot = $DefaultScanRoot
    $webPort = 47812

    for ($i = 0; $i -lt $RawArgs.Count; $i++) {
        $arg = $RawArgs[$i].ToLowerInvariant()
        switch ($arg) {
            '--lang' { $i++ }
            '-lang' { $i++ }
            '--web' { $mode = 'Web' }
            '-web' { $mode = 'Web' }
            '--port' {
                if ($i + 1 -lt $RawArgs.Count) {
                    $candidatePort = 0
                    if ([int]::TryParse($RawArgs[$i + 1], [ref]$candidatePort) -and $candidatePort -gt 0 -and $candidatePort -lt 65536) {
                        $webPort = $candidatePort
                    }
                    $i++
                }
            }
            '-port' {
                if ($i + 1 -lt $RawArgs.Count) {
                    $candidatePort = 0
                    if ([int]::TryParse($RawArgs[$i + 1], [ref]$candidatePort) -and $candidatePort -gt 0 -and $candidatePort -lt 65536) {
                        $webPort = $candidatePort
                    }
                    $i++
                }
            }
            '--auto-dns' { $mode = 'AutoDns' }
            '-autodns' { $mode = 'AutoDns' }
            '-auto-dns' { $mode = 'AutoDns' }
            '--google' { $mode = 'Google' }
            '-google' { $mode = 'Google' }
            '--cloudflare' { $mode = 'Cloudflare' }
            '-cloudflare' { $mode = 'Cloudflare' }
            '--reset-dns' { $mode = 'ResetDns' }
            '-resetdns' { $mode = 'ResetDns' }
            '-reset-dns' { $mode = 'ResetDns' }
            '--status' { $mode = 'Status' }
            '-status' { $mode = 'Status' }
            '--dashboard' { $mode = 'Dashboard' }
            '-dashboard' { $mode = 'Dashboard' }
            '--scan-npm' {
                $mode = 'NpmScan'
                if ($i + 1 -lt $RawArgs.Count) {
                    $scanRoot = $RawArgs[$i + 1]
                    $i++
                }
            }
            '-scannpm' {
                $mode = 'NpmScan'
                if ($i + 1 -lt $RawArgs.Count) {
                    $scanRoot = $RawArgs[$i + 1]
                    $i++
                }
            }
            '-scan-npm' {
                $mode = 'NpmScan'
                if ($i + 1 -lt $RawArgs.Count) {
                    $scanRoot = $RawArgs[$i + 1]
                    $i++
                }
            }
            '--help' { $mode = 'Help' }
            '-help' { $mode = 'Help' }
            '/?' { $mode = 'Help' }
        }
    }

    return [pscustomobject]@{
        Mode = $mode
        ScanRoot = $scanRoot
        WebPort = $webPort
    }
}

$backendScript = Join-Path (Split-Path -Parent $PSScriptRoot) 'backend\NetBoost.LocalWeb.ps1'
if (Test-Path -LiteralPath $backendScript) {
    . $backendScript
}

$parsed = Parse-Args

switch ($parsed.Mode) {
    'Help' { Show-Help }
    'Status' { Show-DnsStatus }
    'Dashboard' { Show-Dashboard }
    'NpmScan' { Show-NpmScan -Root $parsed.ScanRoot }
    'AutoDns' { Invoke-AutoDns }
    'Google' { Set-DnsProvider -ProviderName Google }
    'Cloudflare' { Set-DnsProvider -ProviderName Cloudflare }
    'ResetDns' { Reset-DnsToAuto }
    'Web' {
        if (Get-Command Start-NetBoostWebBackend -ErrorAction SilentlyContinue) {
            Start-NetBoostWebBackend -Port $parsed.WebPort
        } else {
            Write-Status Error 'Local backend module not found.'
            exit 1
        }
    }
    default { Show-Menu }
}
