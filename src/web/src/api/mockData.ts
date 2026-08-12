import type {
  HealthResponse,
  DashboardResponse,
  CleanupTarget,
  SettingsState
} from './types';

export const initialHealth: HealthResponse = {
  ok: true,
  appName: "NetBoost Command Center",
  version: "1.0.1",
  bindAddress: "127.0.0.1",
  isAdmin: true,
  sessionTokenEnabled: true
};

export const initialDashboard: DashboardResponse = {
  adapter: {
    name: "Ethernet",
    status: "Online",
    interfaceIndex: 12
  },
  dns: {
    servers: ["1.1.1.1", "1.0.0.1"],
    mode: "Manual"
  },
  autoDnsTask: {
    name: "NetBoost Auto DNS Optimizer",
    status: "Active",
    trigger: "At logon",
    delay: "30 seconds",
    lastRun: "2 giờ trước"
  },
  latency: {
    googleMs: 12,
    cloudflareMs: 8,
    recommended: "Cloudflare"
  },
  recentLogs: [
    { timestamp: new Date().toISOString(), level: 'INFO', message: "NetBoost Command Center UI v1.0.1 khởi động..." },
    { timestamp: new Date().toISOString(), level: 'SUMMARY', message: "Đã tải thông tin trạng thái local." }
  ]
};

const createCleanupTarget = (
  target: Partial<CleanupTarget> & Pick<CleanupTarget, 'id' | 'label' | 'path' | 'risk' | 'estimatedBytes' | 'requiresConfirmation'>
): CleanupTarget => ({
  action: 'filesystem',
  deepOnly: false,
  safeMinAgeMinutes: 0,
  deepMinAgeMinutes: 0,
  includePatterns: ['*'],
  excludePathSegments: [],
  estimatedFileCount: 0,
  estimateComplete: true,
  ...target
});

export const allowedCleanupTargets: CleanupTarget[] = [
  createCleanupTarget({
    id: "user-temp",
    label: "Temp người dùng",
    path: "%TEMP%",
    risk: "low",
    estimatedBytes: 1288490188, // ~1.2 GB
    estimatedFileCount: 1820,
    safeMinAgeMinutes: 1440,
    deepMinAgeMinutes: 60,
    requiresConfirmation: false,
    description: "Tập tin tạm tạo bởi các ứng dụng (.tmp, .log)"
  }),
  createCleanupTarget({
    id: "windows-temp",
    label: "Windows Temp",
    path: "C:\\Windows\\Temp",
    risk: "low",
    estimatedBytes: 471859200, // ~450 MB
    estimatedFileCount: 640,
    safeMinAgeMinutes: 1440,
    deepMinAgeMinutes: 60,
    requiresConfirmation: false,
    description: "Thư mục tạm của hệ thống Windows"
  }),
  createCleanupTarget({
    id: "directx-cache",
    label: "DirectX Shader Cache",
    path: "Shader cache đồ họa",
    risk: "medium",
    estimatedBytes: 2576980377, // ~2.4 GB
    estimatedFileCount: 380,
    requiresConfirmation: false,
    description: "Bộ nhớ đệm shader đồ họa giúp giảm giật hình khi chơi game"
  }),
  createCleanupTarget({
    id: "nvidia-cache",
    label: "NVIDIA DXCache / GLCache",
    path: "NVIDIA shader cache files",
    risk: "medium",
    estimatedBytes: 933228544, // ~890 MB
    estimatedFileCount: 210,
    requiresConfirmation: false,
    description: "Bộ nhớ đệm shader của driver đồ họa NVIDIA"
  }),
  createCleanupTarget({
    id: "steam-cache",
    label: "Steam shader cache",
    path: "Steam pre-compiled shaders",
    risk: "medium",
    estimatedBytes: 3435973836, // ~3.2 GB
    estimatedFileCount: 420,
    requiresConfirmation: false,
    description: "Bộ nhớ đệm đồ họa được tải trước cho game Steam"
  }),
  createCleanupTarget({
    id: "crash-dumps",
    label: "Crash dumps",
    path: "Báo cáo lỗi hệ thống Windows",
    risk: "high",
    estimatedBytes: 5476083302, // ~5.1 GB
    estimatedFileCount: 12,
    requiresConfirmation: true,
    description: "Các tập tin ghi lại bộ nhớ khi Windows hoặc ứng dụng bị lỗi"
  }),
  createCleanupTarget({
    id: "thumbnails",
    label: "Thumbnail cache",
    path: "Ảnh thu nhỏ của các tệp tin",
    risk: "low",
    estimatedBytes: 125829120, // ~120 MB
    estimatedFileCount: 18,
    requiresConfirmation: false,
    description: "Ảnh thu nhỏ xem trước của thư mục hình ảnh, video"
  }),
  createCleanupTarget({
    id: "inet-cache",
    label: "INetCache",
    path: "Windows Internet Cache",
    risk: "low",
    estimatedBytes: 220200960, // ~210 MB
    estimatedFileCount: 310,
    requiresConfirmation: false,
    description: "Bộ nhớ đệm tạm thời của Internet Explorer và Windows components"
  }),
  createCleanupTarget({
    id: "recycle-bin",
    label: "Recycle Bin",
    path: "Thùng rác hệ thống",
    risk: "high",
    estimatedBytes: 13743895347, // ~12.8 GB
    estimatedFileCount: 84,
    action: 'recycle-bin',
    requiresConfirmation: true,
    description: "Các tập tin đã xóa tạm thời đang chờ dọn sạch hoàn toàn"
  }),
  createCleanupTarget({
    id: 'component-store',
    label: 'Windows Component Store',
    path: 'DISM /StartComponentCleanup',
    risk: 'medium',
    action: 'component-store',
    deepOnly: true,
    estimatedBytes: 0,
    estimateComplete: false,
    requiresConfirmation: true,
    description: 'Dọn component cũ bằng DISM, không sử dụng ResetBase'
  }),
  createCleanupTarget({
    id: 'delivery-optimization',
    label: 'Delivery Optimization cache',
    path: 'Windows Delivery Optimization cache',
    risk: 'low',
    action: 'delivery-optimization',
    estimatedBytes: 0,
    estimateComplete: false,
    requiresConfirmation: false,
    description: 'Dùng cmdlet Windows được hỗ trợ và giữ lại pinned files'
  }),
  createCleanupTarget({
    id: 'windows-font-cache',
    label: 'Windows Font Cache',
    path: 'C:\\Windows\\ServiceProfiles\\LocalService\\AppData\\Local\\FontCache',
    risk: 'low',
    estimatedBytes: 83886080,
    estimatedFileCount: 24,
    requiresConfirmation: false,
    description: 'Bộ nhớ đệm font cục bộ của Windows'
  }),
  createCleanupTarget({
    id: 'windows-prefetch',
    label: 'Windows Prefetch (old .pf only)',
    path: 'C:\\Windows\\Prefetch\\*.pf',
    risk: 'medium',
    deepOnly: true,
    safeMinAgeMinutes: 43200,
    deepMinAgeMinutes: 43200,
    includePatterns: ['*.pf'],
    excludePathSegments: ['ReadyBoot'],
    estimatedBytes: 314572800,
    estimatedFileCount: 72,
    requiresConfirmation: true,
    description: 'Chỉ .pf cũ hơn 30 ngày; giữ ReadyBoot và Layout.ini'
  }),
  createCleanupTarget({
    id: 'windows-error-reports',
    label: 'Windows Error Reports',
    path: 'C:\\ProgramData\\Microsoft\\Windows\\WER',
    risk: 'low',
    safeMinAgeMinutes: 1440,
    deepMinAgeMinutes: 60,
    estimatedBytes: 209715200,
    estimatedFileCount: 48,
    requiresConfirmation: false,
    description: 'Báo cáo lỗi Windows cũ'
  })
];

export const initialSettings: SettingsState = {
  language: 'vi',
  theme: 'light',
  compactMode: false,
  bindAddress: "127.0.0.1 (Chỉ kết nối local)",
  sessionTokenEnabled: true,
  confirmRiskyActions: true,
  detailedCleanupLogs: true,
  autoScrollLogs: true,
  logRetentionDays: 7,
  powershellScriptPath: ".\\NetBoost_Command_Center.ps1",
  launcherBatPath: ".\\NetBoost_Command_Center.bat"
};

export const mockPowerShellLogs = {
  cleanup: [
    { type: 'info', text: 'PS C:\\Users\\System\\NetBoost> ./Cleanup-SystemTemp.ps1' },
    { type: 'info', text: '[SCANNING] Xác định vị trí các thư mục tạm thời của hệ thống...' },
    { type: 'success', text: '[FOUND] C:\\Windows\\Temp (3,115 files)' },
    { type: 'success', text: '[FOUND] %TEMP% (12,402 files)' },
    { type: 'error', text: '[LOCKED] Bỏ qua: "C:\\Windows\\Temp\\~DF39A1.tmp" - Tệp tin đang được sử dụng.' },
    { type: 'info', text: '[PURGE] Bắt đầu xóa an toàn các tệp tin...' },
    { type: 'success', text: '[SUCCESS] Giải phóng 1.65 GB từ các vị trí tạm thời hệ thống.' }
  ],
  dns: [
    { type: 'info', text: 'PS C:\\Users\\System\\NetBoost> ./Set-DnsProvider.ps1 -Provider Google' },
    { type: 'info', text: '[INFO] Đang cấu hình DNS cho card mạng Ethernet...' },
    { type: 'success', text: '[OK] Đã cấu hình Primary DNS thành 8.8.8.8' },
    { type: 'success', text: '[OK] Đã cấu hình Secondary DNS thành 8.8.4.4' },
    { type: 'info', text: '[INFO] Đang thực hiện làm sạch DNS resolver cache...' },
    { type: 'success', text: '[OK] Đã làm sạch DNS cache resolver thành công.' }
  ],
  task: [
    { type: 'info', text: '[2026-05-26 08:30:31] INFO: Initializing NetBoost Auto DNS Task...' },
    { type: 'info', text: '[2026-05-26 08:30:32] INFO: Waiting for network stack (Delay set to 30s)...' },
    { type: 'success', text: '[2026-05-26 08:31:02] DEBUG: Checking Windows Task Scheduler status... OK.' },
    { type: 'success', text: '[2026-05-26 08:31:03] DEBUG: Configuring DNS (1.1.1.1 / 8.8.8.8)' },
    { type: 'success', text: '[2026-05-26 08:31:04] SUCCESS: Flush DNS resolver cache completed.' },
    { type: 'success', text: '[2026-05-26 08:31:04] SUCCESS: Auto DNS Task execution finished.' }
  ]
};
