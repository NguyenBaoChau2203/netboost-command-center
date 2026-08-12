import { useState, useEffect } from 'react';
import { api } from './api/client';
import type { HealthResponse } from './api/types';
import { useTranslation } from './i18n/translations';

// Import Views
import { DashboardView } from './views/DashboardView';
import { DnsView } from './views/DnsView';
import { CleanupView } from './views/CleanupView';
import { NpmPnpmView } from './views/NpmPnpmView';
import { AutoTaskView } from './views/AutoTaskView';
import { SettingsView } from './views/SettingsView';

function App() {
  const [activeTab, setActiveTab] = useState<string>('dashboard');
  const [health, setHealth] = useState<HealthResponse | null>(null);
  const [lang, setLang] = useState<'vi' | 'en'>('vi');
  const [compact, setCompact] = useState(false);
  const [adminRequired, setAdminRequired] = useState(() => api.isAdminRequiredError());

  const t = useTranslation(lang);

  useEffect(() => {
    const refreshSettings = () => {
      api.getSettings().then(settings => {
        setLang(settings.language);
        setCompact(settings.compactMode);
      });
    };

    // Get initial health and load settings once
    api.getHealth().then(setHealth);
    refreshSettings();

    // Only react to session / admin-required changes; settings are local
    const unsubscribe = api.subscribe(() => {
      setAdminRequired(api.isAdminRequiredError());
      refreshSettings();
    });

    return () => {
      unsubscribe();
    };
  }, []);

  const handleRefresh = () => {
    // Simulate UI reloading
    window.location.reload();
  };

  const toggleLanguage = () => {
    const nextLang = lang === 'vi' ? 'en' : 'vi';
    setLang(nextLang);
    api.updateSettings({ language: nextLang });
  };

  const navItems = [
    { id: 'dashboard', label: t('navDashboard'), icon: 'dashboard' },
    { id: 'dns', label: t('navDns'), icon: 'dns' },
    { id: 'cleanup', label: t('navCleanup'), icon: 'cleaning_services' },
    { id: 'npm-pnpm', label: t('navNpmPnpm'), icon: 'swap_horiz' },
    { id: 'task', label: t('navAutoTask'), icon: 'auto_mode' },
    { id: 'settings', label: t('navSettings'), icon: 'settings' }
  ];

  return (
    <div className={`min-h-screen text-on-surface bg-background selection:bg-primary-container selection:text-on-primary-container ${compact ? 'text-sm' : ''}`}>

      {/* 1. Desktop SideNavBar - Fixed Left */}
      <aside className="fixed left-0 top-0 h-full w-[260px] bg-surface-container-low dark:bg-surface-container-lowest border-r border-outline-variant shadow-md flex flex-col py-lg z-50 transition-all duration-300 hidden md:flex text-left">
        <div className="px-lg mb-xl">
          <div className="flex items-center gap-sm mb-xs">
            <span className="material-symbols-outlined text-primary dark:text-primary-fixed-dim text-[32px] select-none">speed</span>
            <h1 className="font-headline-sm text-headline-sm font-bold text-on-surface dark:text-on-surface leading-none">NetBoost</h1>
          </div>
          <p className="font-label-md text-label-md text-on-surface-variant opacity-60">Command Center {health?.version || 'v1.0.1'}</p>
        </div>

        <nav className="flex-1 px-sm space-y-1">
          {navItems.map(item => {
            const isActive = activeTab === item.id;
            return (
              <button
                key={item.id}
                onClick={() => setActiveTab(item.id)}
                className={`w-full flex items-center gap-md px-md py-sm rounded-lg font-label-md text-label-md transition-all cursor-pointer text-left active:scale-[0.98] ${
                  isActive
                    ? 'text-primary dark:text-primary-fixed-dim border-l-4 border-primary dark:border-primary-fixed-dim bg-primary/10 dark:bg-primary-fixed-dim/15 font-bold'
                    : 'text-on-surface-variant hover:text-on-surface hover:bg-surface-variant/30 font-medium'
                }`}
              >
                <span className="material-symbols-outlined select-none">{item.icon}</span>
                <span>{item.label}</span>
              </button>
            );
          })}
        </nav>

        <div className="px-md mt-auto pt-lg border-t border-outline-variant/10 text-center">
          <p className="text-[11px] text-on-surface-variant opacity-40 font-mono">Bind only: 127.0.0.1</p>
        </div>
      </aside>

      {/* 2. TopAppBar */}
      <header className="fixed top-0 right-0 left-0 md:ml-[260px] h-16 bg-surface dark:bg-background border-b border-outline-variant shadow-sm flex justify-between items-center px-lg z-40 transition-all">
        <div className="flex items-center gap-md">
          {/* Logo only visible on mobile top */}
          <div className="flex items-center gap-xs md:hidden select-none mr-sm">
            <span className="material-symbols-outlined text-primary text-[28px]">speed</span>
            <span className="font-bold text-on-surface font-headline-sm text-[18px]">NetBoost</span>
          </div>

          <span className="font-title-lg text-title-lg text-primary font-bold hidden sm:inline-block">{t('localPortal')}</span>
          <span className="px-sm py-xs bg-secondary-container text-on-secondary-container rounded-lg font-label-sm text-label-sm flex items-center gap-xs select-none">
            <span className="material-symbols-outlined text-[14px]" style={{ fontVariationSettings: "'FILL' 1" }}>verified_user</span>
            {t('adminLocal')}
          </span>
        </div>

        <div className="flex items-center gap-lg select-none">
          {/* Language selection toggler */}
          <div
            onClick={toggleLanguage}
            className="flex items-center gap-sm text-on-surface-variant font-label-md text-label-md cursor-pointer hover:bg-surface-container-high px-sm py-xs rounded-lg transition-all"
          >
            <span className={lang === 'en' ? 'text-primary font-bold' : ''}>EN</span>
            <span className="w-[1px] h-4 bg-outline-variant"></span>
            <span className={lang === 'vi' ? 'text-primary font-bold' : ''}>VI</span>
          </div>

          {/* Refresh Action */}
          <button
            onClick={handleRefresh}
            className="p-sm text-on-surface-variant hover:bg-surface-container-high rounded-full transition-all cursor-pointer active:opacity-85"
            title={t('refreshUi')}
          >
            <span className="material-symbols-outlined">refresh</span>
          </button>
        </div>
      </header>

      {/* 3. Main Workspace Container */}
      <main className="md:ml-[260px] mt-16 p-lg pb-[100px] md:pb-lg space-y-lg min-h-screen">
        <div className="max-w-7xl mx-auto">
          {activeTab === 'dashboard' && <DashboardView lang={lang} onNavigate={setActiveTab} setActiveLogSource={() => {}} />}
          {activeTab === 'dns' && <DnsView lang={lang} />}
          {activeTab === 'cleanup' && <CleanupView lang={lang} />}
          {activeTab === 'npm-pnpm' && <NpmPnpmView lang={lang} />}
          {activeTab === 'task' && <AutoTaskView lang={lang} />}
          {activeTab === 'settings' && <SettingsView lang={lang} onLangChange={setLang} />}
        </div>
      </main>

      {/* 4. Mobile Bottom Nav - Sticky Bottom */}
      <nav className="fixed bottom-0 left-0 right-0 bg-surface dark:bg-inverse-surface border-t border-outline-variant shadow-lg flex justify-around items-center h-16 md:hidden z-50">
        {navItems.map(item => {
          const isActive = activeTab === item.id;
          return (
            <button
              key={item.id}
              onClick={() => setActiveTab(item.id)}
              className={`flex flex-col items-center justify-center flex-1 h-full py-sm font-label-sm text-[10px] transition-all cursor-pointer ${
                isActive
                  ? 'text-primary font-bold'
                  : 'text-on-surface-variant font-medium'
              }`}
            >
              <span className="material-symbols-outlined text-[20px] select-none mb-0.5">{item.icon}</span>
              <span className="truncate max-w-[60px]">{item.label}</span>
            </button>
          );
        })}
      </nav>

      {/* Elegant visual backdrop accent */}
      <div className="fixed bottom-0 right-0 p-lg pointer-events-none opacity-5 hidden lg:block select-none z-0">
        <span className="material-symbols-outlined text-[300px] text-primary" style={{ fontVariationSettings: "'wght' 100" }}>speed</span>
      </div>

      {/* Admin Required Glassmorphic Modal Alert */}
      {adminRequired && (
        <div className="fixed inset-0 bg-black/75 backdrop-blur-md z-[9999] flex items-center justify-center p-md">
          <div className="bg-surface-container-lowest max-w-lg w-full rounded-2xl border-2 border-error/30 shadow-2xl p-xl space-y-lg text-left animate-in fade-in zoom-in-95 duration-200">
            <div className="flex items-center gap-md text-error">
              <span className="material-symbols-outlined text-[44px]" style={{ fontVariationSettings: "'FILL' 1" }}>gpp_bad</span>
              <div>
                <h3 className="font-headline-sm text-headline-sm font-bold text-on-surface">{t('adminRequiredTitle')}</h3>
                <p className="text-label-md text-error font-semibold mt-xs">{t('adminRequiredSubtitle')}</p>
              </div>
            </div>

            <div className="space-y-md text-body-md text-on-surface-variant leading-relaxed">
              <p>
                {t('adminRequiredBody')}
              </p>
              <div className="bg-error-container/20 p-md rounded-xl border border-error/20 font-medium text-on-error-container text-sm">
                {t('adminRequiredAction')}
              </div>
              <p className="text-xs italic text-on-surface-variant/70 border-t border-outline-variant/30 pt-md">
                {t('adminRequiredPolicy')}
              </p>
            </div>

            <div className="flex justify-end gap-sm pt-xs">
              <button
                onClick={() => api.clearAdminRequiredError()}
                className="px-xl py-md bg-outline-variant/20 hover:bg-outline-variant/30 text-on-surface rounded-xl font-label-md text-label-md font-bold cursor-pointer active:scale-95 transition-all"
              >
                {t('adminRequiredClose')}
              </button>
            </div>
          </div>
        </div>
      )}

    </div>
  );
}

export default App;
