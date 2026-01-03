'use client';

import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { Trophy, Flame, Clock, BookOpen, Star } from 'lucide-react';
import { useProgressStore } from '@/lib/stores/app-store';
import { cn } from '@/lib/utils';
import { XP_PER_LEVEL } from '@/lib/constants/xp-rewards';

export function HomeProgressWidget() {
  const { xp, level, streak, totalStudyMinutes, sessionsThisWeek, questionsAsked, currentSession } = useProgressStore();
  const [liveMinutes, setLiveMinutes] = useState(0);

  // C-9 FIX: Track current session time in real-time
  useEffect(() => {
    // Early return if no session - don't update state to avoid lint warning
    if (!currentSession?.startedAt) return;

    const updateLiveTime = () => {
      const elapsed = Math.floor((Date.now() - new Date(currentSession.startedAt).getTime()) / 60000);
      setLiveMinutes(elapsed);
    };

    updateLiveTime(); // Initial update
    const interval = setInterval(updateLiveTime, 60000); // Update every minute
    return () => {
      clearInterval(interval);
      setLiveMinutes(0); // Reset on cleanup instead of in effect body
    };
  }, [currentSession?.startedAt]);

  // Calculate XP progress to next level
  const currentLevelXP = XP_PER_LEVEL[level - 1] || 0;
  const nextLevelXP = XP_PER_LEVEL[level] || XP_PER_LEVEL[XP_PER_LEVEL.length - 1];
  const xpInLevel = xp - currentLevelXP;
  const xpNeeded = nextLevelXP - currentLevelXP;
  const progressPercent = Math.min(100, (xpInLevel / xpNeeded) * 100);

  // Format study time - include current session if active
  const displayMinutes = totalStudyMinutes + liveMinutes;
  const hours = Math.floor(displayMinutes / 60);
  const minutes = displayMinutes % 60;
  const studyTimeStr = hours > 0 ? `${hours}h${minutes}m` : `${minutes}m`;
  const isSessionActive = !!currentSession;

  return (
    <div className="mb-6 p-3 rounded-xl bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 shadow-sm">
      <div className="flex items-center gap-4 flex-wrap">
        {/* Level + XP Progress */}
        <div className="flex items-center gap-2 min-w-[180px] flex-1">
          <div className="w-8 h-8 rounded-full bg-accent-themed flex items-center justify-center flex-shrink-0">
            <Trophy className="w-4 h-4 text-white" />
          </div>
          <div className="flex-1 min-w-0">
            <div className="flex items-baseline gap-2 text-sm">
              <span className="font-bold text-slate-900 dark:text-white">Lv.{level}</span>
              <span className="text-xs text-slate-500">{xpInLevel}/{xpNeeded} XP</span>
            </div>
            <div className="h-1.5 bg-slate-200 dark:bg-slate-700 rounded-full overflow-hidden mt-1">
              <motion.div
                className="h-full bg-accent-themed rounded-full"
                initial={{ width: 0 }}
                animate={{ width: `${progressPercent}%` }}
                transition={{ duration: 0.5 }}
              />
            </div>
          </div>
        </div>

        {/* Divider */}
        <div className="hidden md:block w-px h-8 bg-slate-200 dark:bg-slate-700" />

        {/* Quick Stats */}
        <div className="flex items-center gap-4 text-sm">
          <div className="flex items-center gap-1.5" title="Streak">
            <Flame className={cn("w-4 h-4", streak.current > 0 ? "text-orange-500" : "text-slate-400")} />
            <span className={cn("font-semibold", streak.current > 0 ? "text-orange-500" : "text-slate-500")}>
              {streak.current}
            </span>
          </div>

          <div className="flex items-center gap-1.5" title="Sessioni questa settimana">
            <BookOpen className="w-4 h-4 text-blue-500" />
            <span className="font-semibold text-slate-700 dark:text-slate-300">{sessionsThisWeek}</span>
          </div>

          <div className="flex items-center gap-1.5" title={isSessionActive ? "Sessione in corso" : "Tempo di studio"}>
            <Clock className={cn("w-4 h-4", isSessionActive ? "text-green-500 animate-pulse" : "text-green-500")} />
            <span className={cn("font-semibold", isSessionActive ? "text-green-600 dark:text-green-400" : "text-slate-700 dark:text-slate-300")}>
              {studyTimeStr}
            </span>
            {isSessionActive && (
              <span className="w-2 h-2 bg-green-500 rounded-full animate-pulse" title="Sessione attiva" />
            )}
          </div>

          <div className="flex items-center gap-1.5" title="Domande fatte">
            <Star className="w-4 h-4 text-purple-500" />
            <span className="font-semibold text-slate-700 dark:text-slate-300">{questionsAsked}</span>
          </div>
        </div>

        {/* Streak bonus badge - only if active */}
        {streak.current >= 3 && (
          <div className="flex items-center gap-1 px-2 py-1 rounded-full bg-orange-100 dark:bg-orange-900/30 text-orange-600 dark:text-orange-400 text-xs font-medium">
            <Flame className="w-3 h-3" />
            +{Math.min(streak.current * 10, 50)}% XP
          </div>
        )}
      </div>
    </div>
  );
}
