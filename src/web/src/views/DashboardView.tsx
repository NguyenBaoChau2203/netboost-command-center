import React, { useState, useEffect } from 'react';
import { api } from '../api/client';
import type { DashboardResponse } from '../api/types';
import { useTranslation } from '../i18n/translations';

interface DashboardViewProps {
  lang: 'vi' | 'en';
  onNavigate: (tab: string) => void;
  setActiveLogSource: (source: 'cleanup' | 'dns' | 'task' | 'general') => void;
}

export const DashboardView: React.FC<DashboardViewProps> = ({ lang, onNavigate, setActiveLogSource }) => {
  // Suppress unused parameter warning safely
  if (typeof setActiveLogSource === 'function') { /* no-op */ }
  const [data, setData] = useState<DashboardResponse | null>(null);
  const [autoDnsLoading, setAutoDnsLoading] = useState(false);
  const [autoDnsProgress, setAutoDnsProgress] = useState(0);
  const [autoDnsLog, setAutoDnsLog] = useState<string>('');
  const [dnsActionLoading, setDnsActionLoading] = useState<'google' | 'cloudflare' | 'reset' | 'flush' | null>(null);

  const t = useTranslation(lang);

  useEffect(() => {
    // Set initial data
    api.getDashboard().then(setData);

    // Subscribe to changes in client simulator
    const unsubscribe = api.subscribe(() => {
      api.getDashboard().then(setData);
    });

    return unsubscribe;
  }, []);

  const handleAutoDns = async () => {
    if (autoDnsLoading) return;
    setAutoDnsLoading(true);
    setAutoDnsProgress(0);
    setAutoDnsLog(t('dashLatencyScanningStart'));

    await api.setDnsAuto((progress, log) => {
      setAutoDnsProgress(progress);
      if (log) {
        setAutoDnsLog(log.message);
      }
      if (progress === 100) {
        setTimeout(() => {
          setAutoDnsLoading(false);
        }, 1000);
      }
    });
  };

  const handleProvider = async (provider: 'Google' | 'Cloudflare') => {
    if (dnsActionLoading || autoDnsLoading) return;
    const actionKey = provider === 'Google' ? 'google' : 'cloudflare';
    setDnsActionLoading(actionKey);
    await api.setDnsProvider(provider, () => {});
    setDnsActionLoading(null);
  };

  const handleReset = async () => {
    if (dnsActionLoading || autoDnsLoading) return;
    setDnsActionLoading('reset');
    await api.resetDns(() => {});
    setDnsActionLoading(null);
  };

  const handleFlush = async () => {
    if (dnsActionLoading || autoDnsLoading) return;
    setDnsActionLoading('flush');
    await api.flushDns(() => {});
    setDnsActionLoading(null);
  };

  if (!data) return <div className="p-lg text-on-surface-variant font-medium">{t('dashLoading')}</div>;

  const googleMs = Number.isFinite(data.latency.googleMs) && data.latency.googleMs >= 0 ? data.latency.googleMs : null;
  const cloudflareMs = Number.isFinite(data.latency.cloudflareMs) && data.latency.cloudflareMs >= 0 ? data.latency.cloudflareMs : null;
  const recommendedProvider = data.latency.recommended && data.latency.recommended !== 'Unknown'
    ? data.latency.recommended
    : 'Unknown';
  const maxLatencyMs = Math.max(googleMs ?? 0, cloudflareMs ?? 0, 1);
  const googleWidth = `${Math.max(4, Math.round(((googleMs ?? 0) / maxLatencyMs) * 100))}%`;
  const cloudflareWidth = `${Math.max(4, Math.round(((cloudflareMs ?? 0) / maxLatencyMs) * 100))}%`;
  const googleLatencyText = googleMs === null ? 'n/a' : `${googleMs} ms`;
  const cloudflareLatencyText = cloudflareMs === null ? 'n/a' : `${cloudflareMs} ms`;
  const autoTaskStatus = data.autoDnsTask.status.toLowerCase();
  const autoTaskInstalled = autoTaskStatus !== 'inactive' && autoTaskStatus !== 'not installed';
  const autoTaskHealthy = autoTaskInstalled && autoTaskStatus !== 'disabled' && autoTaskStatus !== 'unknown';
  const autoTaskLabel = autoTaskInstalled ? t('dashCardTaskInstalled') : t('dashCardTaskNotInstalled');

  return (
    <div className="space-y-lg">
      {/* Page Header */}
      <section className="mb-xl">
        <h2 className="font-display-lg text-display-lg text-on-surface mb-xs">NetBoost Command Center</h2>
        <p className="font-body-lg text-body-lg text-on-surface-variant">{t('dashSubtitle')}</p>
      </section>

      {/* Status Cards Grid */}
      <section className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-md">
        {/* Card 1: Adapter */}
        <div className="bg-surface-container-lowest p-md rounded-xl border border-outline-variant shadow-sm hover:shadow-md transition-all cursor-pointer" onClick={() => onNavigate('dns')}>
          <div className="flex justify-between items-start mb-sm">
            <span className="text-on-surface-variant font-label-md text-label-md">{t('dashCardAdapter')}</span>
            <span className="material-symbols-outlined text-primary">lan</span>
          </div>
          <div className="flex items-baseline gap-xs">
            <p className="font-headline-sm text-headline-sm text-on-surface">{data.adapter.name}</p>
            <span className="text-[10px] font-bold text-primary uppercase">{data.adapter.status}</span>
          </div>
        </div>

        {/* Card 2: Current DNS */}
        <div className="bg-surface-container-lowest p-md rounded-xl border border-outline-variant shadow-sm hover:shadow-md transition-all cursor-pointer" onClick={() => onNavigate('dns')}>
          <div className="flex justify-between items-start mb-sm">
            <span className="text-on-surface-variant font-label-md text-label-md">{t('dashCardDns')}</span>
            <span className="material-symbols-outlined text-primary">public</span>
          </div>
          <p className="font-headline-sm text-headline-sm text-on-surface">{data.dns.servers[0]}</p>
          <p className="font-label-sm text-label-sm text-on-surface-variant truncate">
            {data.dns.servers[1] ? `${t('dashCardDnsSecondary')} ${data.dns.servers[1]}` : `${t('dashCardDnsMode')} ${data.dns.mode === 'DHCP' ? t('dashCardDnsModeAuto') : data.dns.mode}`}
          </p>
        </div>

        {/* Card 3: Auto DNS Scheduled Task */}
        <div className="bg-surface-container-lowest p-md rounded-xl border border-outline-variant shadow-sm hover:shadow-md transition-all cursor-pointer" onClick={() => onNavigate('task')}>
          <div className="flex justify-between items-start mb-sm">
            <span className="text-on-surface-variant font-label-md text-label-md">{t('dashCardTask')}</span>
            <span className="material-symbols-outlined text-primary">bolt</span>
          </div>
          <div className="flex items-center gap-sm">
            <p className="font-headline-sm text-headline-sm text-on-surface">
              {autoTaskLabel}
            </p>
            <div className={`w-2 h-2 rounded-full ${autoTaskHealthy ? 'bg-primary animate-pulse' : 'bg-outline'}`}></div>
          </div>
        </div>

        {/* Card 4: Latency */}
        <div className="bg-surface-container-lowest p-md rounded-xl border border-outline-variant shadow-sm hover:shadow-md transition-all cursor-pointer" onClick={() => onNavigate('dns')}>
          <div className="flex justify-between items-start mb-sm">
            <span className="text-on-surface-variant font-label-md text-label-md">{t('dashCardLatency')}</span>
            <span className="material-symbols-outlined text-primary">timer</span>
          </div>
          <p className="font-headline-sm text-headline-sm text-on-surface">{cloudflareLatencyText}</p>
          <p className="font-label-sm text-label-sm text-on-surface-variant">{t('dashCardLatencyOptimal', { provider: recommendedProvider })}</p>
        </div>
      </section>

      {/* Main Grid: DNS and Cleanup Side-by-Side */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-lg items-start">

        {/* Left Col: DNS Latency Panel */}
        <div className="lg:col-span-8 bg-surface-container-lowest rounded-xl border border-outline-variant shadow-sm flex flex-col overflow-hidden">
          <div className="p-md border-b border-outline-variant flex justify-between items-center bg-surface-container-low">
            <div className="flex items-center gap-sm">
              <span className="material-symbols-outlined text-primary">speed</span>
              <h3 className="font-title-lg text-title-lg font-bold">{t('dashLatencyTitle')}</h3>
            </div>
            <span className="px-sm py-xs bg-primary-container text-on-primary-container rounded-lg font-label-sm text-label-sm">
              {autoDnsLoading ? t('dashLatencyScanning', { progress: autoDnsProgress }) : t('dashLatencyComparing')}
            </span>
          </div>

          <div className="p-lg space-y-xl">
            {/* Simulation progress bar if loading */}
            {autoDnsLoading && (
              <div className="p-sm bg-primary/5 rounded-lg border border-primary/20 space-y-xs">
                <div className="flex justify-between font-label-sm text-label-sm text-primary">
                  <span>{autoDnsLog}</span>
                  <span>{autoDnsProgress}%</span>
                </div>
                <div className="w-full bg-outline-variant/30 h-2 rounded-full overflow-hidden">
                  <div className="bg-primary h-full transition-all duration-300" style={{ width: `${autoDnsProgress}%` }}></div>
                </div>
              </div>
            )}

            {/* Google DNS comparison */}
            <div className="space-y-sm">
              <div className="flex justify-between items-center">
                <span className="font-label-md text-label-md text-on-surface">Google DNS (8.8.8.8)</span>
                <span className="font-code text-code text-on-surface-variant font-medium">{googleLatencyText}</span>
              </div>
              <div className="w-full bg-surface-container-high h-3 rounded-full overflow-hidden">
                <div className="bg-secondary h-full rounded-full transition-all duration-700" style={{ width: googleWidth }}></div>
              </div>
            </div>

            {/* Cloudflare DNS comparison */}
            <div className="space-y-sm">
              <div className="flex justify-between items-center">
                <div className="flex items-center gap-sm">
                  <span className="font-label-md text-label-md text-on-surface">Cloudflare DNS (1.1.1.1)</span>
                  {recommendedProvider === 'Cloudflare' && (
                    <span className="px-xs py-0.5 bg-tertiary-fixed text-on-tertiary-fixed text-[9px] font-bold rounded uppercase">{t('dashLatencyOptimalBadge')}</span>
                  )}
                </div>
                <span className="font-code text-code text-primary font-bold">{cloudflareLatencyText}</span>
              </div>
              <div className="w-full bg-surface-container-high h-3 rounded-full overflow-hidden">
                <div className="bg-primary h-full rounded-full transition-all duration-700 shadow-[0_0_8px_rgba(0,180,216,0.5)]" style={{ width: cloudflareWidth }}></div>
              </div>
            </div>

            {/* Quick Actions Grid */}
            <div className="pt-lg grid grid-cols-2 md:grid-cols-3 gap-sm">
              <button
                onClick={handleAutoDns}
                disabled={autoDnsLoading || dnsActionLoading !== null}
                className="col-span-2 md:col-span-1 py-sm px-md bg-primary text-on-primary rounded-lg font-label-md text-label-md hover:opacity-90 active:scale-95 transition-all flex items-center justify-center gap-xs cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {autoDnsLoading ? (
                  <span className="material-symbols-outlined text-[18px] animate-spin">sync</span>
                ) : (
                  <span className="material-symbols-outlined text-[18px]">auto_fix_high</span>
                )}
                {autoDnsLoading ? t('dashLatencyScanning', { progress: autoDnsProgress }) : t('dashLatencyActionAuto')}
              </button>
              <button
                onClick={() => handleProvider('Google')}
                disabled={autoDnsLoading || dnsActionLoading !== null}
                className="py-sm px-md border border-outline-variant text-on-surface-variant rounded-lg font-label-md text-label-md hover:bg-surface-container-high transition-all active:scale-95 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-xs"
              >
                {dnsActionLoading === 'google' && (
                  <span className="material-symbols-outlined text-[18px] animate-spin">sync</span>
                )}
                {dnsActionLoading === 'google' ? (lang === 'vi' ? 'Đang chạy...' : 'Processing...') : t('dashLatencyActionGoogle')}
              </button>
              <button
                onClick={() => handleProvider('Cloudflare')}
                disabled={autoDnsLoading || dnsActionLoading !== null}
                className="py-sm px-md border border-outline-variant text-on-surface-variant rounded-lg font-label-md text-label-md hover:bg-surface-container-high transition-all active:scale-95 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-xs"
              >
                {dnsActionLoading === 'cloudflare' && (
                  <span className="material-symbols-outlined text-[18px] animate-spin">sync</span>
                )}
                {dnsActionLoading === 'cloudflare' ? (lang === 'vi' ? 'Đang chạy...' : 'Processing...') : t('dashLatencyActionCloudflare')}
              </button>
              <button
                onClick={handleReset}
                disabled={autoDnsLoading || dnsActionLoading !== null}
                className="py-sm px-md border border-outline-variant text-on-surface-variant rounded-lg font-label-md text-label-md hover:bg-surface-container-high transition-all active:scale-95 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-xs"
              >
                {dnsActionLoading === 'reset' && (
                  <span className="material-symbols-outlined text-[18px] animate-spin">sync</span>
                )}
                {dnsActionLoading === 'reset' ? (lang === 'vi' ? 'Đang reset...' : 'Resetting...') : t('dashLatencyActionReset')}
              </button>
              <button
                onClick={handleFlush}
                disabled={autoDnsLoading || dnsActionLoading !== null}
                className="py-sm px-md border border-outline-variant text-on-surface-variant rounded-lg font-label-md text-label-md hover:bg-surface-container-high transition-all active:scale-95 flex items-center justify-center gap-xs cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {dnsActionLoading === 'flush' ? (
                  <span className="material-symbols-outlined text-[18px] animate-spin">sync</span>
                ) : (
                  <span className="material-symbols-outlined text-[18px]">cleaning_services</span>
                )}
                {dnsActionLoading === 'flush' ? (lang === 'vi' ? 'Đang dọn...' : 'Flushing...') : t('dashLatencyActionFlush')}
              </button>
            </div>
          </div>
        </div>

        {/* Right Col: System Cleanup Summary */}
        <div className="lg:col-span-4 bg-surface-container-lowest rounded-xl border border-outline-variant shadow-sm flex flex-col">
          <div className="p-md border-b border-outline-variant flex items-center gap-sm bg-surface-container-low">
            <span className="material-symbols-outlined text-primary">delete_sweep</span>
            <h3 className="font-title-lg text-title-lg font-bold">{t('dashCleanupTitle')}</h3>
          </div>
          <div className="p-md space-y-md">
            <div className="space-y-sm">
              <div className="flex items-center gap-md p-xs border-b border-outline-variant/30">
                <span className="flex-1 font-body-md text-body-md font-semibold">{t('dashCleanupHeader')}</span>
                <span className="font-label-sm text-label-sm text-on-surface-variant">{t('dashCleanupSize')}</span>
              </div>
              <div className="flex items-center gap-md p-xs">
                <span className="flex-1 font-body-md text-body-md text-on-surface-variant">{t('dashCleanupTemp')}</span>
                <span className="font-code text-code text-on-surface-variant">1.2 GB</span>
              </div>
              <div className="flex items-center gap-md p-xs">
                <span className="flex-1 font-body-md text-body-md text-on-surface-variant">{t('dashCleanupShader')}</span>
                <span className="font-code text-code text-on-surface-variant">850 MB</span>
              </div>
              <div className="flex items-center gap-md p-xs">
                <span className="flex-1 font-body-md text-body-md text-on-surface-variant">{t('dashCleanupRecycle')}</span>
                <span className="font-code text-code text-on-surface-variant">12.8 GB</span>
              </div>
            </div>

            <div className="pt-sm border-t border-outline-variant/20">
              <button
                onClick={() => onNavigate('cleanup')}
                className="w-full py-sm px-md bg-primary text-on-primary rounded-lg font-label-md text-label-md hover:opacity-90 active:scale-[0.98] transition-all flex items-center justify-center gap-xs cursor-pointer font-semibold shadow-md"
              >
                <span className="material-symbols-outlined text-[18px]">cleaning_services</span>
                {t('dashCleanupAction')}
              </button>
            </div>
          </div>
        </div>

      </div>

      {/* Activity Log / Live PowerShell Terminal */}
      <section className="bg-inverse-surface rounded-xl border border-on-surface-variant/20 shadow-xl overflow-hidden flex flex-col">
        <div className="px-md py-sm bg-[#1a1c1d] border-b border-outline/30 flex items-center justify-between">
          <div className="flex items-center gap-sm">
            <span className="material-symbols-outlined text-primary-fixed-dim">terminal</span>
            <span className="font-code text-code text-on-primary-fixed font-bold">{t('dashLogsTitle')}</span>
          </div>
          <div className="flex gap-1.5">
            <div className="w-3 h-3 rounded-full bg-error/40"></div>
            <div className="w-3 h-3 rounded-full bg-tertiary/40"></div>
            <div className="w-3 h-3 rounded-full bg-primary/40"></div>
          </div>
        </div>
        <div className="p-md font-code text-code text-primary-fixed-dim/90 bg-black/40 h-48 custom-scrollbar overflow-y-auto leading-relaxed text-left flex flex-col space-y-1">
          {data.recentLogs.map((log, index) => {
            let color = 'text-primary-fixed-dim/80';
            if (log.level === 'SUMMARY') color = 'text-green-400 font-medium';
            if (log.level === 'ERROR') color = 'text-red-400';
            if (log.level === 'SKIP_LOCKED') color = 'text-amber-400';
            if (log.level === 'DELETE_OK') color = 'text-cyan-400';

            return (
              <p key={index} className={color}>
                [{log.timestamp.split('T')[1].substring(0, 8)}] {log.message}
              </p>
            );
          })}
          <p className="text-white/40 animate-pulse border-l-2 border-primary pl-1">_</p>
        </div>
      </section>
    </div>
  );
};
