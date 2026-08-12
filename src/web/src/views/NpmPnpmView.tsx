import React, { useState, useEffect, useRef } from 'react';
import { api } from '../api/client';
import type { NpmProject, NpmScanJobState } from '../api/types';
import { useTranslation } from '../i18n/translations';

interface NpmPnpmViewProps {
  lang: 'vi' | 'en';
}

export const NpmPnpmView: React.FC<NpmPnpmViewProps> = ({ lang }) => {
  const [pathInput, setPathInput] = useState('D:\\Projects\\Web');
  const [depth, setDepth] = useState('5');
  const [exclude, setExclude] = useState('node_modules, .git, dist, build');

  const [jobState, setJobState] = useState<NpmScanJobState | null>(() => api.getActiveNpmScan());
  const [selectedProject, setSelectedProject] = useState<NpmProject | null>(null);
  const [copiedText, setCopiedText] = useState<string | null>(null);
  const [selectingFolder, setSelectingFolder] = useState(false);

  const terminalRef = useRef<HTMLDivElement | null>(null);

  const handleSelectFolder = async () => {
    if (selectingFolder) return;
    setSelectingFolder(true);
    try {
      const selected = await api.selectFolder();
      if (selected) {
        setPathInput(selected);
      }
    } catch (e) {
      console.error('Failed to select folder', e);
    } finally {
      setSelectingFolder(false);
    }
  };
  const t = useTranslation(lang);

  useEffect(() => {
    if (terminalRef.current) {
      terminalRef.current.scrollTop = terminalRef.current.scrollHeight;
    }
  }, [jobState?.logs]);

  const handleStartScan = async () => {
    setJobState(null);
    setSelectedProject(null);

    await api.scanNpmProjects({
      root: pathInput,
      maxDepth: parseInt(depth),
      ignore: exclude.split(',').map(x => x.trim())
    }, (updatedState) => {
      setJobState(updatedState);
      if (updatedState.status === 'completed' && updatedState.projects.length > 0) {
        setSelectedProject(updatedState.projects[0]);
      }
    });
  };

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
    setCopiedText(text);
    setTimeout(() => {
      setCopiedText(null);
    }, 1500);
  };

  const formatBytes = (bytes: number) => {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
  };

  return (
    <div className="space-y-lg text-left">
      {/* Page Header */}
      <section className="mb-sm">
        <h1 className="font-display-lg text-display-lg text-on-surface">{t('npmTitle')}</h1>
        <p className="text-body-lg text-body-lg text-on-surface-variant mt-xs">
          {t('npmSubtitle')}
        </p>
      </section>

      {/* Report Only Note */}
      <div className="bg-primary/5 border border-primary/20 text-on-primary-container p-sm rounded-lg flex items-center gap-sm">
        <span className="material-symbols-outlined text-primary text-[20px]">info</span>
        <span className="font-medium text-body-md">
          <span className="font-bold">{t('npmImportant')}</span> {t('npmDisclaimer')}
        </span>
      </div>

      {/* Path Search Panel */}
      <section className="bg-surface-container-lowest p-lg rounded-xl border border-outline-variant shadow-sm grid grid-cols-12 gap-lg items-end">
        <div className="col-span-12 md:col-span-6 space-y-sm">
          <label className="font-label-sm text-label-sm text-on-surface-variant font-semibold">{t('npmPathLabel')}</label>
          <div className="flex gap-sm">
            <div className="flex-1 flex items-center bg-surface-container border border-outline-variant rounded-lg px-md h-11 focus-within:ring-2 focus-within:ring-primary-container transition-all">
              <span className="material-symbols-outlined text-on-surface-variant text-[20px] mr-sm">folder_open</span>
              <input
                type="text"
                value={pathInput}
                onChange={(e) => setPathInput(e.target.value)}
                className="bg-transparent border-none outline-none w-full text-body-md text-on-surface focus:ring-0"
                placeholder={t('npmPathPlaceholder')}
              />
            </div>
            <button
              onClick={handleSelectFolder}
              disabled={selectingFolder}
              className="px-lg h-11 border border-outline text-primary font-label-md text-label-md rounded-lg hover:bg-surface-container-high transition-all active:scale-95 cursor-pointer whitespace-nowrap disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-xs"
            >
              {selectingFolder && <span className="material-symbols-outlined animate-spin text-[18px]">sync</span>}
              <span>{t('npmPathBtnOther')}</span>
            </button>
          </div>
        </div>

        <div className="col-span-6 md:col-span-2 space-y-sm">
          <label className="font-label-sm text-label-sm text-on-surface-variant font-semibold">{t('npmDepthLabel')}</label>
          <select
            value={depth}
            onChange={(e) => setDepth(e.target.value)}
            className="w-full h-11 bg-surface-container border border-outline-variant rounded-lg px-md text-body-md focus:ring-primary focus:border-primary outline-none"
          >
            <option value="2">{t('npmDepthFast')}</option>
            <option value="5">{t('npmDepthDefault')}</option>
            <option value="10">{t('npmDepthDeep')}</option>
          </select>
        </div>

        <div className="col-span-6 md:col-span-4 space-y-sm">
          <label className="font-label-sm text-label-sm text-on-surface-variant font-semibold">{t('npmIgnoreLabel')}</label>
          <input
            type="text"
            value={exclude}
            onChange={(e) => setExclude(e.target.value)}
            className="w-full h-11 bg-surface-container border border-outline-variant rounded-lg px-md text-body-md focus:ring-primary focus:border-primary outline-none"
          />
        </div>

        <div className="col-span-12 flex justify-end gap-md pt-sm border-t border-outline-variant/20">
          <button
            onClick={handleStartScan}
            disabled={jobState?.status === 'running'}
            className="px-xl h-12 bg-primary text-on-primary font-bold rounded-lg shadow-md hover:opacity-90 active:scale-95 transition-all flex items-center gap-sm cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {jobState?.status === 'running' ? (
              <span className="material-symbols-outlined animate-spin">sync</span>
            ) : (
              <span className="material-symbols-outlined">search</span>
            )}
            {jobState?.status === 'running' ? t('npmBtnScanning') : t('npmBtnScan')}
          </button>
        </div>
      </section>

      {/* Summary Cards */}
      {jobState && (
        <section className="grid grid-cols-2 lg:grid-cols-4 gap-lg">
          <div className="bg-surface-container-lowest p-lg rounded-xl border border-outline-variant shadow-sm flex items-center gap-lg">
            <div className="w-12 h-12 rounded-full bg-primary-container/20 flex items-center justify-center text-primary flex-shrink-0">
              <span className="material-symbols-outlined">inventory_2</span>
            </div>
            <div>
              <p className="text-[12px] font-bold text-on-surface-variant">{t('npmStatFound')}</p>
              <p className="font-display-lg text-display-lg text-on-surface font-bold">{jobState.projectsFound}</p>
            </div>
          </div>

          <div className="bg-surface-container-lowest p-lg rounded-xl border border-outline-variant shadow-sm flex items-center gap-lg">
            <div className="w-12 h-12 rounded-full bg-error-container/40 flex items-center justify-center text-error flex-shrink-0">
              <span className="material-symbols-outlined">storage</span>
            </div>
            <div>
              <p className="text-[12px] font-bold text-on-surface-variant">{t('npmStatTotal')}</p>
              <p className="font-display-lg text-display-lg text-on-surface font-bold">
                {formatBytes(jobState.totalNodeModulesBytes)}
              </p>
            </div>
          </div>

          <div className="bg-surface-container-lowest p-lg rounded-xl border border-outline-variant shadow-sm flex items-center gap-lg">
            <div className="w-12 h-12 rounded-full bg-secondary-container/50 flex items-center justify-center text-secondary flex-shrink-0">
              <span className="material-symbols-outlined">lock</span>
            </div>
            <div>
              <p className="text-[12px] font-bold text-on-surface-variant">{t('npmStatPackageLock')}</p>
              <p className="font-display-lg text-display-lg text-on-surface font-bold">{jobState.packageLockCount}</p>
            </div>
          </div>

          <div className="bg-surface-container-lowest p-lg rounded-xl border border-outline-variant shadow-sm flex items-center gap-lg ring-2 ring-primary-container/30">
            <div className="w-12 h-12 rounded-full bg-inverse-primary/20 flex items-center justify-center text-primary flex-shrink-0">
              <span className="material-symbols-outlined">eco</span>
            </div>
            <div>
              <p className="text-[12px] font-bold text-primary">{t('npmStatSavings')}</p>
              <p className="font-display-lg text-display-lg text-primary font-bold">
                {formatBytes(jobState.expectedSavingsBytes)}
              </p>
            </div>
          </div>
        </section>
      )}

      {/* Main List and Sidebar Split */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-lg items-start">

        {/* Left Column: Projects table */}
        <div className="lg:col-span-8 bg-surface-container-lowest rounded-xl border border-outline-variant shadow-sm overflow-hidden flex flex-col">
          <div className="px-lg py-md border-b border-outline-variant flex justify-between items-center bg-surface-container-low">
            <h4 className="font-title-lg text-title-lg text-on-surface font-bold">{t('npmListTitle')}</h4>
            {jobState?.projects.length ? (
              <span className="px-sm py-xs bg-surface-variant text-on-surface-variant text-[11px] rounded uppercase font-bold tracking-wider">
                {t('npmListDisplay', { count: jobState.projects.length })}
              </span>
            ) : null}
          </div>

          <div className="overflow-x-auto">
            {!jobState || jobState.projects.length === 0 ? (
              <div className="py-xl text-center text-on-surface-variant italic">
                {jobState?.status === 'running' ? t('npmListScanning') : t('npmListEmpty')}
              </div>
            ) : (
              <table className="w-full text-left border-collapse">
                <thead>
                  <tr className="text-on-surface-variant border-b border-outline-variant bg-surface-container-low/50">
                    <th className="px-lg py-sm font-label-sm text-label-sm">{t('npmColPath')}</th>
                    <th className="px-lg py-sm font-label-sm text-label-sm">{t('npmColLockfile')}</th>
                    <th className="px-lg py-sm font-label-sm text-label-sm">{t('npmColNodeModules')}</th>
                    <th className="px-lg py-sm font-label-sm text-label-sm">{t('npmColStatus')}</th>
                    <th className="px-lg py-sm font-label-sm text-label-sm"></th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-surface-container">
                  {jobState.projects.map((project, idx) => {
                    const isSelected = selectedProject?.path === project.path;

                    let statusBadge = 'bg-surface-variant text-on-surface-variant';
                    let statusText = t('npmStatusNeedsConfig');
                    if (project.status === 'ready') {
                      statusBadge = 'bg-green-100 text-green-700 dark:bg-green-500/10 dark:text-green-400';
                      statusText = t('npmStatusReady');
                    } else if (project.status === 'completed') {
                      statusBadge = 'bg-blue-100 text-blue-700 dark:bg-blue-500/10 dark:text-blue-400';
                      statusText = t('npmStatusCompleted');
                    }

                    return (
                      <tr
                        key={idx}
                        onClick={() => setSelectedProject(project)}
                        className={`hover:bg-primary-container/5 transition-colors group cursor-pointer ${isSelected ? 'bg-primary-container/10' : ''}`}
                      >
                        <td className="px-lg py-md">
                          <div className="flex items-center gap-sm">
                            <span className={`material-symbols-outlined ${project.status === 'completed' ? 'text-blue-500' : 'text-amber-500'}`}>folder</span>
                            <span className={`font-label-md text-label-md ${isSelected ? 'text-primary font-bold' : 'text-on-surface font-semibold'}`}>{project.path}</span>
                          </div>
                        </td>
                        <td className="px-lg py-md text-on-surface-variant font-mono text-xs">{project.lockfile}</td>
                        <td className={`px-lg py-md font-code font-bold ${project.nodeModulesSize > 500*1024*1024 ? 'text-error' : 'text-on-surface'}`}>
                          {formatBytes(project.nodeModulesSize)}
                        </td>
                        <td className="px-lg py-md">
                          <span className={`px-sm py-xs rounded-full text-[11px] font-bold ${statusBadge}`}>
                            {statusText}
                          </span>
                        </td>
                        <td className="px-lg py-md text-right">
                          <span className={`material-symbols-outlined text-on-surface-variant ${isSelected ? 'text-primary' : 'group-hover:text-primary'}`}>
                            chevron_right
                          </span>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            )}
          </div>
          <div className="px-lg py-sm bg-surface-container-high/30 border-t border-outline-variant italic text-[12px] text-on-surface-variant flex items-center gap-sm">
            <span className="material-symbols-outlined text-[16px]">info</span>
            <span>{t('npmDisclaimer')}</span>
          </div>
        </div>

        {/* Right Column: Detail Sidebar / Guide Drawer */}
        <div className="lg:col-span-4 bg-surface-container-lowest border border-outline-variant rounded-xl shadow-sm p-lg flex flex-col gap-lg">
          {selectedProject ? (
            <div className="space-y-lg text-left">
              <div>
                <span className="px-sm py-xs bg-primary-container text-on-primary-container rounded text-[10px] font-black uppercase mb-xs inline-block">
                  {t('npmDetailHeader')}
                </span>
                <h5 className="font-headline-sm text-headline-sm text-on-surface font-bold truncate">
                  {selectedProject.path.replace('/', '')}
                </h5>
              </div>

              <div className="p-md rounded-lg border border-outline-variant bg-surface-container-low space-y-sm">
                <p className="font-label-sm text-label-sm text-on-surface-variant font-semibold">{t('npmDetailCondition')}</p>
                <ul className="space-y-xs font-body-md text-body-md">
                  <li className="flex items-center gap-sm">
                    <span className="material-symbols-outlined text-green-600 text-[18px]" style={{ fontVariationSettings: "'FILL' 1" }}>check_circle</span>
                    <span>{t('npmDetailFoundJson')}</span>
                  </li>
                  <li className="flex items-center gap-sm">
                    <span className="material-symbols-outlined text-green-600 text-[18px]" style={{ fontVariationSettings: "'FILL' 1" }}>check_circle</span>
                    <span>{t('npmDetailLockfile', { file: selectedProject.lockfile })}</span>
                  </li>
                  {selectedProject.status !== 'completed' ? (
                    <li className="flex items-center gap-sm text-on-surface-variant opacity-60">
                      <span className="material-symbols-outlined text-[18px]">cancel</span>
                      <span>{t('npmDetailNoPnpm')}</span>
                    </li>
                  ) : (
                    <li className="flex items-center gap-sm">
                      <span className="material-symbols-outlined text-blue-600 text-[18px]" style={{ fontVariationSettings: "'FILL' 1" }}>check_circle</span>
                      <span className="text-blue-600 font-semibold">{t('npmDetailPnpmOk')}</span>
                    </li>
                  )}
                </ul>
              </div>

              {selectedProject.suggestions.length > 0 && (
                <div className="space-y-md">
                  <div className="flex justify-between items-center px-1">
                    <p className="font-label-sm text-label-sm text-on-surface-variant font-bold">{t('npmDetailStepsHeader')}</p>
                  </div>

                  <div className="space-y-md relative before:absolute before:left-[11px] before:top-2 before:bottom-2 before:w-px before:bg-outline-variant">
                    {selectedProject.suggestions.map((cmd, idx) => (
                      <div key={idx} className="relative pl-lg group/cmd">
                        <div className="absolute left-0 top-0 w-6 h-6 rounded-full bg-primary-container flex items-center justify-center ring-4 ring-surface-container-lowest">
                          <span className="text-[10px] text-on-primary-container font-black">{idx + 1}</span>
                        </div>
                        <div className="flex justify-between items-start">
                          <div>
                            <p className="font-label-md text-label-md text-on-surface font-bold font-mono">{cmd}</p>
                            <p className="text-[12px] text-on-surface-variant leading-relaxed">
                              {cmd === 'pnpm import' ? t('npmDetailStepImportDesc') :
                               cmd === 'pnpm install' ? t('npmDetailStepInstallDesc') :
                               t('npmDetailStepBuildDesc')}
                            </p>
                          </div>
                          <button
                            onClick={() => copyToClipboard(cmd)}
                            className="p-1 hover:bg-surface-variant rounded transition-all cursor-pointer text-on-surface-variant active:scale-90"
                            title={t('npmDetailCopyTitle')}
                          >
                            <span className="material-symbols-outlined text-[18px]">
                              {copiedText === cmd ? 'check' : 'content_copy'}
                            </span>
                          </button>
                        </div>
                        <div className="mt-xs p-xs bg-surface-container rounded font-code text-[11px] text-on-surface border border-outline-variant/30 font-mono">
                          {cmd}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              <div className="pt-sm border-t border-outline-variant space-y-md">
                <div className="p-sm bg-surface-container-low rounded-lg text-[11px] text-on-surface-variant leading-relaxed">
                  {t('npmDetailNote')}
                </div>
                <div className="rounded-xl overflow-hidden border border-outline-variant aspect-video relative group select-none">
                  <img
                    alt="Developer code setup"
                    className="w-full h-full object-cover transition-transform duration-700 group-hover:scale-110"
                    src="https://images.unsplash.com/photo-1555066931-4365d14bab8c?auto=format&fit=crop&w=400&q=80"
                  />
                  <div className="absolute inset-0 bg-gradient-to-t from-black/85 to-transparent flex flex-col justify-end p-md">
                    <p className="text-white font-label-md text-label-md font-bold">{t('npmDetailBannerTitle')}</p>
                    <p className="text-white/70 text-[11px]">{t('npmDetailBannerDesc')}</p>
                  </div>
                </div>
              </div>
            </div>
          ) : (
            <div className="py-xl text-center text-on-surface-variant italic">
              {t('npmDetailSidebarPlaceholder')}
            </div>
          )}
        </div>

      </div>

      {/* PowerShell Console Output at bottom */}
      {jobState && (
        <section className="h-[200px] bg-[#012456] rounded-xl border border-black overflow-hidden flex flex-col shadow-inner text-left font-mono">
          <div className="px-md py-1 bg-[#004a8d] flex items-center justify-between">
            <div className="flex items-center gap-sm">
              <span className="material-symbols-outlined text-white text-[16px]">terminal</span>
              <span className="text-white font-code text-[11px] font-bold">{t('npmConsoleTitle')}</span>
            </div>
            <div className="flex gap-md text-white/60">
              <span className="material-symbols-outlined text-[14px]">minimize</span>
              <span className="material-symbols-outlined text-[14px]">close</span>
            </div>
          </div>
          <div className="p-md font-code text-code text-[#cccccc] overflow-y-auto custom-scrollbar flex-1 leading-relaxed text-left text-[12px] space-y-0.5">
            <p>NetBoost Command Center v1.0.1 - Scanner Utility</p>
            <p>Scanning directory: {pathInput}</p>
            {jobState.logs.map((log, i) => {
              let color = 'text-[#cccccc]';
              if (log.level === 'SUMMARY') color = 'text-[#00ff00] font-bold';
              if (log.level === 'FOUND') color = 'text-[#00ff00]';
              if (log.level === 'ERROR') color = 'text-[#ff0000]';

              return (
                <p key={i} className={color}>
                  {log.message}
                </p>
              );
            })}
            {jobState.status === 'running' && <p className="animate-pulse pl-1 border-l border-white text-white">_</p>}
          </div>
        </section>
      )}

    </div>
  );
};
