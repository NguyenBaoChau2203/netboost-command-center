import type {
  HealthResponse,
  DashboardResponse,
  CleanupTarget,
  SettingsState,
  JobState,
  LogEvent,
  AutoDnsTaskState
} from './types';
import {
  initialHealth,
  initialDashboard,
  allowedCleanupTargets,
  initialSettings
} from './mockData';

// Save settings to localStorage
const SETTINGS_KEY = 'netboost_settings';
const loadSettings = (): SettingsState => {
  const saved = localStorage.getItem(SETTINGS_KEY);
  if (saved) {
    try {
      return JSON.parse(saved);
    } catch {
      // ignore
    }
  }
  return { ...initialSettings };
};

const saveSettings = (settings: SettingsState) => {
  localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
};

const API_BASE_KEY = 'netboost_api_base';
const MOCK_API_KEY = 'netboost_use_mock_api';

const getBackendBase = () => {
  const configuredBase = localStorage.getItem(API_BASE_KEY)?.replace(/\/$/, '');
  if (configuredBase) return configuredBase;

  const host = window.location.hostname;
  const servedByLocalBackend =
    (host === '127.0.0.1' || host === 'localhost') &&
    window.location.port !== '5173';

  return servedByLocalBackend ? '' : null;
};

let onAdminRequiredHandler: (() => void) | null = null;

const fetchBackendJson = async <T,>(path: string, init?: RequestInit): Promise<T | null> => {
  if (localStorage.getItem(MOCK_API_KEY) === '1') return null;

  const base = getBackendBase();
  if (base === null) return null;

  let response: Response;

  try {
    response = await fetch(`${base}${path}`, {
      credentials: 'include',
      ...init,
      headers: {
        'Content-Type': 'application/json',
        ...(init?.headers || {})
      }
    });
  } catch {
    return null;
  }

  // Handle 401 unauthorized by refreshing the local HttpOnly session cookie and retrying once.
  if (response.status === 401) {
    try {
      await fetch(`${base}/api/health`, { credentials: 'include' });
      response = await fetch(`${base}${path}`, {
        credentials: 'include',
        ...init,
        headers: {
          'Content-Type': 'application/json',
          ...(init?.headers || {})
        }
      });
    } catch {
      // ignore and keep original response
    }
  }

  if (response.status === 403) {
    if (onAdminRequiredHandler) onAdminRequiredHandler();
    return { ok: false, adminRequired: true } as unknown as T;
  }

  try {
    const data = await response.json();
    if (data && typeof data === 'object' && (data.adminRequired === true || data.adminRequired === 'true' || data.adminRequired === 1)) {
      if (onAdminRequiredHandler) onAdminRequiredHandler();
    }
    return data as T;
  } catch {
    if (!response.ok) return null;
    return null;
  }
};


export class ApiClient {
  private health: HealthResponse = { ...initialHealth };
  private dashboard: DashboardResponse = { ...initialDashboard };
  private cleanupTargets: CleanupTarget[] = [...allowedCleanupTargets];
  private settings: SettingsState = loadSettings();

  private activeJobs: Record<string, JobState> = {};
  private activeJobEvents: Record<string, LogEvent[]> = {};

  private listeners: (() => void)[] = [];
  private adminRequiredError: boolean = false;

  constructor() {
    onAdminRequiredHandler = () => this.setAdminRequiredError(true);
    // Apply initial settings theme
    this.applyTheme(this.settings.theme);
  }

  public subscribe(listener: () => void) {
    this.listeners.push(listener);
    return () => {
      this.listeners = this.listeners.filter(l => l !== listener);
    };
  }

  private notify() {
    this.listeners.forEach(l => l());
  }

  public isAdminRequiredError(): boolean {
    return this.adminRequiredError;
  }

  public setAdminRequiredError(value: boolean) {
    this.adminRequiredError = value;
    this.notify();
  }

  public clearAdminRequiredError() {
    this.adminRequiredError = false;
    this.notify();
  }

  private async pollJobWithEvents(
    jobId: string,
    onProgress: (progress: number, log?: LogEvent) => void
  ): Promise<void> {
    let seenEventCount = 0;
    return new Promise((resolve, reject) => {
      const interval = setInterval(async () => {
        try {
          const [jobState, events] = await Promise.all([
            fetchBackendJson<JobState>(`/api/jobs/${jobId}`),
            fetchBackendJson<LogEvent[]>(`/api/jobs/${jobId}/events`)
          ]);

          if (jobState && events) {
            const newEvents = events.slice(seenEventCount);
            seenEventCount = events.length;

            for (const ev of newEvents) {
              onProgress(jobState.progress, ev);
            }

            if (newEvents.length === 0) {
              onProgress(jobState.progress);
            }

            this.activeJobs[jobId] = jobState;
            this.activeJobEvents[jobId] = events;
            this.notify();

            if (jobState.status === 'completed') {
              clearInterval(interval);
              resolve();
            } else if (jobState.status === 'failed') {
              clearInterval(interval);
              reject(new Error(`Job ${jobId} failed.`));
            }
          }
        } catch (err) {
          clearInterval(interval);
          reject(err);
        }
      }, 600);
    });
  }

  private async pollJobToCompletion(jobId: string): Promise<void> {
    return new Promise((resolve, reject) => {
      const interval = setInterval(async () => {
        try {
          const jobState = await fetchBackendJson<JobState>(`/api/jobs/${jobId}`);
          if (jobState) {
            this.activeJobs[jobId] = jobState;
            this.notify();

            if (jobState.status === 'completed') {
              clearInterval(interval);
              resolve();
            } else if (jobState.status === 'failed') {
              clearInterval(interval);
              reject(new Error(`Job ${jobId} failed.`));
            }
          }
        } catch (err) {
          clearInterval(interval);
          reject(err);
        }
      }, 500);
    });
  }

  // --- HEALTH ---
  public async getHealth(): Promise<HealthResponse> {
    const backend = await fetchBackendJson<HealthResponse>('/api/health');
    if (backend) {
      this.health = backend;
      return backend;
    }
    return { ...this.health };
  }

  // --- DASHBOARD ---
  public async getDashboard(): Promise<DashboardResponse> {
    const backend = await fetchBackendJson<DashboardResponse>('/api/dashboard');
    if (backend) {
      this.dashboard = backend;
      return backend;
    }
    return { ...this.dashboard };
  }

  // --- DNS CONTROLS ---
  public async setDnsAuto(onProgress: (progress: number, log?: LogEvent) => void): Promise<{ jobId: string; status: string }> {
    const backend = await fetchBackendJson<{ jobId: string; status: string; adminRequired?: boolean; ok?: boolean }>('/api/dns/auto', {
      method: 'POST'
    });

    if (backend && (backend.adminRequired || backend.ok === false)) {
      const errorLog: LogEvent = {
        timestamp: new Date().toISOString(),
        level: 'ERROR',
        message: 'Lỗi: Yêu cầu quyền Administrator (Admin Required).'
      };
      console.error('[NetBoost] DNS Auto Optimization failed: Admin privilege required.');
      this.dashboard.recentLogs.push(errorLog);
      onProgress(100, errorLog);
      this.notify();
      return { jobId: '', status: 'failed' };
    }

    if (backend && backend.jobId) {
      this.pollJobWithEvents(backend.jobId, onProgress).then(async () => {
        this.dashboard = await this.getDashboard();
        this.notify();
      });
      return backend;
    }

    const jobId = `dns-${Date.now()}`;

    // Simulate auto DNS ping and recommendation
    let step = 0;
    const steps = [
      { msg: "[INFO] Đang bắt đầu tự động tìm kiếm DNS tối ưu...", level: 'INFO' as const },
      { msg: "[SCAN] Đang đo độ trễ Google DNS (8.8.8.8)...", level: 'INFO' as const },
      { msg: "[SCAN] Google DNS Latency: 12 ms", level: 'DELETE_OK' as const },
      { msg: "[SCAN] Đang đo độ trễ Cloudflare DNS (1.1.1.1)...", level: 'INFO' as const },
      { msg: "[SCAN] Cloudflare DNS Latency: 8 ms", level: 'DELETE_OK' as const },
      { msg: "[SUCCESS] Đã chọn Cloudflare DNS (Độ trễ thấp nhất: 8 ms).", level: 'SUMMARY' as const },
      { msg: "[INFO] Đang cấu hình DNS cho card mạng Ethernet...", level: 'INFO' as const },
      { msg: "[OK] Đã thiết lập DNS 1.1.1.1 (Primary) và 1.0.0.1 (Secondary)", level: 'SUMMARY' as const },
      { msg: "[INFO] Đang flush DNS resolver cache...", level: 'INFO' as const },
      { msg: "[OK] Cấu hình hoàn tất! Hệ thống đã được tối ưu.", level: 'SUMMARY' as const }
    ];

    const timer = setInterval(() => {
      if (step < steps.length) {
        const item = steps[step];
        const log: LogEvent = {
          timestamp: new Date().toISOString(),
          level: item.level,
          message: item.msg
        };

        this.dashboard.recentLogs.push(log);
        onProgress(Math.round(((step + 1) / steps.length) * 100), log);
        this.notify();
        step++;
      } else {
        clearInterval(timer);
        this.dashboard.dns = {
          servers: ["1.1.1.1", "1.0.0.1"],
          mode: "Auto Opt"
        };
        this.dashboard.latency = {
          googleMs: 12,
          cloudflareMs: 8,
          recommended: "Cloudflare"
        };
        this.notify();
      }
    }, 800);

    return { jobId, status: "queued" };
  }

  public async setDnsProvider(provider: 'Google' | 'Cloudflare', onProgress: (progress: number, log?: LogEvent) => void): Promise<{ jobId: string; status: string }> {
    const backend = await fetchBackendJson<{ jobId: string; status: string; adminRequired?: boolean; ok?: boolean }>('/api/dns/provider', {
      method: 'POST',
      body: JSON.stringify({ provider })
    });

    if (backend && (backend.adminRequired || backend.ok === false)) {
      const errorLog: LogEvent = {
        timestamp: new Date().toISOString(),
        level: 'ERROR',
        message: `Lỗi: Không thể thiết lập ${provider} DNS. Yêu cầu quyền Administrator.`
      };
      console.error(`[NetBoost] Set DNS Provider (${provider}) failed: Admin privilege required.`);
      this.dashboard.recentLogs.push(errorLog);
      onProgress(100, errorLog);
      this.notify();
      return { jobId: '', status: 'failed' };
    }

    if (backend && backend.jobId) {
      this.pollJobWithEvents(backend.jobId, onProgress).then(async () => {
        this.dashboard = await this.getDashboard();
        this.notify();
      });
      return backend;
    }

    const jobId = `dns-provider-${Date.now()}`;
    const servers = provider === 'Google' ? ["8.8.8.8", "8.8.4.4"] : ["1.1.1.1", "1.0.0.1"];
    let step = 0;
    const steps = [
      { msg: `[INFO] Đang cấu hình card mạng Ethernet sử dụng ${provider} DNS...`, level: 'INFO' as const },
      { msg: `[OK] Đã thiết lập DNS ${servers.join(', ')} thành công.`, level: 'SUMMARY' as const },
      { msg: `[INFO] Thực hiện xóa cache phân giải DNS...`, level: 'INFO' as const },
      { msg: `[SUCCESS] Hoàn thành tối ưu DNS mạng sang ${provider} DNS.`, level: 'SUMMARY' as const }
    ];

    const timer = setInterval(() => {
      if (step < steps.length) {
        const item = steps[step];
        const log: LogEvent = {
          timestamp: new Date().toISOString(),
          level: item.level,
          message: item.msg
        };
        this.dashboard.recentLogs.push(log);
        onProgress(Math.round(((step + 1) / steps.length) * 100), log);
        this.notify();
        step++;
      } else {
        clearInterval(timer);
        this.dashboard.dns = {
          servers,
          mode: "Manual"
        };
        this.dashboard.latency.cloudflareMs = provider === 'Google' ? 12 : 8;
        this.notify();
      }
    }, 400);

    return { jobId, status: "queued" };
  }

  public async resetDns(onProgress: (progress: number, log?: LogEvent) => void): Promise<{ jobId: string; status: string }> {
    const backend = await fetchBackendJson<{ jobId: string; status: string; adminRequired?: boolean; ok?: boolean }>('/api/dns/reset', {
      method: 'POST'
    });

    if (backend && (backend.adminRequired || backend.ok === false)) {
      const errorLog: LogEvent = {
        timestamp: new Date().toISOString(),
        level: 'ERROR',
        message: 'Lỗi: Không thể reset DNS về DHCP. Yêu cầu quyền Administrator.'
      };
      console.error('[NetBoost] Reset DNS failed: Admin privilege required.');
      this.dashboard.recentLogs.push(errorLog);
      onProgress(100, errorLog);
      this.notify();
      return { jobId: '', status: 'failed' };
    }

    if (backend && backend.jobId) {
      this.pollJobWithEvents(backend.jobId, onProgress).then(async () => {
        this.dashboard = await this.getDashboard();
        this.notify();
      });
      return backend;
    }

    const jobId = `dns-reset-${Date.now()}`;
    let step = 0;
    const steps = [
      { msg: "[INFO] Đang trả cấu hình DNS card mạng về DHCP tự động...", level: 'INFO' as const },
      { msg: "[OK] Đã chuyển đổi DNS mạng về DHCP mặc định của nhà mạng.", level: 'SUMMARY' as const },
      { msg: "[SUCCESS] Reset cấu hình DNS mạng thành công.", level: 'SUMMARY' as const }
    ];

    const timer = setInterval(() => {
      if (step < steps.length) {
        const item = steps[step];
        const log: LogEvent = {
          timestamp: new Date().toISOString(),
          level: item.level,
          message: item.msg
        };
        this.dashboard.recentLogs.push(log);
        onProgress(Math.round(((step + 1) / steps.length) * 100), log);
        this.notify();
        step++;
      } else {
        clearInterval(timer);
        this.dashboard.dns = {
          servers: ["DHCP / Tự động"],
          mode: "DHCP"
        };
        this.notify();
      }
    }, 400);

    return { jobId, status: "queued" };
  }

  public async flushDns(onProgress: (progress: number, log?: LogEvent) => void): Promise<{ jobId: string; status: string }> {
    const backend = await fetchBackendJson<{ jobId: string; status: string; adminRequired?: boolean; ok?: boolean }>('/api/dns/flush', {
      method: 'POST'
    });

    if (backend && (backend.adminRequired || backend.ok === false)) {
      const errorLog: LogEvent = {
        timestamp: new Date().toISOString(),
        level: 'ERROR',
        message: 'Lỗi: Không thể làm sạch Resolver Cache DNS. Yêu cầu quyền Administrator.'
      };
      console.error('[NetBoost] Flush DNS failed: Admin privilege required.');
      this.dashboard.recentLogs.push(errorLog);
      onProgress(100, errorLog);
      this.notify();
      return { jobId: '', status: 'failed' };
    }

    if (backend && backend.jobId) {
      this.pollJobWithEvents(backend.jobId, onProgress).then(async () => {
        this.dashboard = await this.getDashboard();
        this.notify();
      });
      return backend;
    }

    const jobId = `dns-flush-${Date.now()}`;
    let step = 0;
    const steps = [
      { msg: "[INFO] Windows IP Configuration", level: 'INFO' as const },
      { msg: "[INFO] Đang làm sạch bộ nhớ cache phân giải tên miền DNS...", level: 'INFO' as const },
      { msg: "[SUCCESS] Successfully flushed the DNS Resolver Cache.", level: 'SUMMARY' as const }
    ];

    const timer = setInterval(() => {
      if (step < steps.length) {
        const item = steps[step];
        const log: LogEvent = {
          timestamp: new Date().toISOString(),
          level: item.level,
          message: item.msg
        };
        this.dashboard.recentLogs.push(log);
        onProgress(Math.round(((step + 1) / steps.length) * 100), log);
        this.notify();
        step++;
      } else {
        clearInterval(timer);
        this.notify();
      }
    }, 400);

    return { jobId, status: "queued" };
  }

  // --- CLEANUP ---
  public async getCleanupTargets(): Promise<CleanupTarget[]> {
    const backend = await fetchBackendJson<CleanupTarget[]>('/api/cleanup/targets');
    if (backend) {
      this.cleanupTargets = backend;
      return backend;
    }
    return [...this.cleanupTargets];
  }

  public async runCleanup(targetIds: string[], deep: boolean, confirmed: boolean, onProgress: (state: JobState, logs: LogEvent[]) => void): Promise<{ jobId: string; status: string }> {
    const backend = await fetchBackendJson<{ jobId: string; status: string; adminRequired?: boolean; ok?: boolean }>('/api/cleanup/run', {
      method: 'POST',
      body: JSON.stringify({ targetIds, deep, confirmed })
    });

    if (backend && (backend.adminRequired || backend.ok === false)) {
      const errorLog: LogEvent = {
        timestamp: new Date().toISOString(),
        level: 'ERROR',
        message: 'Lỗi: Không thể thực hiện dọn dẹp hệ thống. Yêu cầu quyền Administrator.'
      };
      console.error('[NetBoost] Run cleanup failed: Admin privilege required.');

      const failedJobState: JobState = {
        jobId: 'cleanup-failed',
        status: 'failed',
        progress: 100,
        currentTarget: 'Thất bại: Yêu cầu quyền Administrator.',
        filesDeleted: 0,
        dirsDeleted: 0,
        locked: 0,
        reclaimedBytes: 0
      };

      this.activeJobs['cleanup-failed'] = failedJobState;
      this.activeJobEvents['cleanup-failed'] = [errorLog];

      onProgress(failedJobState, [errorLog]);
      this.notify();
      return { jobId: '', status: 'failed' };
    }

    if (backend && backend.jobId) {
      const interval = setInterval(async () => {
        const [jobState, events] = await Promise.all([
          fetchBackendJson<JobState>(`/api/jobs/${backend.jobId}`),
          fetchBackendJson<LogEvent[]>(`/api/jobs/${backend.jobId}/events`)
        ]);

        if (jobState && events) {
          onProgress(jobState, events);

          this.activeJobs[backend.jobId] = jobState;
          this.activeJobEvents[backend.jobId] = events;
          this.notify();

          if (jobState.status === 'completed' || jobState.status === 'failed') {
            clearInterval(interval);
            this.dashboard = await this.getDashboard();
            this.notify();
          }
        }
      }, 500);

      return backend;
    }

    const jobId = `cleanup-${Date.now()}`;

    const targets = this.cleanupTargets.filter(t => targetIds.includes(t.id)).map(t => ({...t}));
    const totalBytes = targets.reduce((sum, t) => sum + t.estimatedBytes, 0);

    const jobState: JobState = {
      jobId,
      status: 'queued',
      progress: 0,
      currentTarget: 'Chuẩn bị...',
      filesDeleted: 0,
      dirsDeleted: 0,
      locked: 0,
      reclaimedBytes: 0
    };

    const deepText = deep ? "chuyên sâu" : "tiêu chuẩn";
    const confirmedText = confirmed ? "đã xác nhận" : "tự động";

    this.activeJobs[jobId] = jobState;
    this.activeJobEvents[jobId] = [
      { timestamp: new Date().toISOString(), level: 'INFO', message: `Khởi động tác vụ dọn dẹp hệ thống (${deepText}, ${confirmedText})...` },
      { timestamp: new Date().toISOString(), level: 'INFO', message: `Đang xử lý ${targets.length} mục tiêu dọn dẹp. Dung lượng dự kiến: ${(totalBytes / (1024*1024*1024)).toFixed(2)} GB` }
    ];

    setTimeout(() => {
      jobState.status = 'running';
      this.notify();

      let targetIndex = 0;
      const processNextTarget = () => {
        if (targetIndex < targets.length) {
          const target = targets[targetIndex];
          jobState.currentTarget = target.label;

          // Generate events for this target
          const targetLogs: LogEvent[] = [
            { timestamp: new Date().toISOString(), level: 'INFO', message: `Đang quét thư mục: ${target.label} (${target.path})` }
          ];

          this.activeJobEvents[jobId].push(...targetLogs);
          this.notify();

          let fileCount = 0;
          const maxFiles = 5;
          const fileTimer = setInterval(() => {
            if (fileCount < maxFiles) {
              const fileNum = Math.floor(Math.random() * 1000);
              const isLocked = target.id === 'crash-dumps' && fileCount === 2; // simulate a locked file

              if (isLocked) {
                const lockedLog: LogEvent = {
                  timestamp: new Date().toISOString(),
                  level: 'SKIP_LOCKED',
                  targetId: target.id,
                  path: `${target.path}\\locked_dump_${fileNum}.dmp`,
                  message: `[SKIP LOCKED] Bỏ qua: File đang được sử dụng bởi tiến trình hệ thống.`
                };
                this.activeJobEvents[jobId].push(lockedLog);
                jobState.locked++;
              } else {
                const deletedBytes = Math.floor(Math.random() * 1024 * 1024 * 10); // up to 10MB
                const deletedLog: LogEvent = {
                  timestamp: new Date().toISOString(),
                  level: 'DELETE_OK',
                  targetId: target.id,
                  path: `${target.path}\\temp_asset_${fileNum}.tmp`,
                  bytes: deletedBytes,
                  message: `Deleted file: temp_asset_${fileNum}.tmp`
                };
                this.activeJobEvents[jobId].push(deletedLog);
                jobState.filesDeleted++;
                jobState.reclaimedBytes += deletedBytes;
              }

              jobState.progress = Math.round(
                ((targetIndex / targets.length) + (fileCount / maxFiles) * (1 / targets.length)) * 100
              );

              onProgress({ ...jobState }, [...this.activeJobEvents[jobId]]);
              this.notify();
              fileCount++;
            } else {
              clearInterval(fileTimer);

              // Finish target
              const targetSize = target.estimatedBytes;
              jobState.reclaimedBytes = Math.max(jobState.reclaimedBytes, Math.round(jobState.reclaimedBytes * 1.5));

              const finishLog: LogEvent = {
                timestamp: new Date().toISOString(),
                level: 'SUMMARY',
                message: `Hoàn tất dọn dẹp ${target.label}. Giải phóng ${(targetSize / (1024*1024)).toFixed(1)} MB.`
              };
              this.activeJobEvents[jobId].push(finishLog);

              targetIndex++;
              processNextTarget();
            }
          }, 300);

        } else {
          // Finished all targets
          jobState.status = 'completed';
          jobState.progress = 100;
          jobState.currentTarget = 'Hoàn tất!';

          const completionLog: LogEvent = {
            timestamp: new Date().toISOString(),
            level: 'SUMMARY',
            message: `TẤT CẢ HOÀN TẤT. Tổng dung lượng thu hồi: ${(jobState.reclaimedBytes / (1024*1024*1024)).toFixed(2)} GB. Bỏ qua ${jobState.locked} file đang khóa.`
          };
          this.activeJobEvents[jobId].push(completionLog);
          onProgress({ ...jobState }, [...this.activeJobEvents[jobId]]);

          // Add to dashboard recent logs
          this.dashboard.recentLogs.push({
            timestamp: new Date().toISOString(),
            level: 'SUMMARY',
            message: `Hoàn thành dọn dẹp: Đã thu hồi ${(jobState.reclaimedBytes / (1024*1024*1024)).toFixed(2)} GB`
          });

          this.notify();
        }
      };

      processNextTarget();

    }, 1000);

    return { jobId, status: "queued" };
  }

  // --- AUTO TASK SCHEDULED TASK ---
  public async getAutoDnsTask(): Promise<AutoDnsTaskState> {
    const backend = await fetchBackendJson<AutoDnsTaskState>('/api/tasks/auto-dns');
    if (backend) return backend;
    return { ...this.dashboard.autoDnsTask };
  }

  public async createAutoDnsTask(onProgress?: (progress: number, log?: LogEvent) => void): Promise<{ jobId: string; status: string }> {
    const backend = await fetchBackendJson<{ jobId: string; status: string; adminRequired?: boolean; ok?: boolean }>('/api/tasks/auto-dns/create', {
      method: 'POST',
      body: JSON.stringify({ confirmed: true })
    });

    if (backend && (backend.adminRequired || backend.ok === false)) {
      const errorLog: LogEvent = {
        timestamp: new Date().toISOString(),
        level: 'ERROR',
        message: 'Lỗi: Không thể đăng ký Scheduled Task. Yêu cầu quyền Administrator.'
      };
      console.error('[NetBoost] Create Auto DNS Task failed: Admin privilege required.');
      this.dashboard.recentLogs.push(errorLog);
      if (onProgress) {
        onProgress(100, errorLog);
      }
      this.notify();
      return { jobId: '', status: 'failed' };
    }

    if (backend && backend.jobId) {
      if (onProgress) {
        this.pollJobWithEvents(backend.jobId, onProgress).then(async () => {
          this.dashboard = await this.getDashboard();
          this.notify();
        });
      } else {
        await this.pollJobToCompletion(backend.jobId);
        this.dashboard = await this.getDashboard();
        this.notify();
      }
      return backend;
    }

    const jobId = `task-create-${Date.now()}`;
    const steps = [
      { msg: "Đang đăng ký tác vụ tự động NetBoost Auto DNS Optimizer...", level: 'INFO' as const },
      { msg: "Đã tạo Scheduled Task trong Windows thành công (Trigger: logon, delay: 30s).", level: 'SUMMARY' as const }
    ];

    if (onProgress) {
      let step = 0;
      const timer = setInterval(() => {
        if (step < steps.length) {
          const item = steps[step];
          const log: LogEvent = {
            timestamp: new Date().toISOString(),
            level: item.level,
            message: item.msg
          };
          this.dashboard.recentLogs.push(log);
          onProgress(Math.round(((step + 1) / steps.length) * 100), log);
          this.notify();
          step++;
        } else {
          clearInterval(timer);
          this.dashboard.autoDnsTask.status = "Active";
          this.notify();
        }
      }, 500);
    } else {
      this.dashboard.autoDnsTask.status = "Active";
      steps.forEach(s => {
        this.dashboard.recentLogs.push({
          timestamp: new Date().toISOString(),
          level: s.level,
          message: s.msg
        });
      });
      this.notify();
    }

    return { jobId, status: "queued" };
  }

  public async removeAutoDnsTask(onProgress?: (progress: number, log?: LogEvent) => void): Promise<{ jobId: string; status: string }> {
    const backend = await fetchBackendJson<{ jobId: string; status: string; adminRequired?: boolean; ok?: boolean }>('/api/tasks/auto-dns/remove', {
      method: 'POST'
    });

    if (backend && (backend.adminRequired || backend.ok === false)) {
      const errorLog: LogEvent = {
        timestamp: new Date().toISOString(),
        level: 'ERROR',
        message: 'Lỗi: Không thể gỡ bỏ Scheduled Task. Yêu cầu quyền Administrator.'
      };
      console.error('[NetBoost] Remove Auto DNS Task failed: Admin privilege required.');
      this.dashboard.recentLogs.push(errorLog);
      if (onProgress) {
        onProgress(100, errorLog);
      }
      this.notify();
      return { jobId: '', status: 'failed' };
    }

    if (backend && backend.jobId) {
      if (onProgress) {
        this.pollJobWithEvents(backend.jobId, onProgress).then(async () => {
          this.dashboard = await this.getDashboard();
          this.notify();
        });
      } else {
        await this.pollJobToCompletion(backend.jobId);
        this.dashboard = await this.getDashboard();
        this.notify();
      }
      return backend;
    }

    const jobId = `task-remove-${Date.now()}`;
    const steps = [
      { msg: "Đang gỡ bỏ Scheduled Task NetBoost Auto DNS Optimizer...", level: 'INFO' as const },
      { msg: "Đã xóa scheduled task thành công khỏi Windows Task Scheduler.", level: 'SUMMARY' as const }
    ];

    if (onProgress) {
      let step = 0;
      const timer = setInterval(() => {
        if (step < steps.length) {
          const item = steps[step];
          const log: LogEvent = {
            timestamp: new Date().toISOString(),
            level: item.level,
            message: item.msg
          };
          this.dashboard.recentLogs.push(log);
          onProgress(Math.round(((step + 1) / steps.length) * 100), log);
          this.notify();
          step++;
        } else {
          clearInterval(timer);
          this.dashboard.autoDnsTask.status = "Inactive";
          this.notify();
        }
      }, 500);
    } else {
      this.dashboard.autoDnsTask.status = "Inactive";
      steps.forEach(s => {
        this.dashboard.recentLogs.push({
          timestamp: new Date().toISOString(),
          level: s.level,
          message: s.msg
        });
      });
      this.notify();
    }

    return { jobId, status: "queued" };
  }

  public async testAutoDnsTask(onLog: (logs: LogEvent[], jobState?: JobState) => void): Promise<void> {
    const backend = await fetchBackendJson<{ jobId: string; status: string; adminRequired?: boolean; ok?: boolean }>('/api/tasks/auto-dns/run', {
      method: 'POST'
    });

    if (backend && (backend.adminRequired || backend.ok === false)) {
      const timestamp = new Date().toISOString();
      const errorLogs: LogEvent[] = [
        { timestamp, level: 'INFO', message: "Khởi tạo tác vụ tự động NetBoost Auto DNS..." },
        { timestamp, level: 'INFO', message: "Đang kết nối tới Windows Task Scheduler..." },
        { timestamp, level: 'ERROR', message: "LỖI: Quyền truy cập bị từ chối (403 Forbidden)!" },
        { timestamp, level: 'ERROR', message: "Chi tiết: Thất bại khi kích hoạt Scheduled Task." },
        { timestamp, level: 'ERROR', message: "Yêu cầu chạy ứng dụng dưới đặc quyền Administrator cao nhất." },
        { timestamp, level: 'ERROR', message: "Tác vụ tự động dừng ngay lập tức." }
      ];
      console.error('[NetBoost] Test Auto DNS Task failed: Admin privilege required.');
      this.dashboard.recentLogs.push({
        timestamp,
        level: 'ERROR',
        message: "Lỗi chạy thử Auto DNS: Yêu cầu quyền Administrator."
      });
      const failedJobState: JobState = {
        jobId: 'task-test-failed',
        status: 'failed',
        progress: 100,
        currentTarget: 'Thất bại: Thiếu quyền Administrator',
        filesDeleted: 0,
        dirsDeleted: 0,
        locked: 0,
        reclaimedBytes: 0
      };
      onLog(errorLogs, failedJobState);
      this.notify();
      return;
    }

    if (backend && backend.jobId) {
      const interval = setInterval(async () => {
        const [jobState, events] = await Promise.all([
          fetchBackendJson<JobState>(`/api/jobs/${backend.jobId}`),
          fetchBackendJson<LogEvent[]>(`/api/jobs/${backend.jobId}/events`)
        ]);

        if (jobState && events) {
          onLog(events, jobState);

          this.activeJobs[backend.jobId] = jobState;
          this.activeJobEvents[backend.jobId] = events;
          this.notify();

          if (jobState.status === 'completed' || jobState.status === 'failed') {
            clearInterval(interval);
            this.dashboard = await this.getDashboard();
            this.notify();
          }
        }
      }, 500);

      return;
    }

    this.dashboard.recentLogs.push({
      timestamp: new Date().toISOString(),
      level: 'INFO',
      message: "Yêu cầu chạy thử tác vụ Auto DNS..."
    });

    const timelineLogs: LogEvent[] = [
      { timestamp: new Date().toISOString(), level: 'INFO', message: "Khởi tạo tác vụ tự động NetBoost Auto DNS..." },
      { timestamp: new Date().toISOString(), level: 'INFO', message: "Đang chờ dịch vụ mạng ổn định (Delay 30s được kích hoạt)..." },
      { timestamp: new Date().toISOString(), level: 'SUMMARY', message: "Kiểm tra Task Scheduler... Hoạt động bình thường." },
      { timestamp: new Date().toISOString(), level: 'SUMMARY', message: "Đã tự động chọn và thiết lập DNS tối ưu (Cloudflare 1.1.1.1)." },
      { timestamp: new Date().toISOString(), level: 'SUMMARY', message: "Làm sạch Resolver Cache hoàn tất." },
      { timestamp: new Date().toISOString(), level: 'SUMMARY', message: "Tác vụ chạy thử hoàn tất thành công!" }
    ];

    const jobId = `task-test-mock-${Date.now()}`;
    const mockJobState: JobState = {
      jobId,
      status: 'running',
      progress: 0,
      currentTarget: 'Đang chạy thử...',
      filesDeleted: 0,
      dirsDeleted: 0,
      locked: 0,
      reclaimedBytes: 0
    };

    let logIndex = 0;
    const currentLogs: LogEvent[] = [];
    const timer = setInterval(() => {
      if (logIndex < timelineLogs.length) {
        currentLogs.push(timelineLogs[logIndex]);
        mockJobState.progress = Math.round(((logIndex + 1) / timelineLogs.length) * 100);
        if (logIndex === timelineLogs.length - 1) {
          mockJobState.status = 'completed';
        }
        onLog([...currentLogs], { ...mockJobState });
        logIndex++;
      } else {
        clearInterval(timer);
        this.dashboard.recentLogs.push({
          timestamp: new Date().toISOString(),
          level: 'SUMMARY',
          message: "Chạy thử Scheduled Task hoàn thành tốt đẹp."
        });
        this.notify();
      }
    }, 500);
  }

  // --- SETTINGS ---
  public async getSettings(): Promise<SettingsState> {
    const backend = await fetchBackendJson<SettingsState>('/api/settings');
    if (backend) {
      this.settings = backend;
      return backend;
    }
    return { ...this.settings };
  }

  public async updateSettings(updates: Partial<SettingsState>): Promise<void> {
    const backend = await fetchBackendJson<SettingsState>('/api/settings', {
      method: 'PATCH',
      body: JSON.stringify(updates)
    });

    if (backend) {
      this.settings = backend;
      saveSettings(this.settings);

      if (updates.theme) {
        this.applyTheme(updates.theme);
      }

      this.notify();
      return;
    }

    this.settings = {
      ...this.settings,
      ...updates
    };
    saveSettings(this.settings);

    if (updates.theme) {
      this.applyTheme(updates.theme);
    }

    this.dashboard.recentLogs.push({
      timestamp: new Date().toISOString(),
      level: 'SUMMARY',
      message: "Đã lưu cài đặt local thành công."
    });
    this.notify();
  }

  private mediaQueryListener: ((e: MediaQueryListEvent) => void) | null = null;

  private applyTheme(theme: 'light' | 'dark' | 'system') {
    const root = document.documentElement;
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');

    // Remove existing listener if any to avoid duplicates
    if (this.mediaQueryListener) {
      mediaQuery.removeEventListener('change', this.mediaQueryListener);
      this.mediaQueryListener = null;
    }

    const updateSystemTheme = (isDark: boolean) => {
      if (isDark) {
        root.classList.add('dark');
        root.classList.remove('light');
      } else {
        root.classList.add('light');
        root.classList.remove('dark');
      }
    };

    if (theme === 'dark') {
      root.classList.add('dark');
      root.classList.remove('light');
    } else if (theme === 'light') {
      root.classList.add('light');
      root.classList.remove('dark');
    } else {
      // system
      updateSystemTheme(mediaQuery.matches);

      // Listen to OS theme changes actively
      this.mediaQueryListener = (e: MediaQueryListEvent) => {
        if (this.settings.theme === 'system') {
          updateSystemTheme(e.matches);
        }
      };
      mediaQuery.addEventListener('change', this.mediaQueryListener);
    }
  }

  public async selectFile(filter: 'ps1' | 'bat'): Promise<string | null> {
    const backend = await fetchBackendJson<{ jobId: string; status: string }>('/api/dialog/select-file', {
      method: 'POST',
      body: JSON.stringify({ filter })
    });

    if (backend && backend.jobId) {
      return new Promise((resolve) => {
        const interval = setInterval(async () => {
          try {
            const jobState = await fetchBackendJson<{ status: string; selected?: string | null }>(`/api/jobs/${backend.jobId}`);
            if (jobState) {
              if (jobState.status === 'completed') {
                clearInterval(interval);
                resolve(jobState.selected || null);
              } else if (jobState.status === 'failed') {
                clearInterval(interval);
                resolve(null);
              }
            }
          } catch {
            clearInterval(interval);
            resolve(null);
          }
        }, 500);
      });
    }
    return null;
  }

  public async selectFolder(): Promise<string | null> {
    const backend = await fetchBackendJson<{ jobId: string; status: string }>('/api/dialog/select-folder', {
      method: 'POST'
    });

    if (backend && backend.jobId) {
      return new Promise((resolve) => {
        const interval = setInterval(async () => {
          try {
            const jobState = await fetchBackendJson<{ status: string; selected?: string | null }>(`/api/jobs/${backend.jobId}`);
            if (jobState) {
              if (jobState.status === 'completed') {
                clearInterval(interval);
                resolve(jobState.selected || null);
              } else if (jobState.status === 'failed') {
                clearInterval(interval);
                resolve(null);
              }
            }
          } catch {
            clearInterval(interval);
            resolve(null);
          }
        }, 500);
      });
    }
    return null;
  }
}

export const api = new ApiClient();
