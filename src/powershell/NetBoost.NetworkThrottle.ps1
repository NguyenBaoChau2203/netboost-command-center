#Requires -Version 5.1
<#
.SYNOPSIS
    NetBoost Network Throttling Diagnostic and Optimization Module
.DESCRIPTION
    Audits and optimizes Windows settings that throttle, bottleneck, or degrade
    network bandwidth and latency, including Multimedia Network Throttling Index,
    System Responsiveness, TCP Window Auto-Tuning, RSS, QoS Reservable Bandwidth,
    and Windows Delivery Optimization P2P uploads.
#>

. (Join-Path $PSScriptRoot 'NetBoost.State.ps1')

function Get-NetBoostNetworkThrottleText {
    if ($Language -eq 'EN') {
        return @{
            Header           = "WINDOWS NETWORK THROTTLING DIAGNOSTIC & OPTIMIZER"
            SubHeader        = "Scans Windows settings that throttle or restrict network bandwidth"
            OptimalBadge     = "[OPTIMAL]"
            WarningBadge     = "[WARNING]"
            ThrottledBadge   = "[THROTTLED]"
            UnknownBadge     = "[INFO]"
            SummaryHealthy   = "All checked settings are running at optimal throughput."
            SummaryIssues    = "Found {0} setting(s) restricting network bandwidth or causing latency."
            MenuOptimize     = "1-Click Optimize all (apply maximum throughput settings + auto backup)"
            MenuRestore      = "Restore previous settings from backup"
            MenuRefresh      = "Rescan settings now"
            MenuBack         = "Back to main menu"
            PromptChoice     = "Enter choice [0-3]"
            OptSuccess       = "Successfully optimized network settings! Saved backup to: {0}"
            OptFailed        = "Failed to optimize network settings: {0}"
            RestoreSuccess   = "Successfully restored network settings from backup: {0}"
            RestoreFailed    = "Failed to restore network settings: {0}"
            RestoreDefault   = "Restored network settings to Windows standard defaults."
            NoBackupFound    = "No previous backup found at {0}. Resetting to Windows standard defaults."
            BackupSaved      = "Configuration backup saved to: {0}"
            ActionCancelled  = "Operation cancelled."
            HardwareNotice   = "Link Speed is hardware-dependent (check LAN cable or switch port if capped at 100 Mbps)."
            ItemNti          = "Multimedia Network Throttling (NetworkThrottlingIndex)"
            ItemNtiDesc      = "Default 10 throttles network packets during audio/video playback"
            ItemResp         = "System Responsiveness (SystemResponsiveness)"
            ItemRespDesc     = "Default 20 reserves 20% CPU for background tasks; values below 10 are treated by Windows as 20"
            ItemTcpTune      = "TCP Window Auto-Tuning Level"
            ItemTcpTuneDesc  = "Disabled/Restricted severely caps high-speed download throughput"
            ItemRss          = "Receive-Side Scaling (RSS)"
            ItemRssDesc      = "Distributes network packet processing across multiple CPU cores"
            ItemQos          = "QoS Reservable Bandwidth (NonBestEffortLimit)"
            ItemQosDesc      = "Limits reservable bandwidth for QoS-enabled apps (default does not reserve bandwidth without QoS requests)"
            ItemDo           = "Windows Delivery Optimization P2P (WUDO)"
            ItemDoDesc       = "Uploads Windows updates to other PCs on Internet, consuming upload bandwidth"
            ItemLinkSpeed    = "Primary Adapter Link Speed"
            ItemLinkDesc     = "Hardware connection speed negotiated with your router/switch"
        }
    }

    return @{
        Header           = "CHUAN DOAN & TOI UU BOP NGHEN BANG THONG WINDOWS"
        SubHeader        = "Quet cac thiet lap Windows dang lam giam hoac bop bang thong mang"
        OptimalBadge     = "[TOI UU]"
        WarningBadge     = "[CANH BAO]"
        ThrottledBadge   = "[BOP NGHEN]"
        UnknownBadge     = "[THONG TIN]"
        SummaryHealthy   = "Tat ca thiet lap mang dang o trang thai toi da bang thong."
        SummaryIssues    = "Phat hien {0} thiet lap dang lam han che bang thong hoac gay do tre."
        MenuOptimize     = "1-Click Toi uu tat ca (Ap dung muc toi da & tu dong sao luu)"
        MenuRestore      = "Khoi phuc thiet lap tu ban sao luu"
        MenuRefresh      = "Quet lai trang thai ngay bay gio"
        MenuBack         = "Quay lai menu chinh"
        PromptChoice     = "Nhap lua chon cua ban [0-3]"
        OptSuccess       = "Da toi uu thanh cong toan bo thiet lap mang! Sao luu tai: {0}"
        OptFailed        = "Khong the toi uu thiet lap mang: {0}"
        RestoreSuccess   = "Da khoi phuc thanh cong thiet lap tu ban sao luu: {0}"
        RestoreFailed    = "Khong the khoi phuc thiet lap mang: {0}"
        RestoreDefault   = "Da khoi phuc thiet lap ve mac dinh chuan cua Windows."
        NoBackupFound    = "Khong tim thay file sao luu tai {0}. Dang dat ve mac dinh Windows."
        BackupSaved      = "Da sao luu cau hinh hien tai vao: {0}"
        ActionCancelled  = "Da huy thao tac."
        HardwareNotice   = "Toc do link card mang phu thuoc phan cung (kiem tra day LAN neu chi nhan 100 Mbps)."
        ItemNti          = "Windows Multimedia Network Throttling (NetworkThrottlingIndex)"
        ItemNtiDesc      = "Mac dinh 10 bop goi tin mang khi dang phat am thanh/media"
        ItemResp         = "System Responsiveness (SystemResponsiveness)"
        ItemRespDesc     = "Mac dinh 20 giu 20% CPU cho tac vu nen; gia tri duoi 10 duoc Windows tu dong quy ve 20"
        ItemTcpTune      = "TCP Window Auto-Tuning Level"
        ItemTcpTuneDesc  = "Neu bi Disabled se bop bang thong download chi con vai chuc Mbps"
        ItemRss          = "Receive-Side Scaling (RSS)"
        ItemRssDesc      = "Phan bo xu ly goi tin mang tren tat ca cac nhan CPU"
        ItemQos          = "QoS Reservable Bandwidth (NonBestEffortLimit)"
        ItemQosDesc      = "Gioi han bang thong du phong cho cac ung dung QoS (mac dinh khong chiem giu khi khong co ung dung yeu cau)"
        ItemDo           = "Windows Delivery Optimization P2P (WUDO)"
        ItemDoDesc       = "Am tham upload ban cap nhat Windows ra Internet gay lag mang"
        ItemLinkSpeed    = "Toc do ket noi Card mang (Link Speed)"
        ItemLinkDesc     = "Toc do phan cung thuong luong voi Router/Switch"
    }
}

function Get-NetworkThrottleDefinitions {
    return @(
        [pscustomobject]@{
            Id          = 'network-throttling-index'
            Name        = 'NetworkThrottlingIndex'
            OptimalVal  = [uint32]::MaxValue
            DefaultVal  = 10
            Type        = 'Registry'
            RegPath     = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
            RegName     = 'NetworkThrottlingIndex'
        },
        [pscustomobject]@{
            Id          = 'system-responsiveness'
            Name        = 'SystemResponsiveness'
            OptimalVal  = 10
            DefaultVal  = 20
            Type        = 'Registry'
            RegPath     = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
            RegName     = 'SystemResponsiveness'
        },
        [pscustomobject]@{
            Id          = 'tcp-autotuning'
            Name        = 'TCP AutoTuning'
            OptimalVal  = 'Normal'
            DefaultVal  = 'Normal'
            Type        = 'NetTcp'
        },
        [pscustomobject]@{
            Id          = 'receive-side-scaling'
            Name        = 'RSS'
            OptimalVal  = 'Enabled'
            DefaultVal  = 'Enabled'
            Type        = 'NetTcp'
        },
        [pscustomobject]@{
            Id          = 'qos-limit'
            Name        = 'NonBestEffortLimit'
            OptimalVal  = 'Preserve existing QoS policy'
            DefaultVal  = $null
            Type        = 'Registry'
            RegPath     = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched'
            RegName     = 'NonBestEffortLimit'
        },
        [pscustomobject]@{
            Id          = 'delivery-optimization'
            Name        = 'DODownloadMode'
            OptimalVal  = 0
            DefaultVal  = $null
            Type        = 'Registry'
            RegPath     = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config'
            RegName     = 'DODownloadMode'
        },
        [pscustomobject]@{
            Id          = 'link-speed'
            Name        = 'LinkSpeed'
            OptimalVal  = '1 Gbps+'
            DefaultVal  = 'Auto'
            Type        = 'Adapter'
        }
    )
}

function Get-NetworkThrottleDefaultBackupPath {
    $baseDir = Join-Path $env:LOCALAPPDATA 'NetBoost'
    return (Join-Path $baseDir 'backup-network-throttle.json')
}

function Test-NetworkThrottleBackupFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return @{ Valid = $false; Error = "File does not exist"; NotFound = $true }
    }

    try {
        $content = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
        if ([string]::IsNullOrWhiteSpace($content)) {
            return @{ Valid = $false; Error = "Backup file is empty" }
        }
        $parsed = $content | ConvertFrom-Json
        if (-not $parsed -or -not $parsed.State) {
            return @{ Valid = $false; Error = "Backup file is missing 'State' payload" }
        }
        $stateObj = $parsed.State
        $propNames = if ($stateObj -is [hashtable]) { @($stateObj.Keys) } else { @($stateObj.PSObject.Properties.Name) }
        $requiredKeys = @('NetworkThrottlingIndex', 'SystemResponsiveness', 'AutoTuningLevel', 'RSS', 'NonBestEffortLimit', 'DODownloadMode')
        foreach ($k in $requiredKeys) {
            if ($propNames -notcontains $k) {
                return @{ Valid = $false; Error = "Backup state is missing required property: $k" }
            }
        }
        foreach ($key in @('NetworkThrottlingIndex','SystemResponsiveness','NonBestEffortLimit','DODownloadMode')) {
            $value=$stateObj.$key
            if($null -ne $value -and (($value -isnot [int] -and $value -isnot [long] -and $value -isnot [uint32]) -or [decimal]$value -lt 0 -or [decimal]$value -gt [uint32]::MaxValue)) {
                return @{ Valid=$false; Error="Invalid DWORD in backup: $key" }
            }
        }
        if($stateObj.AutoTuningLevel -isnot [string] -or $stateObj.AutoTuningLevel -notin @('Disabled','HighlyRestricted','Restricted','Normal','Experimental')) {
            return @{ Valid=$false; Error='Original TCP auto-tuning level is not recoverable.' }
        }
        if($stateObj.RSS -isnot [string] -or $stateObj.RSS -notin @('Enabled','Disabled')) {
            return @{ Valid=$false; Error='Original RSS state is not recoverable.' }
        }
        if($parsed.PSObject.Properties.Name -contains 'Restored' -and $parsed.Restored -isnot [bool]) {
            return @{ Valid=$false; Error='Invalid backup lifecycle flag.' }
        }
        $isRestored = ($parsed.PSObject.Properties.Name -contains 'Restored' -and $parsed.Restored -eq $true)
        return @{ Valid = $true; Restored = $isRestored; Parsed = $parsed }
    } catch {
        return @{ Valid = $false; Error = $_.Exception.Message }
    }
}

function Remove-RegistryPropertySafely {
    param(
        [string]$LiteralPath,
        [string]$Name
    )

    try {
        Remove-ItemProperty -LiteralPath $LiteralPath -Name $Name -ErrorAction Stop
        return $null
    } catch {
        $cat = [string]$_.CategoryInfo.Category
        $msg = [string]$_.Exception.Message
        # If the property does not exist, removal is already achieved (idempotent)
        if ($cat -eq 'ObjectNotFound' -or
            $cat -eq 'ItemNotFound' -or
            $msg -match 'does not exist' -or
            $msg -match 'cannot be found' -or
            $msg -match 'Property .+ does not exist') {
            return $null
        }
        return "Restore $Name failed: $msg"
    }
}

function Get-LiveNetworkThrottleState {
    $state = @{
        NetworkThrottlingIndex = $null
        SystemResponsiveness   = $null
        AutoTuningLevel        = 'Unknown'
        RSS                    = 'Unknown'
        NonBestEffortLimit     = $null
        DODownloadMode         = $null
        LinkSpeed              = 'Unknown'
    }

    # 1. Multimedia Profile
    $mmPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
    if (Test-Path -LiteralPath $mmPath) {
        try {
            $nti = Get-ItemPropertyValue -LiteralPath $mmPath -Name 'NetworkThrottlingIndex' -ErrorAction SilentlyContinue
            if ($null -ne $nti) { $state.NetworkThrottlingIndex = [int64]$nti }
            $sr = Get-ItemPropertyValue -LiteralPath $mmPath -Name 'SystemResponsiveness' -ErrorAction SilentlyContinue
            if ($null -ne $sr) { $state.SystemResponsiveness = [int64]$sr }
        } catch {}
    }

    # 2. TCP Settings
    try {
        $tcp = Get-NetTCPSetting -SettingName 'Internet' -ErrorAction SilentlyContinue
        if ($tcp) {
            $state.AutoTuningLevel = [string]$tcp.AutoTuningLevelLocal
        }
    } catch {}

    # RSS from Get-NetOffloadGlobalSetting
    try {
        $offload = Get-NetOffloadGlobalSetting -ErrorAction SilentlyContinue
        if ($offload -and $offload.ReceiveSideScaling) {
            $state.RSS = [string]$offload.ReceiveSideScaling
        }
    } catch {}

    # Fallback to netsh if either AutoTuningLevel or RSS is missing/unknown
    if (-not $state.AutoTuningLevel -or $state.AutoTuningLevel -eq 'Unknown' -or -not $state.RSS -or $state.RSS -eq 'Unknown') {
        try {
            $netsh = netsh int tcp show global 2>$null | Out-String
            if ((-not $state.AutoTuningLevel -or $state.AutoTuningLevel -eq 'Unknown') -and $netsh -match 'Receive Window Auto-Tuning Level\s*:\s*(\w+)') {
                $state.AutoTuningLevel = $Matches[1]
            }
            if ((-not $state.RSS -or $state.RSS -eq 'Unknown') -and $netsh -match 'Receive-Side Scaling State\s*:\s*(\w+)') {
                $state.RSS = $Matches[1]
            }
        } catch {}
    }

    # 3. QoS
    $qosPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched'
    if (Test-Path -LiteralPath $qosPath) {
        try {
            $limit = Get-ItemPropertyValue -LiteralPath $qosPath -Name 'NonBestEffortLimit' -ErrorAction SilentlyContinue
            if ($null -ne $limit) { $state.NonBestEffortLimit = [int64]$limit }
        } catch {}
    }

    # 4. Delivery Optimization
    $doPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config'
    if (Test-Path -LiteralPath $doPath) {
        try {
            $dom = Get-ItemPropertyValue -LiteralPath $doPath -Name 'DODownloadMode' -ErrorAction SilentlyContinue
            if ($null -ne $dom) { $state.DODownloadMode = [int64]$dom }
        } catch {}
    }

    # 5. Adapter Link Speed
    try {
        $adapter = $null
        if (Get-Command Get-GameAdapter -ErrorAction SilentlyContinue) {
            $adapter = Get-GameAdapter
        } else {
            $adapter = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
        }
        if ($adapter -and $adapter.LinkSpeed) {
            $state.LinkSpeed = [string]$adapter.LinkSpeed
        }
    } catch {}

    return $state
}

function Get-NetworkThrottleStatus {
    param(
        [hashtable]$StateOverride = $null
    )

    $state = if ($StateOverride) { $StateOverride } else { Get-LiveNetworkThrottleState }
    $items = [Collections.Generic.List[object]]::new()

    # 1. NetworkThrottlingIndex
    $nti = $state.NetworkThrottlingIndex
    $ntiStatus = 'Optimal'
    $ntiDisplay = ''
    if ($null -eq $nti) {
        $ntiStatus = 'Throttled'
        $ntiDisplay = 'Not Set (Windows defaults to 10)'
    } elseif ($nti -eq 0xFFFFFFFF -or $nti -eq 4294967295 -or $nti -eq -1) {
        $ntiStatus = 'Optimal'
        $ntiDisplay = '0xFFFFFFFF (Disabled - No Throttling)'
    } elseif ($nti -eq 10) {
        $ntiStatus = 'Throttled'
        $ntiDisplay = '10 (Default Windows Multimedia Throttling)'
    } else {
        $ntiStatus = 'Warning'
        $ntiDisplay = "$nti (Custom)"
    }
    $items.Add([pscustomobject]@{
        Id          = 'network-throttling-index'
        CurrentVal  = $nti
        DisplayVal  = $ntiDisplay
        Status      = $ntiStatus
        OptimalVal  = '0xFFFFFFFF (Disabled)'
    })

    # 2. SystemResponsiveness
    $sr = $state.SystemResponsiveness
    $srStatus = 'Optimal'
    $srDisplay = ''
    if ($null -eq $sr) {
        $srStatus = 'Optimal'
        $srDisplay = 'Not Set (Windows default 20%)'
    } elseif ($sr -eq 10) {
        $srStatus = 'Optimal'
        $srDisplay = '10% (Minimum valid reservation for background tasks)'
    } elseif ($sr -eq 20) {
        $srStatus = 'Optimal'
        $srDisplay = '20% (Windows default)'
    } elseif ($sr -lt 10) {
        $srStatus = 'Warning'
        $srDisplay = "$sr% (Treated as 20% by Windows MMCSS)"
    } else {
        $srStatus = 'Warning'
        $srDisplay = "$sr% Reserved"
    }
    $items.Add([pscustomobject]@{
        Id          = 'system-responsiveness'
        CurrentVal  = $sr
        DisplayVal  = $srDisplay
        Status      = $srStatus
        OptimalVal  = '10% or 20%'
    })

    # 3. TCP Window Auto-Tuning
    $tune = [string]$state.AutoTuningLevel
    $tuneStatus = 'Optimal'
    if ($tune -match 'Disabled|HighlyRestricted|Restricted') {
        $tuneStatus = 'Throttled'
    } elseif ($tune -match 'Experimental') {
        $tuneStatus = 'Warning'
    } elseif ($tune -match 'Normal') {
        $tuneStatus = 'Optimal'
    } else {
        $tuneStatus = 'Warning'
    }
    $items.Add([pscustomobject]@{
        Id          = 'tcp-autotuning'
        CurrentVal  = $tune
        DisplayVal  = $tune
        Status      = $tuneStatus
        OptimalVal  = 'Normal'
    })

    # 4. RSS
    $rss = [string]$state.RSS
    $rssStatus = 'Optimal'
    if ($rss -match 'Disabled') {
        $rssStatus = 'Warning'
    } elseif ($rss -match 'Enabled') {
        $rssStatus = 'Optimal'
    } else {
        $rssStatus = 'Warning'
    }
    $items.Add([pscustomobject]@{
        Id          = 'receive-side-scaling'
        CurrentVal  = $rss
        DisplayVal  = $rss
        Status      = $rssStatus
        OptimalVal  = 'Enabled'
    })

    # 5. QoS NonBestEffortLimit
    $qos = $state.NonBestEffortLimit
    $qosStatus = 'Optimal'
    $qosDisplay = ''
    if ($null -eq $qos) {
        $qosStatus = 'Optimal'
        $qosDisplay = 'Not Configured (Standard OS Behavior)'
    } elseif ($qos -eq 0) {
        $qosStatus = 'Optimal'
        $qosDisplay = '0% (Disabled Bandwidth Reservation)'
    } elseif ($qos -ge 0 -and $qos -le 100) {
        $qosStatus = 'Optimal'
        $qosDisplay = "$qos% Reservable ceiling (not a fixed bandwidth cap)"
    } else {
        $qosStatus = 'Warning'
        $qosDisplay = "$qos% Bandwidth Reservable"
    }
    $items.Add([pscustomobject]@{
        Id          = 'qos-limit'
        CurrentVal  = $qos
        DisplayVal  = $qosDisplay
        Status      = $qosStatus
        OptimalVal  = 'Preserve existing QoS policy'
    })

    # 6. Delivery Optimization
    $dom = $state.DODownloadMode
    $domStatus = 'Optimal'
    $domDisplay = ''
    if ($null -eq $dom) {
        $domStatus = 'Optimal'
        $domDisplay = 'Not Configured (Standard Windows Peering)'
    } elseif ($dom -eq 0) {
        $domStatus = 'Optimal'
        $domDisplay = '0 (HTTP Only - No P2P Upload)'
    } elseif ($dom -eq 1) {
        $domStatus = 'Optimal'
        $domDisplay = '1 (Local Network LAN Only)'
    } elseif ($dom -eq 3) {
        $domStatus = 'Warning'
        $domDisplay = '3 (Internet P2P Peering Enabled)'
    } elseif ($dom -eq 99) {
        $domStatus = 'Optimal'
        $domDisplay = '99 (Simple Mode - No P2P)'
    } else {
        $domStatus = 'Warning'
        $domDisplay = "$dom (Custom Mode)"
    }
    $items.Add([pscustomobject]@{
        Id          = 'delivery-optimization'
        CurrentVal  = $dom
        DisplayVal  = $domDisplay
        Status      = $domStatus
        OptimalVal  = '0 (HTTP Only) or Default'
    })

    # 7. Link Speed
    $link = [string]$state.LinkSpeed
    $linkStatus = 'Optimal'
    if ($link -match '100 Mbps') {
        $linkStatus = 'Warning'
    }
    $items.Add([pscustomobject]@{
        Id          = 'link-speed'
        CurrentVal  = $link
        DisplayVal  = $link
        Status      = $linkStatus
        OptimalVal  = '1 Gbps+'
    })

    $warningCount = @($items | Where-Object { $_.Status -eq 'Warning' }).Count
    $throttledCount = @($items | Where-Object { $_.Status -eq 'Throttled' }).Count
    $issuesCount = $warningCount + $throttledCount

    return [pscustomobject]@{
        Items          = @($items)
        IssuesCount    = $issuesCount
        ThrottledCount = $throttledCount
        WarningCount   = $warningCount
        RawState       = $state
    }
}

function Backup-NetworkThrottleState {
    param(
        [hashtable]$State,
        [string]$Path
    )

    # If backup already exists at this path, validate it
    if (Test-Path -LiteralPath $Path) {
        $validation = Test-NetworkThrottleBackupFile -Path $Path
        if (-not $validation.Valid) {
            throw "Existing backup file at '$Path' is invalid or corrupt: $($validation.Error)"
        }
        # If the existing backup was already restored (cycle finished), allow capturing new baseline
        if (-not $validation.Restored) {
            # Active baseline exists; do not overwrite
            return
        }
    }

    $parentDir = [System.IO.Path]::GetDirectoryName($Path)
    if (-not [string]::IsNullOrEmpty($parentDir) -and -not (Test-Path -LiteralPath $parentDir)) {
        [System.IO.Directory]::CreateDirectory($parentDir) | Out-Null
    }

    $backupPayload = [pscustomobject]@{
        Timestamp = (Get-Date -Format 'o')
        Restored  = $false
        State     = $State
    }

    # Validate the snapshot before it can authorize changes, including live Unknown reads.
    $validationPath=Join-Path ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path))) ('.validate-' + [guid]::NewGuid().ToString('N') + '.json')
    try {
        Write-NetBoostJsonFile -Path $validationPath -Value $backupPayload -NoOverwrite
        $check=Test-NetworkThrottleBackupFile -Path $validationPath
        if(-not $check.Valid){ throw $check.Error }
    } finally { if([IO.File]::Exists($validationPath)){ [IO.File]::Delete($validationPath) } }
    Write-NetBoostJsonFile -Path $Path -Value $backupPayload

    # Immediately verify written file exists and can be parsed
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Failed to verify backup file creation at '$Path'."
    }
}

function Optimize-NetworkThrottle {
    param(
        [hashtable]$StateOverride = $null,
        [string]$BackupFilePath = $null,
        [bool]$ApplyChanges = $true
    )

    $targetBackup = if ($BackupFilePath) { $BackupFilePath } else { Get-NetworkThrottleDefaultBackupPath }
    $currentState = if ($StateOverride) { $StateOverride } else { Get-LiveNetworkThrottleState }

    if(-not $ApplyChanges){ return [pscustomobject]@{ Success=$true; Errors=@(); BackupPath=$targetBackup; State=$currentState; DryRun=$true } }

    # Save initial baseline backup before applying (blocking check)
    try {
        Backup-NetworkThrottleState -State $currentState -Path $targetBackup
    } catch {
        return [pscustomobject]@{
            Success    = $false
            Errors     = @("Backup creation/verification failed: $($_.Exception.Message)")
            BackupPath = $targetBackup
            State      = $currentState
        }
    }

    if ($StateOverride) {
        $StateOverride.NetworkThrottlingIndex = [uint32]::MaxValue
        $StateOverride.SystemResponsiveness   = 10
        $StateOverride.AutoTuningLevel        = 'Normal'
        $StateOverride.RSS                    = 'Enabled'
        # QoS is not a fixed bandwidth loss; preserve voice/media reservations.
        $StateOverride.DODownloadMode         = 0
        return [pscustomobject]@{
            Success        = $true
            Errors         = @()
            BackupPath     = $targetBackup
            State          = $StateOverride
        }
    }

    $capturedErrors = [Collections.Generic.List[string]]::new()

    if ($ApplyChanges) {
        if (Get-Command Ensure-Admin -ErrorAction SilentlyContinue) {
            Ensure-Admin
        }

        # 1. NetworkThrottlingIndex & SystemResponsiveness
        $mmPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
        try {
            if (-not (Test-Path -LiteralPath $mmPath)) {
                New-Item -Path $mmPath -Force -ErrorAction Stop | Out-Null
            }
            Set-ItemProperty -LiteralPath $mmPath -Name 'NetworkThrottlingIndex' -Value ([uint32]::MaxValue) -Type DWord -Force -ErrorAction Stop
        } catch {
            $capturedErrors.Add("NetworkThrottlingIndex write failed: $($_.Exception.Message)")
        }

        try {
            Set-ItemProperty -LiteralPath $mmPath -Name 'SystemResponsiveness' -Value ([uint32]10) -Type DWord -Force -ErrorAction Stop
        } catch {
            $capturedErrors.Add("SystemResponsiveness write failed: $($_.Exception.Message)")
        }

        # Preserve QoS policy; reservable bandwidth is not an always-active cap.

        # 3. Delivery Optimization DODownloadMode = 0 (HTTP only, disable P2P upload)
        $doPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config'
        try {
            if (-not (Test-Path -LiteralPath $doPath)) {
                New-Item -Path $doPath -Force -ErrorAction Stop | Out-Null
            }
            Set-ItemProperty -LiteralPath $doPath -Name 'DODownloadMode' -Value ([uint32]0) -Type DWord -Force -ErrorAction Stop
        } catch {
            $capturedErrors.Add("DODownloadMode write failed: $($_.Exception.Message)")
        }

        # 4. TCP Window Auto-Tuning & RSS
        try {
            $netshTune = netsh int tcp set global autotuninglevel=normal 2>&1
            if ($LASTEXITCODE -ne 0) {
                $capturedErrors.Add("netsh autotuninglevel failed: $netshTune")
            }
        } catch {
            $capturedErrors.Add("netsh autotuninglevel exception: $($_.Exception.Message)")
        }

        try {
            $netshRss = netsh int tcp set global rss=enabled 2>&1
            if ($LASTEXITCODE -ne 0) {
                $capturedErrors.Add("netsh rss failed: $netshRss")
            }
        } catch {
            $capturedErrors.Add("netsh rss exception: $($_.Exception.Message)")
        }
    }

    $isSuccess = ($capturedErrors.Count -eq 0)
    return [pscustomobject]@{
        Success    = $isSuccess
        Errors     = @($capturedErrors)
        BackupPath = $targetBackup
        State      = (Get-LiveNetworkThrottleState)
    }
}

function Restore-NetworkThrottle {
    param(
        [hashtable]$StateOverride = $null,
        [string]$BackupFilePath = $null,
        [bool]$ApplyChanges = $true
    )

    $targetBackup = if ($BackupFilePath) { $BackupFilePath } else { Get-NetworkThrottleDefaultBackupPath }
    $restoredFromBackup = $false
    $savedState = $null
    $currentState = if ($StateOverride) { $StateOverride } else { Get-LiveNetworkThrottleState }

    if(-not $ApplyChanges){ return [pscustomobject]@{ Success=$true; Errors=@(); RestoredFromBackup=$false; BackupPath=$targetBackup; State=$currentState; DryRun=$true } }

    if(-not(Test-Path -LiteralPath $targetBackup -PathType Leaf)){
        return [pscustomobject]@{Success=$false;Errors=@('No network backup found. Restore did not change any settings.');RestoredFromBackup=$false;BackupPath=$targetBackup;State=$currentState}
    }

    if (Test-Path -LiteralPath $targetBackup) {
        $backupCheck = Test-NetworkThrottleBackupFile -Path $targetBackup
        if (-not $backupCheck.Valid) {
            return [pscustomobject]@{
                Success            = $false
                Errors             = @("Backup file at '$targetBackup' is invalid or corrupt: $($backupCheck.Error)")
                RestoredFromBackup = $false
                BackupPath         = $targetBackup
                State              = $currentState
            }
        }
        $savedState = $backupCheck.Parsed.State
        $restoredFromBackup = $true
    }

    if ($StateOverride) {
        if ($restoredFromBackup -and $savedState) {
            $StateOverride.NetworkThrottlingIndex = $savedState.NetworkThrottlingIndex
            $StateOverride.SystemResponsiveness   = $savedState.SystemResponsiveness
            $StateOverride.AutoTuningLevel        = $savedState.AutoTuningLevel
            $StateOverride.RSS                    = $savedState.RSS
            $StateOverride.NonBestEffortLimit     = $savedState.NonBestEffortLimit
            $StateOverride.DODownloadMode         = $savedState.DODownloadMode
        } else {
            # Windows standard defaults (unconfigured properties set to $null)
            $StateOverride.NetworkThrottlingIndex = 10
            $StateOverride.SystemResponsiveness   = 20
            $StateOverride.AutoTuningLevel        = 'Normal'
            $StateOverride.RSS                    = 'Enabled'
            $StateOverride.NonBestEffortLimit     = $null
            $StateOverride.DODownloadMode         = $null
        }

        # Mark backup as restored if a valid backup existed
        if ($restoredFromBackup -and (Test-Path -LiteralPath $targetBackup)) {
            try {
                $backupPayload = [pscustomobject]@{
                    Timestamp = (Get-Date -Format 'o')
                    Restored  = $true
                    State     = $savedState
                }
                Write-NetBoostJsonFile -Path $targetBackup -Value $backupPayload
            } catch {
                return [pscustomobject]@{ Success=$false; Errors=@("Settings restored but backup completion could not be saved: $($_.Exception.Message)"); RestoredFromBackup=$true; BackupPath=$targetBackup; State=$StateOverride }
            }
        }

        return [pscustomobject]@{
            Success            = $true
            Errors             = @()
            RestoredFromBackup = $restoredFromBackup
            BackupPath         = $targetBackup
            State              = $StateOverride
        }
    }

    $capturedErrors = [Collections.Generic.List[string]]::new()

    if ($ApplyChanges) {
        if (Get-Command Ensure-Admin -ErrorAction SilentlyContinue) {
            Ensure-Admin
        }

        $mmPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
        $qosPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched'
        $doPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config'

        if ($restoredFromBackup -and $savedState) {
            # 1. NetworkThrottlingIndex
            try {
                if ($null -ne $savedState.NetworkThrottlingIndex) {
                    Set-ItemProperty -LiteralPath $mmPath -Name 'NetworkThrottlingIndex' -Value ([uint32]$savedState.NetworkThrottlingIndex) -Type DWord -Force -ErrorAction Stop
                } else {
                    $err = Remove-RegistryPropertySafely -LiteralPath $mmPath -Name 'NetworkThrottlingIndex'
                    if ($err) { $capturedErrors.Add($err) }
                }
            } catch {
                $capturedErrors.Add("Restore NetworkThrottlingIndex failed: $($_.Exception.Message)")
            }

            # 2. SystemResponsiveness
            try {
                if ($null -ne $savedState.SystemResponsiveness) {
                    Set-ItemProperty -LiteralPath $mmPath -Name 'SystemResponsiveness' -Value ([uint32]$savedState.SystemResponsiveness) -Type DWord -Force -ErrorAction Stop
                } else {
                    $err = Remove-RegistryPropertySafely -LiteralPath $mmPath -Name 'SystemResponsiveness'
                    if ($err) { $capturedErrors.Add($err) }
                }
            } catch {
                $capturedErrors.Add("Restore SystemResponsiveness failed: $($_.Exception.Message)")
            }

            # 3. NonBestEffortLimit
            try {
                if ($null -ne $savedState.NonBestEffortLimit) {
                    Set-ItemProperty -LiteralPath $qosPath -Name 'NonBestEffortLimit' -Value ([uint32]$savedState.NonBestEffortLimit) -Type DWord -Force -ErrorAction Stop
                } else {
                    $err = Remove-RegistryPropertySafely -LiteralPath $qosPath -Name 'NonBestEffortLimit'
                    if ($err) { $capturedErrors.Add($err) }
                }
            } catch {
                $capturedErrors.Add("Restore NonBestEffortLimit failed: $($_.Exception.Message)")
            }

            # 4. DODownloadMode
            try {
                if ($null -ne $savedState.DODownloadMode) {
                    Set-ItemProperty -LiteralPath $doPath -Name 'DODownloadMode' -Value ([uint32]$savedState.DODownloadMode) -Type DWord -Force -ErrorAction Stop
                } else {
                    $err = Remove-RegistryPropertySafely -LiteralPath $doPath -Name 'DODownloadMode'
                    if ($err) { $capturedErrors.Add($err) }
                }
            } catch {
                $capturedErrors.Add("Restore DODownloadMode failed: $($_.Exception.Message)")
            }

            # 5. TCP Settings
            $targetTune = if ($savedState.AutoTuningLevel -and $savedState.AutoTuningLevel -ne 'Unknown') { $savedState.AutoTuningLevel } else { 'normal' }
            try {
                $netshTune = netsh int tcp set global autotuninglevel=$targetTune 2>&1
                if ($LASTEXITCODE -ne 0) {
                    $capturedErrors.Add("netsh restore autotuninglevel failed: $netshTune")
                }
            } catch {
                $capturedErrors.Add("netsh restore autotuninglevel exception: $($_.Exception.Message)")
            }

            $targetRss = if ($savedState.RSS -and $savedState.RSS -ne 'Unknown') { $savedState.RSS } else { 'enabled' }
            try {
                $netshRss = netsh int tcp set global rss=$targetRss 2>&1
                if ($LASTEXITCODE -ne 0) {
                    $capturedErrors.Add("netsh restore rss failed: $netshRss")
                }
            } catch {
                $capturedErrors.Add("netsh restore rss exception: $($_.Exception.Message)")
            }
        } else {
            # Restore to standard Windows defaults when no backup exists
            try {
                Set-ItemProperty -LiteralPath $mmPath -Name 'NetworkThrottlingIndex' -Value ([uint32]10) -Type DWord -Force -ErrorAction Stop
            } catch {
                $capturedErrors.Add("Default restore NetworkThrottlingIndex failed: $($_.Exception.Message)")
            }

            try {
                Set-ItemProperty -LiteralPath $mmPath -Name 'SystemResponsiveness' -Value ([uint32]20) -Type DWord -Force -ErrorAction Stop
            } catch {
                $capturedErrors.Add("Default restore SystemResponsiveness failed: $($_.Exception.Message)")
            }

            $errQos = Remove-RegistryPropertySafely -LiteralPath $qosPath -Name 'NonBestEffortLimit'
            if ($errQos) { $capturedErrors.Add("Default restore NonBestEffortLimit failed: $errQos") }

            # Remove DODownloadMode to allow Windows to use its OS default mode (not forcing mode 3)
            $errDo = Remove-RegistryPropertySafely -LiteralPath $doPath -Name 'DODownloadMode'
            if ($errDo) { $capturedErrors.Add("Default restore DODownloadMode failed: $errDo") }

            try {
                $netshTune = netsh int tcp set global autotuninglevel=normal 2>&1
                if ($LASTEXITCODE -ne 0) {
                    $capturedErrors.Add("netsh default autotuninglevel failed: $netshTune")
                }
            } catch {
                $capturedErrors.Add("netsh default autotuninglevel exception: $($_.Exception.Message)")
            }

            try {
                $netshRss = netsh int tcp set global rss=enabled 2>&1
                if ($LASTEXITCODE -ne 0) {
                    $capturedErrors.Add("netsh default rss failed: $netshRss")
                }
            } catch {
                $capturedErrors.Add("netsh default rss exception: $($_.Exception.Message)")
            }
        }
    }

    $isSuccess = ($capturedErrors.Count -eq 0)

    # Mark backup as restored if restore was completely successful
    if ($isSuccess -and $restoredFromBackup -and (Test-Path -LiteralPath $targetBackup)) {
        try {
            $backupPayload = [pscustomobject]@{
                Timestamp = (Get-Date -Format 'o')
                Restored  = $true
                State     = $savedState
            }
            Write-NetBoostJsonFile -Path $targetBackup -Value $backupPayload
        } catch {
            $isSuccess=$false
            $capturedErrors.Add("Settings restored but backup completion could not be saved: $($_.Exception.Message)")
        }
    }

    return [pscustomobject]@{
        Success            = $isSuccess
        Errors             = @($capturedErrors)
        RestoredFromBackup = $restoredFromBackup
        BackupPath         = $targetBackup
        State              = (Get-LiveNetworkThrottleState)
    }
}

function Show-NetworkThrottleCenter {
    param(
        [scriptblock]$InputReader = $null
    )

    $ui = Get-NetBoostNetworkThrottleText

    while ($true) {
        $status = Get-NetworkThrottleStatus

        if (Get-Command Write-UiHeader -ErrorAction SilentlyContinue) {
            Write-UiHeader $ui.Header 'Tools'
        } else {
            Clear-Host
            Write-Host "=== $($ui.Header) ===" -ForegroundColor Cyan
        }

        if (Get-Command Write-Line -ErrorAction SilentlyContinue) {
            Write-Line "  $($ui.SubHeader)" Gray
            Write-Line ''
        } else {
            Write-Host "  $($ui.SubHeader)`n" -ForegroundColor Gray
        }

        # Print Items Table
        foreach ($item in $status.Items) {
            $badgeColor = [ConsoleColor]::Green
            $badgeText = $ui.OptimalBadge
            if ($item.Status -eq 'Throttled') {
                $badgeColor = [ConsoleColor]::Red
                $badgeText = $ui.ThrottledBadge
            } elseif ($item.Status -eq 'Warning') {
                $badgeColor = [ConsoleColor]::Yellow
                $badgeText = $ui.WarningBadge
            }

            $title = switch ($item.Id) {
                'network-throttling-index' { $ui.ItemNti }
                'system-responsiveness'   { $ui.ItemResp }
                'tcp-autotuning'          { $ui.ItemTcpTune }
                'receive-side-scaling'    { $ui.ItemRss }
                'qos-limit'               { $ui.ItemQos }
                'delivery-optimization'   { $ui.ItemDo }
                'link-speed'              { $ui.ItemLinkSpeed }
                default                   { $item.Id }
            }

            Write-Host ("  {0,-14} " -f $badgeText) -NoNewline -ForegroundColor $badgeColor
            Write-Host ("{0}" -f $title) -ForegroundColor White
            Write-Host ("                 -> $($item.DisplayVal)") -ForegroundColor Gray
        }

        Write-Host ''
        if ($status.IssuesCount -eq 0) {
            if (Get-Command Write-Status -ErrorAction SilentlyContinue) {
                Write-Status Ok $ui.SummaryHealthy
            } else {
                Write-Host "  [OK] $($ui.SummaryHealthy)" -ForegroundColor Green
            }
        } else {
            if (Get-Command Write-Status -ErrorAction SilentlyContinue) {
                Write-Status Warning ($ui.SummaryIssues -f $status.IssuesCount)
            } else {
                Write-Host ("  [!] " + ($ui.SummaryIssues -f $status.IssuesCount)) -ForegroundColor Yellow
            }
        }

        Write-Host ''
        if (Get-Command Write-MenuItem -ErrorAction SilentlyContinue) {
            Write-MenuItem '1' $ui.MenuOptimize Green 'Ok'
            Write-MenuItem '2' $ui.MenuRestore Yellow 'Reset'
            Write-MenuItem '3' $ui.MenuRefresh Cyan 'Test'
            Write-MenuItem '0' $ui.MenuBack Red 'Back'
        } else {
            Write-Host "  [1] $($ui.MenuOptimize)" -ForegroundColor Green
            Write-Host "  [2] $($ui.MenuRestore)" -ForegroundColor Yellow
            Write-Host "  [3] $($ui.MenuRefresh)" -ForegroundColor Cyan
            Write-Host "  [0] $($ui.MenuBack)" -ForegroundColor Red
        }

        Write-Host ''
        $reader = if ($InputReader) { $InputReader } else {
            if (Get-Command Read-UiInput -ErrorAction SilentlyContinue) { { Read-UiInput $ui.PromptChoice } } else { { Read-Host $ui.PromptChoice } }
        }
        $choice = [string](& $reader)

        switch ($choice) {
            '1' {
                try {
                    $res = Optimize-NetworkThrottle
                    if ($res.Success) {
                        if (Get-Command Write-Status -ErrorAction SilentlyContinue) {
                            Write-Status Ok ($ui.OptSuccess -f $res.BackupPath)
                        } else {
                            Write-Host ($ui.OptSuccess -f $res.BackupPath) -ForegroundColor Green
                        }
                    } else {
                        $errSummary = $res.Errors -join '; '
                        if (Get-Command Write-Status -ErrorAction SilentlyContinue) {
                            Write-Status Error ($ui.OptFailed -f $errSummary)
                        } else {
                            Write-Host ($ui.OptFailed -f $errSummary) -ForegroundColor Red
                        }
                    }
                } catch {
                    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
                }
                if (Get-Command Pause-Back -ErrorAction SilentlyContinue) { Pause-Back } else { Read-Host 'Press Enter to continue...' }
            }
            '2' {
                try {
                    $res = Restore-NetworkThrottle
                    if ($res.Success) {
                        if ($res.RestoredFromBackup) {
                            if (Get-Command Write-Status -ErrorAction SilentlyContinue) {
                                Write-Status Ok ($ui.RestoreSuccess -f $res.BackupPath)
                            } else {
                                Write-Host ($ui.RestoreSuccess -f $res.BackupPath) -ForegroundColor Green
                            }
                        } else {
                            if (Get-Command Write-Status -ErrorAction SilentlyContinue) {
                                Write-Status Ok $ui.RestoreDefault
                            } else {
                                Write-Host $ui.RestoreDefault -ForegroundColor Green
                            }
                        }
                    } else {
                        $errSummary = $res.Errors -join '; '
                        if (Get-Command Write-Status -ErrorAction SilentlyContinue) {
                            Write-Status Error ($ui.RestoreFailed -f $errSummary)
                        } else {
                            Write-Host ($ui.RestoreFailed -f $errSummary) -ForegroundColor Red
                        }
                    }
                } catch {
                    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
                }
                if (Get-Command Pause-Back -ErrorAction SilentlyContinue) { Pause-Back } else { Read-Host 'Press Enter to continue...' }
            }
            '3' {
                # Rescan loop
                continue
            }
            '0' {
                return
            }
            default {
                Write-Host 'Invalid choice.' -ForegroundColor Red
                Start-Sleep -Milliseconds 600
            }
        }
    }
}
