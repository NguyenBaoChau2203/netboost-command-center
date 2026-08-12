import React, { useState, useEffect, useRef } from 'react';
import { api } from '../api/client';
import type { DashboardResponse, LogEvent } from '../api/types';
import { useTranslation } from '../i18n/translations';

interface DnsViewProps {
  lang: 'vi' | 'en';
}

export const DnsView: React.FC<DnsViewProps> = ({ lang }) => {
  const [data, setData] = useState<DashboardResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [dnsActionLoading, setDnsActionLoading] = useState<'auto' | 'cloudflare' | 'google' | 'reset' | 'flush' | null>(null);
  const [progress, setProgress] = useState(0);
  const [logs, setLogs] = useState<LogEvent[]>([]);
  const logContainerRef = useRef<HTMLDivElement | null>(null);

  const t = useTranslation(lang);

  useEffect(() => {
    api.getDashboard().then(setData);

    const unsubscribe = api.subscribe(() => {
      api.getDashboard().then(setData);
    });

    return unsubscribe;
  }, []);

  useEffect(() => {
    if (logContainerRef.current) {
      logContainerRef.current.scrollTop = logContainerRef.current.scrollHeight;
    }
  }, [logs]);

  const addLocalLog = (message: string, level: LogEvent['level'] = 'INFO') => {
    setLogs(prev => [...prev, { timestamp: new Date().toISOString(), level, message }]);
  };

  const handleAutoDns = async () => {
    if (loading) return;
    setLoading(true);
    setDnsActionLoading('auto');
    setProgress(0);
    setLogs([]);

    addLocalLog("PS C:\\Users\\System\\NetBoost> ./Optimize-Dns.ps1 -AutoSelect", 'INFO');

    await api.setDnsAuto((prog, log) => {
      setProgress(prog);
      if (log) {
        setLogs(prev => [...prev, log]);
      }
      if (prog === 100) {
        setTimeout(() => {
          setLoading(false);
          setDnsActionLoading(null);
        }, 800);
      }
    });
  };

  const handleProvider = async (provider: 'Google' | 'Cloudflare') => {
    if (loading) return;
    setLoading(true);
    const actionKey = provider === 'Google' ? 'google' : 'cloudflare';
    setDnsActionLoading(actionKey);
    setProgress(0);
    setLogs([]);

    addLocalLog(`PS C:\\Users\\System\\NetBoost> ./Optimize-Dns.ps1 -Provider ${provider}`, 'INFO');

    await api.setDnsProvider(provider, (prog, log) => {
      setProgress(prog);
      if (log) {
        setLogs(prev => [...prev, log]);
      }
      if (prog === 100) {
        setTimeout(() => {
          setLoading(false);
          setDnsActionLoading(null);
        }, 800);
      }
    });
  };

  const handleReset = async () => {
    if (loading) return;
    setLoading(true);
    setDnsActionLoading('reset');
    setProgress(0);
    setLogs([]);

    addLocalLog("PS C:\\Users\\System\\NetBoost> ./Optimize-Dns.ps1 -ResetDHCP", 'INFO');

    await api.resetDns((prog, log) => {
      setProgress(prog);
      if (log) {
        setLogs(prev => [...prev, log]);
      }
      if (prog === 100) {
        setTimeout(() => {
          setLoading(false);
          setDnsActionLoading(null);
        }, 800);
      }
    });
  };

  const handleFlush = async () => {
    if (loading) return;
    setLoading(true);
    setDnsActionLoading('flush');
    setProgress(0);
    setLogs([]);

    addLocalLog("PS C:\\Users\\System\\NetBoost> ipconfig /flushdns", 'INFO');

    await api.flushDns((prog, log) => {
      setProgress(prog);
      if (log) {
        setLogs(prev => [...prev, log]);
      }
      if (prog === 100) {
        setTimeout(() => {
          setLoading(false);
          setDnsActionLoading(null);
        }, 800);
      }
    });
  };

  if (!data) return <div className="p-lg text-on-surface-variant font-medium">{t('dnsLoading')}</div>;

  const googleMs = Number.isFinite(data.latency.googleMs) && data.latency.googleMs >= 0 ? data.latency.googleMs : null;
  const cloudflareMs = Number.isFinite(data.latency.cloudflareMs) && data.latency.cloudflareMs >= 0 ? data.latency.cloudflareMs : null;
  const recommendedProvider = data.latency.recommended && data.latency.recommended !== 'Unknown'
    ? data.latency.recommended
    : null;

  const fastestText = lang === 'en' ? ' (Fastest)' : ' (Nhanh nhất)';
  const googleLatencyLabel = `${googleMs === null ? 'n/a' : `${googleMs} ms`}${recommendedProvider === 'Google' ? fastestText : ''}`;
  const cloudflareLatencyLabel = `${cloudflareMs === null ? 'n/a' : `${cloudflareMs} ms`}${recommendedProvider === 'Cloudflare' ? fastestText : ''}`;

  return (
    <div className="space-y-lg text-left">
      {/* Page Header */}
      <section>
        <h1 className="font-display-lg text-display-lg text-on-surface">{t('dnsTitle')}</h1>
        <p className="font-body-lg text-body-lg text-on-surface-variant mt-xs">
          {t('dnsSubtitle')}
        </p>
      </section>

      {/* Admin Privilege Alert */}
      <div className="bg-secondary-container/50 text-on-secondary-container p-md rounded-lg flex items-center gap-md border border-outline-variant">
        <span className="material-symbols-outlined text-primary text-[24px]">verified_user</span>
        <div className="text-body-md">
          {t('dnsAdminAlert')}
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-lg items-start">
        {/* Left Column: DNS Settings and latency graph */}
        <div className="lg:col-span-7 space-y-lg">

          {/* Card: Current DNS details */}
          <div className="bg-surface-container-lowest border border-outline-variant rounded-xl shadow-sm p-lg">
            <h3 className="font-title-lg text-title-lg font-bold text-on-surface mb-lg flex items-center gap-sm">
              <span className="material-symbols-outlined text-primary">lan</span>
              {t('dnsStatusTitle')}
            </h3>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-lg border-b border-outline-variant/30 pb-lg mb-lg">
              <div>
                <p className="font-label-sm text-label-sm text-on-surface-variant mb-xs">{t('dnsAdapterName')}</p>
                <p className="font-title-lg text-title-lg font-bold text-on-surface flex items-center gap-xs">
                  {data.adapter.name}
                  <span className="w-2.5 h-2.5 rounded-full bg-green-500 inline-block animate-pulse"></span>
                </p>
              </div>
              <div>
                <p className="font-label-sm text-label-sm text-on-surface-variant mb-xs">{t('dnsAdapterMode')}</p>
                <span className="px-sm py-1 bg-primary-container text-on-primary-container text-label-sm rounded-lg font-bold font-mono">
                  {data.dns.mode === 'DHCP' ? t('dashCardDnsModeAuto') : data.dns.mode}
                </span>
              </div>
              <div>
                <p className="font-label-sm text-label-sm text-on-surface-variant mb-xs">{t('dnsAdapterStatus')}</p>
                <p className="font-title-lg text-title-lg text-primary font-bold uppercase">ONLINE</p>
              </div>
            </div>

            <div className="space-y-sm">
              <p className="font-label-sm text-label-sm text-on-surface-variant font-semibold">{t('dnsAdapterDnsList')}</p>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-sm">
                {data.dns.servers.map((srv, idx) => (
                  <div key={idx} className="bg-surface-container p-sm rounded-lg font-mono text-body-md border border-outline-variant/30 text-on-surface">
                    <span className="text-on-surface-variant mr-sm font-semibold">{idx === 0 ? 'Primary:' : 'Secondary:'}</span>
                    {srv}
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Card: Manual and Auto controls */}
          <div className="bg-surface-container-lowest border border-outline-variant rounded-xl shadow-sm p-lg">
            <h3 className="font-title-lg text-title-lg font-bold text-on-surface mb-lg flex items-center gap-sm">
              <span className="material-symbols-outlined text-primary">auto_fix_high</span>
              {t('dnsOptTitle')}
            </h3>

            <div className="space-y-lg">
              <div className="p-md rounded-lg border border-primary/20 bg-primary/5 flex flex-col md:flex-row items-center justify-between gap-md">
                <div className="text-left space-y-sm">
                  <p className="font-label-md text-label-md text-primary font-bold flex items-center gap-sm">
                    <span className="material-symbols-outlined">network_ping</span>
                    {t('dnsOptAutoPingTitle')}
                  </p>
                  <p className="text-label-sm text-on-surface-variant leading-relaxed">
                    {t('dnsOptAutoPingDesc')}
                  </p>
                </div>
                <button
                  onClick={handleAutoDns}
                  disabled={loading}
                  className="px-xl py-md bg-primary text-on-primary rounded-lg font-label-md text-label-md font-bold hover:opacity-90 active:scale-95 transition-all shadow-md flex items-center gap-sm whitespace-nowrap cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {dnsActionLoading === 'auto' ? (
                    <span className="material-symbols-outlined animate-spin">sync</span>
                  ) : (
                    <span className="material-symbols-outlined">auto_fix_high</span>
                  )}
                  {dnsActionLoading === 'auto' ? t('dnsOptAutoPingBtnLoading') : t('dnsOptAutoPingBtn')}
                </button>
              </div>

              {/* Grid of other choices */}
              <div>
                <p className="font-label-sm text-label-sm text-on-surface-variant font-semibold mb-sm">{t('dnsOptManualTitle')}</p>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-sm">
                  <button
                    onClick={() => handleProvider('Cloudflare')}
                    disabled={loading}
                    className="p-md border border-outline-variant rounded-xl text-left hover:bg-surface-container-high transition-all active:scale-98 cursor-pointer flex justify-between items-center group disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    <div className="flex items-center gap-sm">
                      {dnsActionLoading === 'cloudflare' ? (
                        <span className="material-symbols-outlined animate-spin text-primary text-[20px]">sync</span>
                      ) : (
                        <span className="material-symbols-outlined text-primary-container group-hover:text-primary transition-colors text-[20px]">dns</span>
                      )}
                      <div>
                        <p className="font-label-md text-label-md text-on-surface font-bold">Cloudflare DNS</p>
                        <p className="text-[11px] text-on-surface-variant font-mono">1.1.1.1 / 1.0.0.1</p>
                      </div>
                    </div>
                    <span className="px-xs py-0.5 bg-tertiary-fixed text-on-tertiary-fixed text-[10px] font-bold rounded uppercase">{cloudflareLatencyLabel}</span>
                  </button>

                  <button
                    onClick={() => handleProvider('Google')}
                    disabled={loading}
                    className="p-md border border-outline-variant rounded-xl text-left hover:bg-surface-container-high transition-all active:scale-98 cursor-pointer flex justify-between items-center group disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    <div className="flex items-center gap-sm">
                      {dnsActionLoading === 'google' ? (
                        <span className="material-symbols-outlined animate-spin text-primary text-[20px]">sync</span>
                      ) : (
                        <span className="material-symbols-outlined text-primary-container group-hover:text-primary transition-colors text-[20px]">dns</span>
                      )}
                      <div>
                        <p className="font-label-md text-label-md text-on-surface font-bold">Google DNS</p>
                        <p className="text-[11px] text-on-surface-variant font-mono">8.8.8.8 / 8.8.4.4</p>
                      </div>
                    </div>
                    <span className="px-xs py-0.5 bg-secondary-container text-on-secondary-container text-[10px] font-bold rounded uppercase">{googleLatencyLabel}</span>
                  </button>
                </div>
              </div>

              {/* Auxiliary actions */}
              <div className="flex gap-md pt-sm border-t border-outline-variant/30">
                <button
                  onClick={handleReset}
                  disabled={loading}
                  className="flex-1 py-sm border border-outline text-on-surface rounded-lg font-label-md text-label-md hover:bg-surface-container-low transition-all active:scale-95 flex items-center justify-center gap-xs cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {dnsActionLoading === 'reset' ? (
                    <span className="material-symbols-outlined animate-spin">sync</span>
                  ) : (
                    <span className="material-symbols-outlined">restart_alt</span>
                  )}
                  {dnsActionLoading === 'reset' ? (lang === 'vi' ? 'Đang reset...' : 'Resetting...') : t('dnsOptActionReset')}
                </button>
                <button
                  onClick={handleFlush}
                  disabled={loading}
                  className="flex-1 py-sm border border-outline text-on-surface rounded-lg font-label-md text-label-md hover:bg-surface-container-low transition-all active:scale-95 flex items-center justify-center gap-xs cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {dnsActionLoading === 'flush' ? (
                    <span className="material-symbols-outlined animate-spin">sync</span>
                  ) : (
                    <span className="material-symbols-outlined">cleaning_services</span>
                  )}
                  {dnsActionLoading === 'flush' ? (lang === 'vi' ? 'Đang dọn...' : 'Flushing...') : t('dnsOptActionFlush')}
                </button>
              </div>

            </div>
          </div>
        </div>

        {/* Right Column: Live PowerShell Console */}
        <div className="lg:col-span-5 bg-inverse-surface rounded-xl border border-outline shadow-xl overflow-hidden flex flex-col h-[525px]">
          <div className="px-md py-sm bg-[#1a1c1d] border-b border-outline/30 flex items-center justify-between">
            <div className="flex items-center gap-sm">
              <span className="material-symbols-outlined text-primary-fixed-dim">terminal</span>
              <span className="font-code text-code text-on-primary-fixed font-bold">{t('dnsConsoleTitle')}</span>
            </div>
            <div className="flex gap-1">
              <div className="w-2.5 h-2.5 rounded-full bg-red-500/80"></div>
              <div className="w-2.5 h-2.5 rounded-full bg-amber-500/80"></div>
              <div className="w-2.5 h-2.5 rounded-full bg-green-500/80"></div>
            </div>
          </div>

          <div
            ref={logContainerRef}
            className="p-md font-code text-code text-primary-fixed-dim/90 overflow-y-auto flex-1 space-y-1 bg-black/35 text-left custom-scrollbar"
          >
            {logs.length === 0 ? (
              <p className="text-on-surface-variant/40 italic">{t('dnsConsolePlaceholder')}</p>
            ) : (
              logs.map((log, index) => {
                let color = 'text-primary-fixed-dim';
                if (log.level === 'SUMMARY') color = 'text-green-400 font-bold';
                if (log.level === 'ERROR') color = 'text-red-400';
                if (log.level === 'SKIP_LOCKED') color = 'text-amber-400';
                if (log.level === 'DELETE_OK') color = 'text-cyan-300';

                return (
                  <p key={index} className={color}>
                    {log.message}
                  </p>
                );
              })
            )}
            {loading && <p className="text-primary-fixed-dim animate-pulse">_</p>}
          </div>

          {loading && (
            <div className="p-sm bg-black/55 border-t border-outline/20">
              <div className="flex justify-between text-[11px] font-code text-primary-fixed-dim mb-xs">
                <span>{t('dnsProgressText')}</span>
                <span>{progress}%</span>
              </div>
              <div className="w-full bg-outline-variant/30 h-1.5 rounded-full overflow-hidden">
                <div className="bg-primary h-full transition-all duration-300" style={{ width: `${progress}%` }}></div>
              </div>
            </div>
          )}
        </div>

      </div>
    </div>
  );
};
