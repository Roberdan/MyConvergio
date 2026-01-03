'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { motion } from 'framer-motion';
import { useOnboardingStore } from '@/lib/stores/onboarding-store';
import {
  GraduationCap,
  BookOpen,
  Brain,
  Trophy,
  Settings,
  PanelLeftClose,
  PanelLeftOpen,
  Target,
  Flame,
  Network,
  Calendar,
  Heart,
  Sparkles,
  Clock,
  Star,
  Users,
  FileText,
  Upload,
  Archive,
} from 'lucide-react';
import Image from 'next/image';
import { MaestriGrid } from '@/components/maestros/maestri-grid';
import { MaestroSession } from '@/components/maestros/maestro-session';
import type { Maestro } from '@/types';
import { NotificationBell } from '@/components/notifications/notification-bell';
import { PomodoroHeaderWidget } from '@/components/pomodoro';
import { AmbientAudioHeaderWidget } from '@/components/ambient-audio';
import {
  LazyQuizView,
  LazyFlashcardsView,
  LazyMindmapsView,
  LazySummariesView,
  LazyHomeworkHelpView,
  LazyCalendarView,
  LazyHTMLSnippetsView,
} from '@/components/education';
import { CharacterChatView } from '@/components/conversation';
import { LazySettingsView } from '@/components/settings';
import { LazyProgressView } from '@/components/progress';
import { Button } from '@/components/ui/button';
import { useProgressStore, useSettingsStore, useUIStore } from '@/lib/stores/app-store';
import { useConversationFlowStore } from '@/lib/stores/conversation-flow-store';
import { FocusToolLayout } from '@/components/tools/focus-tool-layout';
import { useParentInsightsIndicator } from '@/lib/hooks/use-parent-insights-indicator';
import { cn } from '@/lib/utils';
import { XP_PER_LEVEL } from '@/lib/constants/xp-rewards';

type View = 'coach' | 'buddy' | 'maestri' | 'maestro-session' | 'quiz' | 'flashcards' | 'mindmaps' | 'summaries' | 'homework' | 'studykit' | 'supporti' | 'calendar' | 'demos' | 'progress' | 'genitori' | 'settings';
type MaestroSessionMode = 'voice' | 'chat';

// Character info for sidebar display
const COACH_INFO = {
  melissa: { name: 'Melissa', avatar: '/avatars/melissa.jpg' },
  roberto: { name: 'Roberto', avatar: '/avatars/roberto.png' },
  chiara: { name: 'Chiara', avatar: '/avatars/chiara.png' },
  andrea: { name: 'Andrea', avatar: '/avatars/andrea.png' },
  favij: { name: 'Favij', avatar: '/avatars/favij.jpg' },
} as const;

const BUDDY_INFO = {
  mario: { name: 'Mario', avatar: '/avatars/mario.jpg' },
  noemi: { name: 'Noemi', avatar: '/avatars/noemi.png' },
  enea: { name: 'Enea', avatar: '/avatars/enea.png' },
  bruno: { name: 'Bruno', avatar: '/avatars/bruno.png' },
  sofia: { name: 'Sofia', avatar: '/avatars/sofia.png' },
} as const;

export default function Home() {
  const router = useRouter();
  const { hasCompletedOnboarding, isHydrated, hydrateFromApi } = useOnboardingStore();

  // Hydrate onboarding state from DB on mount
  useEffect(() => {
    hydrateFromApi();
  }, [hydrateFromApi]);

  // Redirect to welcome if onboarding not completed (only after hydration)
  useEffect(() => {
    if (isHydrated && !hasCompletedOnboarding) {
      router.push('/welcome');
    }
  }, [isHydrated, hasCompletedOnboarding, router]);

  // Start with Maestri as the first view
  const [currentView, setCurrentView] = useState<View>('maestri');
  const [sidebarOpen, setSidebarOpen] = useState(true);

  // Maestro session state
  const [selectedMaestro, setSelectedMaestro] = useState<Maestro | null>(null);
  const [maestroSessionMode, setMaestroSessionMode] = useState<MaestroSessionMode>('voice');
  const [maestroSessionKey, setMaestroSessionKey] = useState(0);

  const { xp, level, streak, totalStudyMinutes, sessionsThisWeek, questionsAsked } = useProgressStore();
  const { studentProfile } = useSettingsStore();
  const { hasNewInsights, markAsViewed } = useParentInsightsIndicator();
  const { focusMode } = useUIStore();
  const {
    activeCharacter,
    conversationsByCharacter,
    endConversationWithSummary,
    isActive: isConversationActive
  } = useConversationFlowStore();

  // Handler to close active conversation before navigating to a different view
  const handleViewChange = async (newView: View) => {
    // If there's an active conversation, close it first
    if (isConversationActive && activeCharacter) {
      const characterConvo = conversationsByCharacter[activeCharacter.id];
      if (characterConvo?.conversationId) {
        const userId = sessionStorage.getItem('mirrorbuddy-user-id');
        if (userId) {
          try {
            await endConversationWithSummary(characterConvo.conversationId, userId);
          } catch (error) {
            console.error('Failed to close conversation:', error);
          }
        }
      }
    }
    setCurrentView(newView);
  };

  // Don't render main app until hydration is done and onboarding is completed
  if (!isHydrated || !hasCompletedOnboarding) {
    return null;
  }

  // XP calculations (using centralized constants)
  const currentLevelXP = XP_PER_LEVEL[level - 1] || 0;
  const nextLevelXP = XP_PER_LEVEL[level] || XP_PER_LEVEL[XP_PER_LEVEL.length - 1];
  const xpInLevel = xp - currentLevelXP;
  const xpNeeded = nextLevelXP - currentLevelXP;
  const progressPercent = Math.min(100, (xpInLevel / xpNeeded) * 100);

  // Format study time
  const hours = Math.floor(totalStudyMinutes / 60);
  const minutes = totalStudyMinutes % 60;
  const studyTimeStr = hours > 0 ? `${hours}h${minutes}m` : `${minutes}m`;

  // Get selected coach and buddy from preferences (with defaults)
  const selectedCoach = studentProfile?.preferredCoach || 'melissa';
  const selectedBuddy = studentProfile?.preferredBuddy || 'mario';
  const coachInfo = COACH_INFO[selectedCoach];
  const buddyInfo = BUDDY_INFO[selectedBuddy];

  const navItems = [
    { id: 'coach' as const, label: coachInfo.name, icon: Sparkles, isChat: true, avatar: coachInfo.avatar },
    { id: 'buddy' as const, label: buddyInfo.name, icon: Heart, isChat: true, avatar: buddyInfo.avatar },
    { id: 'maestri' as const, label: 'Professori', icon: GraduationCap },
    { id: 'quiz' as const, label: 'Quiz', icon: Brain },
    { id: 'flashcards' as const, label: 'Flashcards', icon: BookOpen },
    { id: 'mindmaps' as const, label: 'Mappe Mentali', icon: Network },
    { id: 'summaries' as const, label: 'Riassunti', icon: FileText },
    { id: 'homework' as const, label: 'Materiali', icon: Target },
    { id: 'studykit' as const, label: 'Study Kit', icon: Upload },
    { id: 'supporti' as const, label: 'Supporti', icon: Archive },
    { id: 'calendar' as const, label: 'Calendario', icon: Calendar },
    { id: 'demos' as const, label: 'Demo', icon: Brain },
    { id: 'progress' as const, label: 'Progressi', icon: Trophy },
    { id: 'genitori' as const, label: 'Genitori', icon: Users },
    { id: 'settings' as const, label: 'Impostazioni', icon: Settings },
  ];

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-900 dark:to-slate-950">
      {/* Unified Header Bar */}
      <header
        className={cn(
          'fixed top-0 right-0 h-14 z-50 flex items-center justify-between px-4 bg-white/80 dark:bg-slate-900/80 backdrop-blur-md border-b border-slate-200/50 dark:border-slate-700/50 transition-all duration-300',
          sidebarOpen ? 'left-64' : 'left-20'
        )}
      >
        {/* Level + XP Progress */}
        <div className="flex items-center gap-3 min-w-[200px]">
          <div className="w-8 h-8 rounded-full bg-accent-themed flex items-center justify-center flex-shrink-0">
            <Trophy className="w-4 h-4 text-white" />
          </div>
          <div className="flex-1 min-w-0">
            <div className="flex items-baseline gap-2 text-sm">
              <span className="font-bold text-slate-900 dark:text-white">Lv.{level}</span>
              <span className="text-xs text-slate-500">{xpInLevel}/{xpNeeded} XP</span>
            </div>
            <div className="h-1.5 bg-slate-200 dark:bg-slate-700 rounded-full overflow-hidden mt-0.5 w-32">
              <motion.div
                className="h-full bg-accent-themed rounded-full"
                initial={{ width: 0 }}
                animate={{ width: `${progressPercent}%` }}
                transition={{ duration: 0.5 }}
              />
            </div>
          </div>
        </div>

        {/* Quick Stats */}
        <div className="flex items-center gap-4 text-sm">
          <div className="flex items-center gap-1.5" title="Streak">
            <Flame className={cn("w-4 h-4", streak.current > 0 ? "text-orange-500" : "text-slate-400")} />
            <span className={cn("font-semibold", streak.current > 0 ? "text-orange-500" : "text-slate-500")}>
              {streak.current}
            </span>
          </div>

          <div className="flex items-center gap-1.5" title="Sessioni questa settimana">
            <BookOpen className="w-4 h-4 text-accent-themed" />
            <span className="font-semibold text-slate-700 dark:text-slate-300">{sessionsThisWeek}</span>
          </div>

          <div className="flex items-center gap-1.5" title="Tempo di studio">
            <Clock className="w-4 h-4 text-green-500" />
            <span className="font-semibold text-slate-700 dark:text-slate-300">{studyTimeStr}</span>
          </div>

          <div className="flex items-center gap-1.5" title="Domande fatte">
            <Star className="w-4 h-4 text-purple-500" />
            <span className="font-semibold text-slate-700 dark:text-slate-300">{questionsAsked}</span>
          </div>

          {/* Streak bonus badge */}
          {streak.current >= 3 && (
            <div className="flex items-center gap-1 px-2 py-0.5 rounded-full bg-orange-100 dark:bg-orange-900/30 text-orange-600 dark:text-orange-400 text-xs font-medium">
              <Flame className="w-3 h-3" />
              +{Math.min(streak.current * 10, 50)}% XP
            </div>
          )}
        </div>

        {/* Right section: ambient audio + pomodoro + notifications + version */}
        <div className="flex items-center gap-3">
          <AmbientAudioHeaderWidget />
          <PomodoroHeaderWidget />
          <NotificationBell />
          <span className="text-xs text-slate-400 dark:text-slate-500 font-mono">
            v{process.env.APP_VERSION}
          </span>
        </div>
      </header>

      {/* Sidebar */}
      <aside
        className={cn(
          'fixed top-0 left-0 h-full bg-white dark:bg-slate-900 border-r border-slate-200 dark:border-slate-800 z-40 transition-all duration-300',
          sidebarOpen ? 'w-64' : 'w-20'
        )}
      >
        {/* Logo - clickable to return home */}
        <div className="h-14 flex items-center justify-between px-4 border-b border-slate-200 dark:border-slate-800">
          <button
            onClick={() => setCurrentView('maestri')}
            className="flex items-center gap-3 hover:opacity-80 transition-opacity"
            aria-label="Torna alla home"
          >
            <div className="w-9 h-9 rounded-xl overflow-hidden flex-shrink-0">
              <Image
                src="/logo-brain.png"
                alt="MirrorBuddy"
                width={36}
                height={36}
                className="w-full h-full object-cover"
              />
            </div>
            {sidebarOpen && (
              <span className="font-bold text-lg text-slate-900 dark:text-white">
                MirrorBuddy
              </span>
            )}
          </button>
          <Button
            variant="ghost"
            size="icon-sm"
            onClick={() => setSidebarOpen(!sidebarOpen)}
            className="text-slate-500"
            aria-label={sidebarOpen ? 'Chiudi menu' : 'Apri menu'}
          >
            {sidebarOpen ? <PanelLeftClose className="h-4 w-4" /> : <PanelLeftOpen className="h-4 w-4" />}
          </Button>
        </div>

        {/* Navigation - with bottom padding for XP bar */}
        <nav className="p-4 space-y-2 overflow-y-auto pb-24" style={{ maxHeight: 'calc(100vh - 120px)' }}>
          {navItems.map((item) => {
            const isChatItem = item.id === 'coach' || item.id === 'buddy';
            const avatarSrc = 'avatar' in item ? item.avatar : null;

            return (
              <button
                key={item.id}
                onClick={async () => {
                  if (item.id === 'genitori') {
                    markAsViewed();
                    // Close active conversation before navigating away
                    await handleViewChange('genitori');
                    router.push('/parent-dashboard');
                  } else if (item.id === 'studykit') {
                    await handleViewChange('studykit');
                    router.push('/study-kit');
                  } else if (item.id === 'supporti') {
                    await handleViewChange('supporti');
                    router.push('/supporti');
                  } else {
                    await handleViewChange(item.id);
                  }
                }}
                className={cn(
                  'w-full flex items-center gap-3 px-4 py-3 rounded-xl transition-all',
                  currentView === item.id
                    ? 'bg-accent-themed text-white shadow-lg'
                    : 'text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800',
                  isChatItem && 'relative'
                )}
                style={currentView === item.id ? { boxShadow: '0 10px 15px -3px var(--accent-color, #3b82f6)40' } : undefined}
              >
                {avatarSrc ? (
                  <div className="relative flex-shrink-0">
                    <Image
                      src={avatarSrc}
                      alt={item.label}
                      width={32}
                      height={32}
                      className="w-8 h-8 rounded-full object-cover"
                    />
                    <span className="absolute bottom-0 right-0 w-2.5 h-2.5 bg-green-400 border-2 border-white dark:border-slate-900 rounded-full" />
                  </div>
                ) : (
                  <div className="relative flex-shrink-0">
                    <item.icon className="h-5 w-5" />
                    {item.id === 'genitori' && hasNewInsights && (
                      <span className="absolute -top-1 -right-1 w-2.5 h-2.5 bg-red-500 rounded-full animate-pulse" />
                    )}
                  </div>
                )}
                {sidebarOpen && <span className="font-medium">{item.label}</span>}
              </button>
            );
          })}
        </nav>

        {/* XP Progress */}
        {sidebarOpen && (
          <div className="absolute bottom-0 left-0 right-0 p-4 border-t border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900">
            <div className="mb-2 flex justify-between text-sm">
              <span className="text-slate-600 dark:text-slate-400">XP</span>
              <span className="font-medium text-slate-900 dark:text-white">
                {xp.toLocaleString()}
              </span>
            </div>
            <div className="h-2 rounded-full bg-slate-200 dark:bg-slate-700 overflow-hidden">
              <motion.div
                className="h-full bg-accent-themed"
                initial={{ width: 0 }}
                animate={{ width: `${(xp % 1000) / 10}%` }}
              />
            </div>
          </div>
        )}
      </aside>

      {/* Main content */}
      <main
        className={cn(
          'min-h-screen transition-all duration-300 p-8 pt-20',
          sidebarOpen ? 'ml-64' : 'ml-20'
        )}
      >

        {/* View content */}
        <motion.div
          key={currentView}
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.3 }}
        >
          {currentView === 'coach' && (
            <CharacterChatView characterId={selectedCoach} characterType="coach" />
          )}

          {currentView === 'buddy' && (
            <CharacterChatView characterId={selectedBuddy} characterType="buddy" />
          )}

          {currentView === 'maestri' && (
            <MaestriGrid
              onMaestroSelect={(maestro, mode) => {
                setSelectedMaestro(maestro);
                setMaestroSessionMode(mode);
                setMaestroSessionKey(prev => prev + 1);
                setCurrentView('maestro-session');
              }}
            />
          )}

          {currentView === 'maestro-session' && selectedMaestro && (
            <MaestroSession
              key={`maestro-${selectedMaestro.id}-${maestroSessionKey}`}
              maestro={selectedMaestro}
              onClose={() => setCurrentView('maestri')}
              initialMode={maestroSessionMode}
            />
          )}

          {currentView === 'quiz' && <LazyQuizView />}

          {currentView === 'flashcards' && <LazyFlashcardsView />}

          {currentView === 'mindmaps' && <LazyMindmapsView />}

          {currentView === 'summaries' && <LazySummariesView />}

          {currentView === 'homework' && <LazyHomeworkHelpView />}

          {/* Supporti view is at /supporti route */}

          {currentView === 'calendar' && <LazyCalendarView />}

          {currentView === 'demos' && <LazyHTMLSnippetsView />}

          {currentView === 'progress' && <LazyProgressView />}

          {currentView === 'settings' && <LazySettingsView />}
        </motion.div>
      </main>

      {/* Focus Mode Overlay - renders above everything when active */}
      {focusMode && <FocusToolLayout />}
    </div>
  );
}
