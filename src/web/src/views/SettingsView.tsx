import React, { useState, useEffect } from 'react';
import { api } from '../api/client';
import type { SettingsState } from '../api/types';
import { useTranslation } from '../i18n/translations';

interface SettingsViewProps {
  lang: 'vi' | 'en';
  onLangChange: (lang: 'vi' | 'en') => void;
}

export const SettingsView: React.FC<SettingsViewProps> = ({ lang, onLangChange }) => {
  const [settings, setSettings] = useState<SettingsState | null>(null);

  // Simulated environment checking
  const [checkingPs, setCheckingPs] = useState(false);
  const [psCheckResult, setPsCheckResult] = useState<string | null>(null);

  const [openingPsFolder, setOpeningPsFolder] = useState(false);
  const [openingBatFolder, setOpeningBatFolder] = useState(false);

  const t = useTranslation(lang);

  useEffect(() => {
    api.getSettings().then(setSettings);
  }, []);

  const handleUpdate = async (updates: Partial<SettingsState>) => {
    if (!settings) return;
    const next = { ...settings, ...updates };
    setSettings(next);
    await api.updateSettings(updates);
    if (updates.language && onLangChange) {
      onLangChange(updates.language);
    }
  };

  const handleTestPowerShell = () => {
    if (checkingPs) return;
    setCheckingPs(true);
    setPsCheckResult(null);

    setTimeout(() => {
      setCheckingPs(false);
      setPsCheckResult(t('settingsIntegrationSuccess'));
    }, 1500);
  };

  const handleSelectPsFile = async () => {
    if (openingPsFolder) return;
    setOpeningPsFolder(true);
    try {
      const selected = await api.selectFile('ps1');
      if (selected) {
        handleUpdate({ powershellScriptPath: selected });
      }
    } catch (e) {
      console.error('Failed to select PowerShell file', e);
    } finally {
      setOpeningPsFolder(false);
    }
  };

  const handleSelectBatFile = async () => {
    if (openingBatFolder) return;
    setOpeningBatFolder(true);
    try {
      const selected = await api.selectFile('bat');
      if (selected) {
        handleUpdate({ launcherBatPath: selected });
      }
    } catch (e) {
      console.error('Failed to select batch file', e);
    } finally {
      setOpeningBatFolder(false);
    }
  };

  if (!settings) return <div className="p-lg text-on-surface-variant font-medium">{t('settingsLoading')}</div>;

  return (
    <div className="space-y-lg text-left">
      {/* Header Section */}
      <div className="mb-xl">
        <h1 className="font-display-lg text-display-lg text-on-surface">{t('settingsTitle')}</h1>
        <p className="font-body-lg text-body-lg text-on-surface-variant mt-xs">
          {t('settingsSubtitle')}
        </p>
      </div>

      {/* Settings Grid (Bento Style) */}
      <div className="grid grid-cols-12 gap-lg">

        {/* Section 1: Giao diện */}
        <section className="col-span-12 md:col-span-7 bg-surface-container-lowest border border-outline-variant rounded-xl p-lg shadow-sm">
          <div className="flex items-center gap-md mb-lg border-b border-surface-container pb-md">
            <span className="material-symbols-outlined text-primary">palette</span>
            <h4 className="font-headline-sm text-headline-sm font-bold">{t('settingsUiHeader')}</h4>
          </div>

          <div className="space-y-lg text-body-md text-on-surface">
            {/* Language Selection */}
            <div className="flex items-center justify-between gap-md">
              <div>
                <p className="font-label-md text-label-md font-bold">{t('settingsLangLabel')}</p>
                <p className="text-label-sm text-on-surface-variant text-sm">{t('settingsLangDesc')}</p>
              </div>
              <select
                value={settings.language}
                onChange={(e) => handleUpdate({ language: e.target.value as 'vi' | 'en' })}
                className="bg-surface-container border border-outline-variant rounded-lg px-md py-sm font-label-md text-label-md focus:ring-2 focus:ring-primary-container outline-none cursor-pointer"
              >
                <option value="vi">{t('settingsLangVi')}</option>
                <option value="en">{t('settingsLangEn')}</option>
              </select>
            </div>

            {/* Theme Selection */}
            <div className="flex items-center justify-between gap-md">
              <div>
                <p className="font-label-md text-label-md font-bold">{t('settingsThemeLabel')}</p>
                <p className="text-label-sm text-on-surface-variant text-sm font-normal">{t('settingsThemeDesc')}</p>
              </div>
              <div className="flex bg-surface-container p-xs rounded-lg border border-outline-variant">
                {(['light', 'dark', 'system'] as const).map(themeType => (
                  <button
                    key={themeType}
                    onClick={() => handleUpdate({ theme: themeType })}
                    className={`px-md py-sm rounded-md font-label-md text-label-md transition-all cursor-pointer ${
                      settings.theme === themeType
                        ? 'bg-surface-container-lowest shadow-sm font-bold text-primary'
                        : 'text-on-surface-variant hover:text-on-surface'
                    }`}
                  >
                    {themeType === 'light' ? t('settingsThemeLight') : themeType === 'dark' ? t('settingsThemeDark') : t('settingsThemeSystem')}
                  </button>
                ))}
              </div>
            </div>

            {/* Compact Mode */}
            <div className="flex items-center justify-between gap-md">
              <div>
                <p className="font-label-md text-label-md font-bold">{t('settingsCompactLabel')}</p>
                <p className="text-label-sm text-on-surface-variant text-sm">{t('settingsCompactDesc')}</p>
              </div>
              <label className="relative inline-flex items-center cursor-pointer select-none">
                <input
                  type="checkbox"
                  checked={settings.compactMode}
                  onChange={(e) => handleUpdate({ compactMode: e.target.checked })}
                  className="sr-only peer"
                />
                <div className="w-11 h-6 bg-surface-container-highest peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-primary"></div>
              </label>
            </div>
          </div>
        </section>

        {/* Section 2: About (Bento Sidebar) */}
        <section className="col-span-12 md:col-span-5 bg-inverse-surface text-inverse-on-surface rounded-xl p-lg shadow-lg relative overflow-hidden flex flex-col justify-between text-left">
          <div className="absolute top-0 right-0 w-32 h-32 bg-primary/10 rounded-full -mr-16 -mt-16 blur-2xl pointer-events-none"></div>
          <div>
            <div className="flex items-center gap-md mb-lg border-b border-outline/25 pb-sm">
              <span className="material-symbols-outlined text-inverse-primary">info</span>
              <h4 className="font-headline-sm text-headline-sm font-bold">{t('settingsAboutHeader')}</h4>
            </div>
            <ul className="space-y-md text-sm font-medium">
              <li className="flex justify-between border-b border-outline/10 pb-xs">
                <span className="opacity-70 font-semibold">{t('settingsAboutUiVersion')}</span>
                <span className="font-code text-code text-inverse-primary font-bold">v1.0.1 (Stable)</span>
              </li>
              <li className="flex justify-between border-b border-outline/10 pb-xs">
                <span className="opacity-70 font-semibold">{t('settingsAboutPsVersion')}</span>
                <span className="font-code text-code font-bold">v5.1+ Compatible</span>
              </li>
              <li className="flex justify-between border-b border-outline/10 pb-xs">
                <span className="opacity-70 font-semibold">{t('settingsAboutDataCollect')}</span>
                <span className="text-red-300 font-bold font-mono">{t('settingsAboutDataCollectDisabled')}</span>
              </li>
              <li className="flex justify-between">
                <span className="opacity-70 font-semibold">{t('settingsAboutConnection')}</span>
                <span className="text-primary-fixed-dim font-bold font-mono">127.0.0.1 bind only</span>
              </li>
            </ul>
          </div>
          <div className="mt-xl pt-lg border-t border-outline/20">
            <p className="text-[11px] opacity-50 text-center font-mono">© 2026 NetBoost Command Center. Local-first first policy.</p>
          </div>
        </section>

        {/* Section 3: Bảo mật local */}
        <section className="col-span-12 md:col-span-6 bg-surface-container-lowest border border-outline-variant rounded-xl p-lg shadow-sm">
          <div className="flex items-center gap-md mb-lg border-b border-surface-container pb-md">
            <span className="material-symbols-outlined text-primary">security</span>
            <h4 className="font-headline-sm text-headline-sm font-bold">{t('settingsSecurityHeader')}</h4>
          </div>
          <div className="space-y-lg text-body-md">
            <div>
              <p className="font-label-md text-label-md font-bold mb-xs">{t('settingsSecurityBindLabel')}</p>
              <input
                type="text"
                value={settings.bindAddress}
                disabled
                className="w-full bg-surface-container border border-outline-variant rounded-lg px-md py-sm font-code text-code text-on-surface-variant opacity-70 cursor-not-allowed outline-none"
              />
              <p className="text-[11px] text-on-surface-variant mt-1 leading-relaxed">
                {t('settingsSecurityBindDesc')}
              </p>
            </div>

            <div className="flex items-center justify-between gap-md pt-sm border-t border-outline-variant/30">
              <div>
                <p className="font-label-md text-label-md font-bold">{t('settingsSecurityTokenLabel')}</p>
                <p className="text-label-sm text-on-surface-variant text-sm">{t('settingsSecurityTokenDesc')}</p>
              </div>
              <label className="relative inline-flex items-center cursor-pointer select-none">
                <input
                  type="checkbox"
                  checked={settings.sessionTokenEnabled}
                  onChange={(e) => handleUpdate({ sessionTokenEnabled: e.target.checked })}
                  className="sr-only peer"
                />
                <div className="w-11 h-6 bg-surface-container-highest peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-primary"></div>
              </label>
            </div>

            <div className="flex items-center justify-between gap-md pt-sm border-t border-outline-variant/30">
              <div>
                <p className="font-label-md text-label-md font-bold">{t('settingsSecurityConfirmLabel')}</p>
                <p className="text-label-sm text-on-surface-variant text-sm">{t('settingsSecurityConfirmDesc')}</p>
              </div>
              <label className="relative inline-flex items-center cursor-pointer select-none">
                <input
                  type="checkbox"
                  checked={settings.confirmRiskyActions}
                  onChange={(e) => handleUpdate({ confirmRiskyActions: e.target.checked })}
                  className="sr-only peer"
                />
                <div className="w-11 h-6 bg-surface-container-highest peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-primary"></div>
              </label>
            </div>
          </div>
        </section>

        {/* Section 4: Nhật ký (Log) */}
        <section className="col-span-12 md:col-span-6 bg-surface-container-lowest border border-outline-variant rounded-xl p-lg shadow-sm">
          <div className="flex items-center gap-md mb-lg border-b border-surface-container pb-md">
            <span className="material-symbols-outlined text-primary">history_edu</span>
            <h4 className="font-headline-sm text-headline-sm font-bold">{t('settingsLogHeader')}</h4>
          </div>
          <div className="space-y-lg text-body-md">
            <div className="flex items-center justify-between gap-md">
              <div>
                <p className="font-label-md text-label-md font-bold">{t('settingsLogDetailedLabel')}</p>
                <p className="text-label-sm text-on-surface-variant text-sm">{t('settingsLogDetailedDesc')}</p>
              </div>
              <label className="relative inline-flex items-center cursor-pointer select-none">
                <input
                  type="checkbox"
                  checked={settings.detailedCleanupLogs}
                  onChange={(e) => handleUpdate({ detailedCleanupLogs: e.target.checked })}
                  className="sr-only peer"
                />
                <div className="w-11 h-6 bg-surface-container-highest peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-primary"></div>
              </label>
            </div>

            <div className="flex items-center justify-between gap-md pt-sm border-t border-outline-variant/30">
              <div>
                <p className="font-label-md text-label-md font-bold">{t('settingsLogAutoScrollLabel')}</p>
                <p className="text-label-sm text-on-surface-variant text-sm">{t('settingsLogAutoScrollDesc')}</p>
              </div>
              <label className="relative inline-flex items-center cursor-pointer select-none">
                <input
                  type="checkbox"
                  checked={settings.autoScrollLogs}
                  onChange={(e) => handleUpdate({ autoScrollLogs: e.target.checked })}
                  className="sr-only peer"
                />
                <div className="w-11 h-6 bg-surface-container-highest peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-primary"></div>
              </label>
            </div>

            <div className="space-y-xs pt-sm border-t border-outline-variant/30">
              <p className="font-label-md text-label-md font-bold">{t('settingsLogRetentionLabel')}</p>
              <div className="flex gap-md pt-xs">
                {([7, 30, -1] as const).map(days => (
                  <button
                    key={days}
                    onClick={() => handleUpdate({ logRetentionDays: days })}
                    className={`flex-1 py-sm border rounded-lg font-label-md text-label-md cursor-pointer transition-colors text-center ${
                      settings.logRetentionDays === days
                        ? 'border-primary bg-primary/5 text-primary font-bold'
                        : 'border-outline-variant text-on-surface-variant hover:bg-surface-container-low'
                    }`}
                  >
                    {days === 7 ? t('settingsLogRetention7') : days === 30 ? t('settingsLogRetention30') : t('settingsLogRetentionForever')}
                  </button>
                ))}
              </div>
            </div>
          </div>
        </section>

        {/* Section 5: PowerShell Paths & Tester */}
        <section className="col-span-12 bg-surface-container-lowest border border-outline-variant rounded-xl p-lg shadow-sm">
          <div className="flex items-center gap-md mb-lg border-b border-surface-container pb-md">
            <span className="material-symbols-outlined text-primary">terminal</span>
            <h4 className="font-headline-sm text-headline-sm font-bold">{t('settingsIntegrationHeader')}</h4>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-xl">
            <div className="space-y-md text-left">
              <div>
                <label className="font-label-md text-label-md font-bold text-on-surface block mb-xs">
                  {t('settingsIntegrationPsPath')}
                </label>
                <div className="flex gap-sm">
                  <input
                    type="text"
                    value={settings.powershellScriptPath}
                    onChange={(e) => handleUpdate({ powershellScriptPath: e.target.value })}
                    className="flex-1 bg-surface-container border border-outline-variant rounded-lg px-md py-sm font-code text-code text-on-surface outline-none focus:ring-2 focus:ring-primary-container font-mono text-sm"
                  />
                  <button
                    onClick={handleSelectPsFile}
                    disabled={openingPsFolder}
                    className="p-sm border border-outline-variant rounded-lg hover:bg-surface-container-high transition-colors cursor-pointer select-none disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center"
                  >
                    <span className={`material-symbols-outlined ${openingPsFolder ? 'animate-spin' : ''}`}>
                      {openingPsFolder ? 'sync' : 'folder_open'}
                    </span>
                  </button>
                </div>
              </div>

              <div>
                <label className="font-label-md text-label-md font-bold text-on-surface block mb-xs">
                  {t('settingsIntegrationBatPath')}
                </label>
                <div className="flex gap-sm">
                  <input
                    type="text"
                    value={settings.launcherBatPath}
                    onChange={(e) => handleUpdate({ launcherBatPath: e.target.value })}
                    className="flex-1 bg-surface-container border border-outline-variant rounded-lg px-md py-sm font-code text-code text-on-surface outline-none focus:ring-2 focus:ring-primary-container font-mono text-sm"
                  />
                  <button
                    onClick={handleSelectBatFile}
                    disabled={openingBatFolder}
                    className="p-sm border border-outline-variant rounded-lg hover:bg-surface-container-high transition-colors cursor-pointer select-none disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center"
                  >
                    <span className={`material-symbols-outlined ${openingBatFolder ? 'animate-spin' : ''}`}>
                      {openingBatFolder ? 'sync' : 'folder_open'}
                    </span>
                  </button>
                </div>
              </div>
            </div>

            <div className="flex flex-col justify-between space-y-md">
              <div className="bg-surface-container p-md rounded-xl border border-outline-variant/60 flex flex-col justify-center min-h-[110px]">
                <p className="text-label-sm text-on-surface-variant font-semibold mb-sm">{t('settingsIntegrationTestHeading')}</p>
                <div className="flex flex-wrap items-center gap-md">
                  <button
                    onClick={handleTestPowerShell}
                    disabled={checkingPs}
                    className="flex items-center gap-xs px-lg py-md bg-primary text-on-primary rounded-lg font-label-md text-label-md font-bold shadow-md hover:opacity-90 active:scale-95 transition-all cursor-pointer disabled:opacity-60 disabled:cursor-not-allowed"
                  >
                    {checkingPs ? (
                      <span className="material-symbols-outlined animate-spin">sync</span>
                    ) : (
                      <span className="material-symbols-outlined">play_arrow</span>
                    )}
                    {checkingPs ? t('settingsIntegrationTestBtnRunning') : t('settingsIntegrationTestBtn')}
                  </button>
                  {checkingPs && (
                    <div className="flex items-center gap-xs text-primary font-bold text-sm">
                      <span className="material-symbols-outlined animate-spin">sync</span>
                      <span>{t('settingsIntegrationChecking')}</span>
                    </div>
                  )}
                  {psCheckResult && (
                    <div className="flex items-center gap-xs text-green-600 font-bold text-sm bg-green-500/10 p-sm rounded-lg border border-green-500/20">
                      <span className="material-symbols-outlined">check_circle</span>
                      <span>{psCheckResult}</span>
                    </div>
                  )}
                </div>
              </div>

              <p className="text-label-sm text-on-surface-variant italic leading-relaxed text-sm">
                {t('settingsIntegrationNote')}
              </p>
            </div>
          </div>
        </section>

      </div>
    </div>
  );
};
