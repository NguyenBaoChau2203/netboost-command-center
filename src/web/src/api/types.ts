export interface HealthResponse {
  ok: boolean;
  appName: string;
  version: string;
  bindAddress: string;
  isAdmin: boolean;
  sessionTokenEnabled: boolean;
}

export interface AdapterState {
  name: string;
  status: string;
  interfaceIndex: number;
}

export interface DnsState {
  servers: string[];
  mode: string;
}

export interface AutoDnsTaskState {
  name: string;
  status: string;
  trigger?: string;
  delay?: string;
  lastRun?: string;
}

export interface LatencyState {
  googleMs: number;
  cloudflareMs: number;
  recommended: string;
}

export interface LogEvent {
  timestamp: string;
  level: 'INFO' | 'DELETE_OK' | 'DELETE_DIR' | 'SKIP_LOCKED' | 'WARN' | 'ERROR' | 'SUMMARY' | 'FOUND';
  targetId?: string;
  path?: string;
  bytes?: number;
  message: string;
}

export interface DashboardResponse {
  adapter: AdapterState;
  dns: DnsState;
  autoDnsTask: AutoDnsTaskState;
  latency: LatencyState;
  recentLogs: LogEvent[];
}

export interface CleanupTarget {
  id: string;
  label: string;
  path: string;
  risk: 'low' | 'medium' | 'high';
  action: 'filesystem' | 'recycle-bin' | 'delivery-optimization' | 'component-store' | 'windows-update-downloads';
  deepOnly: boolean;
  safeMinAgeMinutes: number;
  deepMinAgeMinutes: number;
  includePatterns: string[];
  excludePathSegments: string[];
  estimatedBytes: number;
  estimatedFileCount: number;
  estimateComplete: boolean;
  requiresConfirmation: boolean;
  description?: string;
}

export interface JobState {
  jobId: string;
  status: 'queued' | 'running' | 'completed' | 'failed';
  progress: number;
  currentTarget: string;
  filesDeleted: number;
  dirsDeleted: number;
  locked: number;
  reclaimedBytes: number;
}

export interface SettingsState {
  language: 'vi' | 'en';
  theme: 'light' | 'dark' | 'system';
  compactMode: boolean;
  bindAddress: string;
  sessionTokenEnabled: boolean;
  confirmRiskyActions: boolean;
  detailedCleanupLogs: boolean;
  autoScrollLogs: boolean;
  logRetentionDays: number; // 7, 30, -1 (forever)
  powershellScriptPath: string;
  launcherBatPath: string;
}
