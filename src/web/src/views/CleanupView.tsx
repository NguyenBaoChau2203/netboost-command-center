import React, { useState, useEffect, useRef } from 'react';
import { api } from '../api/client';
import type { CleanupTarget, JobState, LogEvent } from '../api/types';
import { useTranslation } from '../i18n/translations';

interface CleanupViewProps {
  lang: 'vi' | 'en';
}

export const CleanupView: React.FC<CleanupViewProps> = ({ lang }) => {
  const [targets, setTargets] = useState<CleanupTarget[]>([]);
  const [selectedIds, setSelectedIds] = useState<string[]>([]);
  const [runningJob, setRunningJob] = useState<JobState | null>(null);
  const [runningLogs, setRunningLogs] = useState<LogEvent[]>([]);
  const [completedJob, setCompletedJob] = useState<JobState | null>(null);
  const [failedJob, setFailedJob] = useState<JobState | null>(null);
  const [lockedFiles, setLockedFiles] = useState<string[]>([]);

  // State machine states
  const [cleanupState, setCleanupState] = useState<'idle' | 'confirming' | 'running' | 'completed' | 'failed'>('idle');
  const [isDeepClean, setIsDeepClean] = useState(false);
  const [riskReason, setRiskReason] = useState<string>('');

  const logConsoleRef = useRef<HTMLDivElement | null>(null);
  const t = useTranslation(lang);

  useEffect(() => {
    api.getCleanupTargets().then(data => {
      setTargets(data);
      // Deep-only and confirmation-required targets stay opt-in.
      setSelectedIds(data.filter(t => !t.requiresConfirmation && !t.deepOnly).map(t => t.id));
    });
  }, []);

  useEffect(() => {
    if (logConsoleRef.current) {
      logConsoleRef.current.scrollTop = logConsoleRef.current.scrollHeight;
    }
  }, [runningLogs]);

  const toggleSelectAll = (checked: boolean) => {
    if (checked) {
      setSelectedIds(targets.map(t => t.id));
    } else {
      setSelectedIds([]);
    }
  };

  const toggleSelectTarget = (id: string) => {
    setSelectedIds(prev =>
      prev.includes(id) ? prev.filter(x => x !== id) : [...prev, id]
    );
  };

  const getExpectedImpactBytes = () => {
    const selected = targets.filter(t => selectedIds.includes(t.id));
    return selected.reduce((sum, t) => sum + t.estimatedBytes, 0);
  };

  const hasSelectedDeepOnlyTarget = targets.some(target =>
    selectedIds.includes(target.id) && target.deepOnly
  );

  const hasIncompleteEstimate = targets.some(target =>
    selectedIds.includes(target.id) && !target.estimateComplete
  );

  const handleStartCleanup = (deepMode: boolean) => {
    setIsDeepClean(deepMode);

    // Check if any selected targets require confirmation
    const selectedTargets = targets.filter(t => selectedIds.includes(t.id));
    if (!deepMode && selectedTargets.some(target => target.deepOnly)) {
      return;
    }
    const needsConfirm = selectedTargets.some(t => t.requiresConfirmation) || deepMode;

    if (needsConfirm) {
      let reason = t('cleanConfirmDeepReason');
      if (selectedIds.includes('recycle-bin')) {
        reason += t('cleanConfirmRecycleBinReason');
      }
      if (selectedIds.includes('crash-dumps')) {
        reason += t('cleanConfirmCrashDumpsReason');
      }
      if (selectedIds.includes('windows-prefetch')) {
        reason += t('cleanConfirmPrefetchReason');
      }
      if (selectedIds.includes('component-store')) {
        reason += t('cleanConfirmComponentStoreReason');
      }
      if (deepMode) {
        reason += t('cleanConfirmDeepCleanReason');
      }
      setRiskReason(reason);
      setCleanupState('confirming');
    } else {
      executeCleanup(deepMode);
    }
  };

  const executeCleanup = async (deepMode: boolean) => {
    setCleanupState('running');
    setCompletedJob(null);
    setFailedJob(null);
    setLockedFiles([]);
    setRunningLogs([]);

    await api.runCleanup(selectedIds, deepMode, true, (jobState, logs) => {
      setRunningJob(jobState);
      setRunningLogs(logs);

      // Collect simulated locked file paths
      const skippedEvents = logs.filter(log => log.level === 'SKIP_LOCKED');
      setLockedFiles(skippedEvents.map(e => e.path || 'Access Denied file'));

      if (jobState.status === 'completed') {
        setTimeout(() => {
          setCompletedJob(jobState);
          setCleanupState('completed');
          setRunningJob(null);

          // Re-fetch targets to update their sizes
          api.getCleanupTargets().then(setTargets);
        }, 1200);
      } else if (jobState.status === 'failed') {
        setTimeout(() => {
          setFailedJob(jobState);
          setCleanupState('failed');
          setRunningJob(null);
        }, 1200);
      }
    });
  };

  const formatBytes = (bytes: number) => {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  };

  return (
    <div className="space-y-lg text-left relative">
      {/* Page Header */}
      <section className="flex justify-between items-end mb-lg">
        <div>
          <h1 className="font-display-lg text-display-lg text-on-surface">{t('cleanTitle')}</h1>
          <p className="font-body-md text-body-md text-on-surface-variant mt-1">
            {t('cleanSubtitle')}
          </p>
        </div>
        {cleanupState === 'idle' && (
          <button
            onClick={() => handleStartCleanup(false)}
            disabled={selectedIds.length === 0 || hasSelectedDeepOnlyTarget}
            className="bg-primary text-on-primary px-xl py-md rounded-lg font-label-md font-bold flex items-center gap-sm shadow-lg hover:shadow-primary/20 active:scale-95 transition-all cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <span className="material-symbols-outlined">bolt</span>
            {t('cleanBtnStart')}
          </button>
        )}
      </section>

      {/* PROGRESS PANEL FOR RUNNING CLEANUP */}
      {cleanupState === 'running' && (
        <div className="p-lg bg-primary-container/10 border border-primary/20 rounded-xl space-y-md shadow-md">
          <div className="flex justify-between items-center">
            {runningJob ? (
              <>
                <div>
                  <p className="font-label-sm text-label-sm text-primary uppercase font-bold tracking-wider">{t('cleanProgressTitle')}</p>
                  <h4 className="font-headline-sm text-headline-sm text-on-surface flex items-center gap-sm">
                    <span className="material-symbols-outlined animate-spin">sync</span>
                    {t('cleanProgressCurrent', { target: runningJob.currentTarget })}
                  </h4>
                </div>
                <div className="text-right">
                  <p className="font-code text-code font-bold text-primary">{runningJob.progress}%</p>
                  <p className="text-label-sm text-on-surface-variant">{t('cleanProgressReclaimed', { size: formatBytes(runningJob.reclaimedBytes) })}</p>
                </div>
              </>
            ) : (
              <div>
                <p className="font-label-sm text-label-sm text-primary uppercase font-bold tracking-wider">{t('cleanProgressTitle')}</p>
                <h4 className="font-headline-sm text-headline-sm text-on-surface flex items-center gap-sm">
                  <span className="material-symbols-outlined animate-spin">sync</span>
                  {lang === 'vi' ? 'Đang chuẩn bị dọn dẹp...' : 'Preparing cleanup...'}
                </h4>
              </div>
            )}
          </div>
          <div className="w-full bg-outline-variant/30 h-3 rounded-full overflow-hidden">
            <div className="bg-primary h-full transition-all duration-300" style={{ width: `${runningJob ? runningJob.progress : 0}%` }}></div>
          </div>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-md pt-sm border-t border-outline-variant/20 text-center">
            <div className="p-xs bg-surface-container rounded-lg">
              <p className="text-[11px] text-on-surface-variant">{t('cleanStatDeletedFiles')}</p>
              <p className="font-mono font-bold text-body-lg text-on-surface">{runningJob ? runningJob.filesDeleted : 0}</p>
            </div>
            <div className="p-xs bg-surface-container rounded-lg">
              <p className="text-[11px] text-on-surface-variant">{t('cleanStatDeletedDirs')}</p>
              <p className="font-mono font-bold text-body-lg text-on-surface">{runningJob ? (runningJob.dirsDeleted ?? 0) : 0}</p>
            </div>
            <div className="p-xs bg-surface-container rounded-lg">
              <p className="text-[11px] text-on-surface-variant">{t('cleanStatLocked')}</p>
              <p className="font-mono font-bold text-body-lg text-amber-600">{runningJob ? runningJob.locked : 0}</p>
            </div>
            <div className="p-xs bg-surface-container rounded-lg">
              <p className="text-[11px] text-on-surface-variant">{t('cleanStatTotalSize')}</p>
              <p className="font-mono font-bold text-body-lg text-green-600">{formatBytes(runningJob ? runningJob.reclaimedBytes : 0)}</p>
            </div>
          </div>
        </div>
      )}

      {/* COMPLETED PANEL FOR SUCCESSFUL CLEANUP */}
      {cleanupState === 'completed' && completedJob && (
        <div className="p-lg bg-green-500/5 border border-green-500/20 rounded-xl space-y-lg shadow-md">
          <div className="flex items-center gap-md">
            <span className="material-symbols-outlined text-green-600 text-[42px]" style={{ fontVariationSettings: "'FILL' 1" }}>check_circle</span>
            <div>
              <h3 className="font-headline-sm text-headline-sm text-on-surface font-bold">{t('cleanSuccessTitle')}</h3>
              <p className="text-body-md text-on-surface-variant">
                {t('cleanSuccessBody', { size: formatBytes(completedJob.reclaimedBytes) })}
              </p>
            </div>
          </div>

          {lockedFiles.length > 0 && (
            <div className="space-y-sm bg-amber-500/5 p-md rounded-lg border border-amber-500/20">
              <p className="font-label-sm text-label-sm text-amber-500 dark:text-amber-400 font-bold flex items-center gap-xs">
                <span className="material-symbols-outlined text-[18px]">security</span>
                {t('cleanSuccessLocked', { count: lockedFiles.length })}
              </p>
              <div className="max-h-24 overflow-y-auto font-mono text-[11px] text-on-surface-variant/80 divide-y divide-outline-variant/30 custom-scrollbar">
                {lockedFiles.map((f, i) => (
                  <div key={i} className="py-1 truncate" title={f}>{f}</div>
                ))}
              </div>
            </div>
          )}

          <div className="flex justify-end gap-sm">
            <button
              onClick={() => {
                setCompletedJob(null);
                setCleanupState('idle');
              }}
              className="px-xl py-sm bg-primary text-on-primary rounded-lg font-label-md text-label-md font-bold cursor-pointer hover:opacity-90 active:scale-95"
            >
              {t('cleanBtnBack')}
            </button>
          </div>
        </div>
      )}

      {/* FAILED PANEL FOR ERRORED CLEANUP */}
      {cleanupState === 'failed' && failedJob && (
        <div className="p-lg bg-error-container/10 border border-error/20 rounded-xl space-y-lg shadow-md">
          <div className="flex items-center gap-md">
            <span className="material-symbols-outlined text-error text-[42px]" style={{ fontVariationSettings: "'FILL' 1" }}>error</span>
            <div>
              <h3 className="font-headline-sm text-headline-sm text-on-surface font-bold text-error">{t('cleanFailedTitle')}</h3>
              <p className="text-body-md text-on-surface-variant">
                {t('cleanFailedBody')}
              </p>
            </div>
          </div>

          <div className="flex justify-end gap-sm">
            <button
              onClick={() => {
                setFailedJob(null);
                setCleanupState('idle');
              }}
              className="px-xl py-sm bg-primary text-on-primary rounded-lg font-label-md text-label-md font-bold cursor-pointer hover:opacity-90 active:scale-95"
            >
              {t('cleanBtnBack')}
            </button>
          </div>
        </div>
      )}

      {/* MAIN TARGETS SELECTION PANEL */}
      {cleanupState === 'idle' && (
        <div className="grid grid-cols-12 gap-lg mb-xl animate-in fade-in duration-200">

          {/* Left: Targets Checklist */}
          <div className="col-span-12 lg:col-span-8 space-y-md">
            <div className="bg-surface-container-lowest rounded-xl border border-outline-variant shadow-sm overflow-hidden">
              <div className="px-md py-sm bg-surface-container-low border-b border-outline-variant flex items-center justify-between">
                <div className="flex items-center gap-sm">
                  <input
                    type="checkbox"
                    checked={selectedIds.length === targets.length}
                    onChange={(e) => toggleSelectAll(e.target.checked)}
                    className="w-4 h-4 rounded border-outline text-primary focus:ring-primary/20 cursor-pointer"
                  />
                  <span className="font-label-md text-label-md uppercase tracking-tight text-on-surface-variant font-bold">
                    {t('cleanHeaderAll')}
                  </span>
                </div>
                <span className="text-label-sm font-label-sm text-on-surface-variant font-semibold">
                  {t('cleanHeaderSelectedCount', { selected: selectedIds.length, total: targets.length })}
                </span>
              </div>
              <div className="divide-y divide-outline-variant/40">
                {targets.map(target => {
                  const isChecked = selectedIds.includes(target.id);
                  let riskColor = 'bg-green-100 text-green-700 dark:bg-green-500/10 dark:text-green-400';
                  let riskText = t('cleanRiskLow');
                  if (target.risk === 'medium') {
                    riskColor = 'bg-amber-100 text-amber-700 dark:bg-amber-500/10 dark:text-amber-400';
                    riskText = t('cleanRiskMedium');
                  } else if (target.risk === 'high') {
                    riskColor = 'bg-red-100 text-red-700 dark:bg-red-500/10 dark:text-red-400';
                    riskText = t('cleanRiskHigh');
                  }

                  let targetIcon = 'folder';
                  if (target.id.includes('cache')) targetIcon = 'memory';
                  if (target.id === 'recycle-bin') targetIcon = 'delete';
                  if (target.id === 'crash-dumps') targetIcon = 'bug_report';
                  if (target.id === 'thumbnails') targetIcon = 'image';

                  return (
                    <div
                      key={target.id}
                      onClick={() => toggleSelectTarget(target.id)}
                      className={`px-md py-md flex items-center gap-md hover:bg-surface-container-low transition-colors group cursor-pointer ${isChecked ? 'bg-primary/5' : ''}`}
                    >
                      <div className="flex-shrink-0">
                        <input
                          type="checkbox"
                          checked={isChecked}
                          onChange={() => {}} // Handled by div onClick
                          className="w-4 h-4 rounded border-outline text-primary focus:ring-primary/20 cursor-pointer"
                        />
                      </div>
                      <div className={`w-10 h-10 rounded-lg flex items-center justify-center ${isChecked ? 'bg-primary/10 text-primary' : 'bg-surface-container text-on-surface-variant'}`}>
                        <span className="material-symbols-outlined">{targetIcon}</span>
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-sm">
                          <h4 className="font-label-md text-on-surface font-semibold truncate">{target.label}</h4>
                          <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold uppercase ${riskColor}`}>
                            {riskText}
                          </span>
                          {target.deepOnly && (
                            <span className="px-2 py-0.5 rounded-full text-[10px] font-bold uppercase bg-purple-100 text-purple-700 dark:bg-purple-500/10 dark:text-purple-300">
                              {t('cleanDeepOnly')}
                            </span>
                          )}
                        </div>
                        <p className="text-label-sm text-on-surface-variant truncate font-mono text-[11px] opacity-80">{target.path}</p>
                      </div>
                      <div className="text-right flex-shrink-0">
                        <p className="font-label-md text-on-surface font-mono font-semibold">
                          {!target.estimateComplete && target.estimatedBytes === 0
                            ? t('cleanEstimateSystem')
                            : `${target.estimateComplete ? '' : '≥ '}${formatBytes(target.estimatedBytes)}`}
                        </p>
                        <p className="text-[10px] text-green-600 font-bold">
                          {target.estimatedFileCount > 0
                            ? t('cleanEstimateFiles', { count: target.estimatedFileCount })
                            : t('cleanStatusReady')}
                        </p>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          </div>

          {/* Right: Explanatory warning and action boxes */}
          <div className="col-span-12 lg:col-span-4 space-y-lg">

            {/* Box 1: Impact description */}
            <div className="bg-surface-container-lowest rounded-xl border border-outline-variant shadow-sm p-lg">
              <h4 className="font-title-lg text-on-surface mb-md font-bold flex items-center gap-sm">
                <span className="material-symbols-outlined text-tertiary">warning</span>
                {t('cleanInfoTitle')}
              </h4>
              <ul className="space-y-md">
                <li className="flex gap-sm">
                  <span className="material-symbols-outlined text-primary text-[18px] mt-0.5">speed</span>
                  <div className="text-body-sm text-on-surface-variant">
                    <span className="font-bold text-on-surface">{t('cleanInfoSpeedTitle')} </span>
                    {t('cleanInfoSpeedDesc')}
                  </div>
                </li>
                <li className="flex gap-sm">
                  <span className="material-symbols-outlined text-primary text-[18px] mt-0.5">stadium</span>
                  <div className="text-body-sm text-on-surface-variant">
                    <span className="font-bold text-on-surface">{t('cleanInfoShaderTitle')} </span>
                    {t('cleanInfoShaderDesc')}
                  </div>
                </li>
                <li className="flex gap-sm">
                  <span className="material-symbols-outlined text-primary text-[18px] mt-0.5">grid_view</span>
                  <div className="text-body-sm text-on-surface-variant">
                    <span className="font-bold text-on-surface">{t('cleanInfoThumbTitle')} </span>
                    {t('cleanInfoThumbDesc')}
                  </div>
                </li>
                <li className="flex gap-sm">
                  <span className="material-symbols-outlined text-primary text-[18px] mt-0.5">security</span>
                  <div className="text-body-sm text-on-surface-variant">
                    <span className="font-bold text-on-surface">{t('cleanInfoSafetyTitle')} </span>
                    {t('cleanInfoSafetyDesc')}
                  </div>
                </li>
              </ul>
            </div>

            {/* Box 2: Total expected size to reclaim */}
            <div className="bg-primary/5 rounded-xl border border-primary/20 p-lg relative overflow-hidden group">
              <div className="absolute -right-4 -bottom-4 opacity-10 group-hover:scale-110 transition-transform duration-500 pointer-events-none">
                <span className="material-symbols-outlined text-[120px]">eco</span>
              </div>
              <h4 className="font-label-md text-primary uppercase font-bold tracking-widest mb-xs">{t('cleanImpactReclaim')}</h4>
              <div className="flex items-baseline gap-xs text-primary mb-md">
                <span className="text-[48px] font-black leading-none">
                  {hasIncompleteEstimate ? '≥ ' : ''}{formatBytes(getExpectedImpactBytes())}
                </span>
              </div>
              <p className="text-label-sm text-on-surface-variant leading-relaxed">
                {t('cleanImpactDesc')}
              </p>
            </div>

            {/* Action buttons */}
            <div className="space-y-sm">
              <button
                onClick={() => handleStartCleanup(false)}
                disabled={selectedIds.length === 0 || hasSelectedDeepOnlyTarget}
                className="w-full py-sm px-md bg-primary text-on-primary rounded-lg font-label-md font-bold hover:opacity-90 active:scale-[0.98] transition-all cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed text-center shadow-md flex items-center justify-center gap-xs font-semibold"
              >
                <span className="material-symbols-outlined">cleaning_services</span>
                {t('cleanActionSafe')}
              </button>
              <button
                onClick={() => handleStartCleanup(true)}
                disabled={selectedIds.length === 0}
                className="w-full py-sm px-md bg-error text-on-error rounded-lg font-label-md font-bold hover:opacity-90 active:scale-[0.98] transition-all cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed text-center shadow-md flex items-center justify-center gap-xs font-semibold"
              >
                <span className="material-symbols-outlined">bolt</span>
                {t('cleanActionDeep')}
              </button>
            </div>

          </div>
        </div>
      )}

      {/* Terminal Live Output logs during execution */}
      {(cleanupState === 'running' || cleanupState === 'completed' || cleanupState === 'failed') && (
        <div className="bg-inverse-surface rounded-xl border border-outline shadow-xl overflow-hidden flex flex-col h-[400px] text-left">
          <div className="px-md py-sm bg-[#1a1c1d] border-b border-outline/30 flex items-center justify-between">
            <div className="flex items-center gap-md">
              <div className="flex gap-1.5">
                <div className="w-3 h-3 rounded-full bg-red-500/80"></div>
                <div className="w-3 h-3 rounded-full bg-amber-500/80"></div>
                <div className="w-3 h-3 rounded-full bg-green-500/80"></div>
              </div>
              <span className="font-code text-code text-on-surface-variant/80 ml-2 font-bold">
                {t('cleanConsoleTitle')} ({cleanupState === 'running' ? 'Running' : cleanupState === 'completed' ? 'Completed' : 'Failed'})
              </span>
            </div>
            <span className="text-[11px] font-code text-on-surface-variant/60 font-mono">
              {t('cleanConsoleSubtitle')}
            </span>
          </div>
          <div
            ref={logConsoleRef}
            className="p-md font-code text-code text-primary-fixed-dim/90 overflow-y-auto flex-1 space-y-1 bg-black/40 custom-scrollbar font-mono text-[12px]"
          >
            {runningLogs.map((log, index) => {
              let color = 'text-primary-fixed-dim';
              if (log.level === 'SUMMARY') color = 'text-green-400 font-bold';
              if (log.level === 'ERROR') color = 'text-red-400';
              if (log.level === 'SKIP_LOCKED') color = 'text-amber-400';
              if (log.level === 'DELETE_OK') color = 'text-cyan-400';

              return (
                <p key={index} className={color}>
                  {log.message} {log.path ? ` -> ${log.path}` : ''} {log.bytes ? ` (${formatBytes(log.bytes)})` : ''}
                </p>
              );
            })}
            {cleanupState === 'running' && <p className="text-primary-fixed-dim animate-pulse">_</p>}
          </div>
        </div>
      )}

      {/* Confirmation Modal */}
      {cleanupState === 'confirming' && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-md">
          <div className="bg-surface-container-lowest w-full max-w-[32rem] max-h-[calc(100vh-2rem)] overflow-y-auto rounded-xl border border-outline-variant shadow-2xl p-lg space-y-lg text-left animate-in fade-in zoom-in-95 duration-200">
            <div className="flex items-center gap-md text-error">
              <span className="material-symbols-outlined text-[36px]" style={{ fontVariationSettings: "'FILL' 1" }}>warning</span>
              <h3 className="font-headline-sm text-headline-sm font-bold">{t('cleanConfirmTitle')}</h3>
            </div>

            <div className="space-y-sm text-body-md text-on-surface-variant">
              <p className="font-semibold text-on-surface">{t('cleanConfirmBody')}</p>
              <p className="whitespace-pre-line text-sm bg-surface-container p-sm rounded-lg font-mono text-[12px] text-on-surface-variant/90 border border-outline-variant/40 leading-relaxed">
                {riskReason}
              </p>
              <p className="text-sm italic pt-xs border-t border-outline-variant/30">
                {t('cleanConfirmWarning')}
              </p>
            </div>

            <div className="flex justify-end gap-sm pt-sm">
              <button
                onClick={() => setCleanupState('idle')}
                className="px-lg py-sm border border-outline text-on-surface rounded-lg font-label-md text-label-md hover:bg-surface-container-high transition-all cursor-pointer"
              >
                {t('cleanConfirmCancel')}
              </button>
              <button
                onClick={() => executeCleanup(isDeepClean)}
                className="px-xl py-sm bg-error text-on-error rounded-lg font-label-md text-label-md font-bold hover:opacity-90 active:scale-95 transition-all shadow-md cursor-pointer"
              >
                Xác nhận & Chạy
              </button>
            </div>
          </div>
        </div>
      )}

    </div>
  );
};
