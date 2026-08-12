import React, { useState, useEffect, useRef } from 'react';
import { api } from '../api/client';
import type { AutoDnsTaskState, LogEvent } from '../api/types';
import { useTranslation } from '../i18n/translations';

interface AutoTaskViewProps {
  lang: 'vi' | 'en';
}

export const AutoTaskView: React.FC<AutoTaskViewProps> = ({ lang }) => {
  const [taskState, setTaskState] = useState<AutoDnsTaskState | null>(null);
  const [loading, setLoading] = useState(false);
  const [activeAction, setActiveAction] = useState<'create' | 'remove' | 'test' | null>(null);
  const [logs, setLogs] = useState<LogEvent[]>([]);
  const consoleRef = useRef<HTMLDivElement | null>(null);
  const t = useTranslation(lang);

  useEffect(() => {
    api.getAutoDnsTask().then(setTaskState);

    const unsubscribe = api.subscribe(() => {
      api.getAutoDnsTask().then(setTaskState);
    });

    return unsubscribe;
  }, []);

  useEffect(() => {
    if (consoleRef.current) {
      consoleRef.current.scrollTop = consoleRef.current.scrollHeight;
    }
  }, [logs]);

  const addLocalLog = (message: string, level: LogEvent['level'] = 'INFO') => {
    setLogs(prev => [...prev, { timestamp: new Date().toISOString(), level, message }]);
  };

  const formatLastRun = (lastRunStr: string | null | undefined, currentLang: 'vi' | 'en') => {
    if (!lastRunStr) {
      return currentLang === 'vi' ? 'Chưa từng chạy' : 'Never run';
    }
    const lower = lastRunStr.toLowerCase().trim();
    if (
      lower === 'never' ||
      lower === 'n/a' ||
      lower === 'null' ||
      lower === '' ||
      lower === 'none'
    ) {
      return currentLang === 'vi' ? 'Chưa từng chạy' : 'Never run';
    }

    try {
      const date = new Date(lastRunStr);
      if (isNaN(date.getTime())) {
        return currentLang === 'vi' ? 'Chưa từng chạy' : 'Never run';
      }

      const year = date.getFullYear();
      if (year < 2000) {
        return currentLang === 'vi' ? 'Chưa từng chạy' : 'Never run';
      }

      if (currentLang === 'vi') {
        const day = String(date.getDate()).padStart(2, '0');
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const hours = String(date.getHours()).padStart(2, '0');
        const minutes = String(date.getMinutes()).padStart(2, '0');
        return `${day}/${month}/${year} ${hours}:${minutes}`;
      } else {
        return date.toLocaleString('en-US', {
          month: 'long',
          day: 'numeric',
          year: 'numeric',
          hour: 'numeric',
          minute: '2-digit',
          hour12: true
        });
      }
    } catch {
      return currentLang === 'vi' ? 'Chưa từng chạy' : 'Never run';
    }
  };

  const handleCreateTask = async () => {
    if (loading) return;
    if (!window.confirm(t('taskCreateConfirm'))) return;
    setLoading(true);
    setActiveAction('create');
    setLogs([]);

    addLocalLog("PS C:\\Users\\System\\NetBoost> ./Register-ScheduledTask.ps1 -TaskName 'NetBoost Auto DNS Optimizer'", 'INFO');

    await api.createAutoDnsTask((prog, log) => {
      if (log) {
        setLogs(prev => [...prev, log]);
      }
      if (prog === 100) {
        setTimeout(() => {
          setLoading(false);
          setActiveAction(null);
        }, 800);
      }
    });
  };

  const handleRemoveTask = async () => {
    if (loading) return;
    setLoading(true);
    setActiveAction('remove');
    setLogs([]);

    addLocalLog("PS C:\\Users\\System\\NetBoost> ./Unregister-ScheduledTask.ps1 -TaskName 'NetBoost Auto DNS Optimizer'", 'INFO');

    await api.removeAutoDnsTask((prog, log) => {
      if (log) {
        setLogs(prev => [...prev, log]);
      }
      if (prog === 100) {
        setTimeout(() => {
          setLoading(false);
          setActiveAction(null);
        }, 800);
      }
    });
  };

  const handleRunNow = async () => {
    if (loading) return;
    setLoading(true);
    setActiveAction('test');
    setLogs([]);

    const initialLogs: LogEvent[] = [
      { timestamp: new Date().toISOString(), level: 'INFO', message: "PS C:\\Users\\System\\NetBoost> Start-ScheduledTask -TaskName 'NetBoost Auto DNS Optimizer'" },
      { timestamp: new Date().toISOString(), level: 'INFO', message: "[INFO] Kích hoạt chạy thử tác vụ Auto DNS ngay lập tức..." }
    ];
    setLogs(initialLogs);

    await api.testAutoDnsTask((currentLogs, jobState) => {
      setLogs([...initialLogs, ...currentLogs]);

      if (jobState && (jobState.status === 'completed' || jobState.status === 'failed')) {
        setTimeout(() => {
          setLoading(false);
          setActiveAction(null);
        }, 800);
      }
    });
  };

  if (!taskState) return <div className="p-lg text-on-surface-variant font-medium">{t('loading')}</div>;

  const normalizedStatus = taskState.status.toLowerCase();
  const taskInstalled = normalizedStatus !== 'inactive' && normalizedStatus !== 'not installed';
  const taskRunnable = taskInstalled && normalizedStatus !== 'disabled';
  const taskHealthy = taskRunnable && normalizedStatus !== 'unknown';
  const taskStatusLabel = !taskInstalled
    ? t('taskStatusNotInstalled')
    : normalizedStatus === 'disabled'
      ? t('taskStatusDisabled')
      : t('taskStatusReady', { status: taskState.status });

  return (
    <div className="space-y-lg text-left">
      {/* Page Header */}
      <section>
        <h1 className="font-display-lg text-display-lg text-on-surface">{t('taskTitle')}</h1>
        <p className="font-body-lg text-body-lg text-on-surface-variant mt-xs">
          {t('taskSubtitle')}
        </p>
      </section>

      {/* Warning Panel */}
      <div className="bg-error-container/30 border border-error/20 p-md rounded-lg flex items-start gap-md">
        <span className="material-symbols-outlined text-error mt-0.5">warning</span>
        <p className="font-body-md text-body-md text-on-error-container leading-relaxed">
          {t('taskAdminAlert')}
        </p>
      </div>

      {/* Bento Grid */}
      <div className="grid grid-cols-12 gap-lg">

        {/* Status Card (Left Column) */}
        <div className="col-span-12 lg:col-span-8 bg-surface-container-lowest border border-outline-variant rounded-xl shadow-sm p-lg flex flex-col justify-between">
          <div className="flex flex-col md:flex-row justify-between items-start gap-sm">
            <div>
              <span className="font-label-sm text-label-sm text-primary uppercase font-bold tracking-wider mb-xs block">
                Windows Task Scheduler
              </span>
              <h3 className="font-headline-sm text-headline-sm font-bold text-on-surface">
                {taskState.name}
              </h3>
            </div>

            <div className={`flex items-center gap-xs px-sm py-1 rounded-full ${taskHealthy ? 'bg-green-100 text-green-700 dark:bg-green-500/10 dark:text-green-400' : 'bg-surface-variant text-on-surface-variant'}`}>
              <span className={`w-2.5 h-2.5 rounded-full ${taskHealthy ? 'bg-green-500 animate-pulse' : 'bg-outline'} inline-block`}></span>
              <span className="font-label-sm text-label-sm font-bold">
                {taskStatusLabel}
              </span>
            </div>
          </div>

          <div className="grid grid-cols-2 md:grid-cols-4 gap-md mt-lg pt-lg border-t border-outline-variant/30">
            <div className="p-sm bg-surface-container rounded-lg border border-outline-variant/10">
              <p className="text-[11px] text-on-surface-variant font-semibold">{t('taskTriggerLabel')}</p>
              <p className="font-title-lg text-[15px] font-bold text-on-surface truncate">{taskState.trigger || 'At logon'}</p>
            </div>
            <div className="p-sm bg-surface-container rounded-lg border border-outline-variant/10">
              <p className="text-[11px] text-on-surface-variant font-semibold">{t('taskDelayLabel')}</p>
              <p className="font-title-lg text-[15px] font-bold text-on-surface">{taskState.delay || '30 seconds'}</p>
            </div>
            <div className="p-sm bg-surface-container rounded-lg border border-outline-variant/10">
              <p className="text-[11px] text-on-surface-variant font-semibold">{t('taskLastRunLabel')}</p>
              <p className="font-title-lg text-[15px] font-bold text-on-surface">{formatLastRun(taskState.lastRun, lang)}</p>
            </div>
            <div className="p-sm bg-surface-container rounded-lg border border-outline-variant/10">
              <p className="text-[11px] text-on-surface-variant font-semibold">{t('taskPrivilegeLabel')}</p>
              <p className="font-title-lg text-[15px] font-bold text-on-surface">Highest Privileges</p>
            </div>
          </div>
        </div>

        {/* Actions Card (Right Column) */}
        <div className="col-span-12 lg:col-span-4 bg-surface-container-lowest border border-outline-variant rounded-xl shadow-sm p-lg">
          <h4 className="font-title-lg text-title-lg font-bold text-on-surface mb-md">{t('taskQuickActionHeader')}</h4>
          <div className="flex flex-col gap-sm">
            {!taskInstalled ? (
              <button
                onClick={handleCreateTask}
                disabled={loading}
                className="w-full flex items-center justify-center gap-sm bg-primary text-on-primary font-label-md text-label-md font-bold py-md rounded-lg hover:bg-primary/95 active:scale-95 transition-all cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {activeAction === 'create' ? (
                  <span className="material-symbols-outlined animate-spin">sync</span>
                ) : (
                  <span className="material-symbols-outlined">add_task</span>
                )}
                {activeAction === 'create' ? (lang === 'vi' ? 'Đang tạo...' : 'Creating...') : t('taskActionCreate')}
              </button>
            ) : (
              <button
                onClick={handleRemoveTask}
                disabled={loading}
                className="w-full flex items-center justify-center gap-sm text-error border border-error/30 hover:bg-error/5 font-label-md text-label-md font-bold py-md rounded-lg transition-all cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {activeAction === 'remove' ? (
                  <span className="material-symbols-outlined animate-spin">sync</span>
                ) : (
                  <span className="material-symbols-outlined">delete_forever</span>
                )}
                {activeAction === 'remove' ? (lang === 'vi' ? 'Đang gỡ...' : 'Removing...') : t('taskActionRemove')}
              </button>
            )}
            <button
              onClick={handleRunNow}
              disabled={loading || !taskRunnable}
              className="w-full flex items-center justify-center gap-sm bg-surface-container-high text-on-surface font-label-md text-label-md font-bold py-md rounded-lg hover:bg-surface-variant transition-all active:scale-95 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {activeAction === 'test' ? (
                <span className="material-symbols-outlined animate-spin">sync</span>
              ) : (
                <span className="material-symbols-outlined">play_arrow</span>
              )}
              {activeAction === 'test' ? (lang === 'vi' ? 'Đang chạy...' : 'Processing...') : t('taskActionTest')}
            </button>
          </div>
        </div>

        {/* Timeline Timeline Steps */}
        {taskInstalled && (
          <div className="col-span-12 bg-surface-container-lowest border border-outline-variant rounded-xl shadow-sm overflow-hidden">
            <div className="px-lg py-md border-b border-outline-variant flex justify-between items-center bg-surface-container-low">
              <h4 className="font-title-lg text-title-lg font-bold text-on-surface">{t('taskWorkflowHeader')}</h4>
              <span className="font-label-sm text-label-sm text-on-surface-variant font-semibold">{t('taskWorkflowTrigger')}</span>
            </div>

            <div className="p-lg">
              <div className="relative flex flex-col gap-lg before:content-[''] before:absolute before:left-[11px] before:top-2 before:bottom-2 before:w-[2px] before:bg-outline-variant/30">
                {/* Step 1 */}
                <div className="relative pl-10">
                  <span className="absolute left-0 top-0 w-6 h-6 rounded-full bg-primary flex items-center justify-center border-4 border-surface-container-lowest ring-1 ring-primary/20">
                    <span className="material-symbols-outlined text-[12px] text-white" style={{ fontVariationSettings: "'FILL' 1" }}>check</span>
                  </span>
                  <div className="flex flex-col">
                    <span className="font-label-md text-label-md text-on-surface font-bold">{t('taskStep1Title')}</span>
                    <span className="font-label-sm text-label-sm text-on-surface-variant">{t('taskStep1Desc')}</span>
                  </div>
                </div>

                {/* Step 2 */}
                <div className="relative pl-10">
                  <span className="absolute left-0 top-0 w-6 h-6 rounded-full bg-primary flex items-center justify-center border-4 border-surface-container-lowest ring-1 ring-primary/20">
                    <span className="material-symbols-outlined text-[12px] text-white" style={{ fontVariationSettings: "'FILL' 1" }}>check</span>
                  </span>
                  <div className="flex flex-col">
                    <span className="font-label-md text-label-md text-on-surface font-bold">{t('taskStep2Title')}</span>
                    <span className="font-label-sm text-label-sm text-on-surface-variant">{t('taskStep2Desc')}</span>
                  </div>
                </div>

                {/* Step 3 */}
                <div className="relative pl-10">
                  <span className="absolute left-0 top-0 w-6 h-6 rounded-full bg-primary flex items-center justify-center border-4 border-surface-container-lowest ring-1 ring-primary/20">
                    <span className="material-symbols-outlined text-[12px] text-white" style={{ fontVariationSettings: "'FILL' 1" }}>check</span>
                  </span>
                  <div className="flex flex-col">
                    <span className="font-label-md text-label-md text-on-surface font-bold">{t('taskStep3Title')}</span>
                    <span className="font-label-sm text-label-sm text-on-surface-variant">{t('taskStep3Desc')}</span>
                  </div>
                </div>

                {/* Step 4 */}
                <div className="relative pl-10">
                  <span className="absolute left-0 top-0 w-6 h-6 rounded-full bg-primary flex items-center justify-center border-4 border-surface-container-lowest ring-1 ring-primary/20">
                    <span className="material-symbols-outlined text-[12px] text-white" style={{ fontVariationSettings: "'FILL' 1" }}>check</span>
                  </span>
                  <div className="flex flex-col">
                    <span className="font-label-md text-label-md text-on-surface font-bold">{t('taskStep4Title')}</span>
                    <span className="font-label-sm text-label-sm text-on-surface-variant">{t('taskStep4Desc')}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* PowerShell Logs Console */}
        <div className="col-span-12 bg-inverse-surface rounded-xl shadow-lg overflow-hidden border border-outline-variant/30">
          <div className="bg-[#1e1e1e] px-md py-sm flex items-center justify-between border-b border-white/5">
            <div className="flex items-center gap-sm">
              <span className="material-symbols-outlined text-surface-variant text-[18px]">terminal</span>
              <span className="font-code text-code text-surface-variant font-bold">{t('taskConsoleTitle')}</span>
            </div>
            <div className="flex gap-xs">
              <div className="w-2.5 h-2.5 rounded-full bg-red-500/40"></div>
              <div className="w-2.5 h-2.5 rounded-full bg-amber-500/40"></div>
              <div className="w-2.5 h-2.5 rounded-full bg-green-500/40"></div>
            </div>
          </div>
          <div
            ref={consoleRef}
            className="p-lg font-code text-code text-[#d4d4d4] h-48 overflow-y-auto custom-scrollbar bg-[#1a1a1a] text-left font-mono text-[12px] space-y-1"
          >
            {logs.length === 0 ? (
              <>
                <p className="text-on-surface-variant/40 italic">{t('taskConsolePlaceholder')}</p>
              </>
            ) : (
              logs.map((log, i) => {
                let color = 'text-[#d4d4d4]';
                if (log.level === 'SUMMARY') color = 'text-green-400 font-bold';
                if (log.level === 'ERROR') color = 'text-red-400';
                return (
                  <p key={i} className={color}>
                    {log.message}
                  </p>
                );
              })
            )}
            {loading && <p className="animate-pulse pl-1 border-l border-primary text-primary">_</p>}
          </div>
        </div>

      </div>
    </div>
  );
};
