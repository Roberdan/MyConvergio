'use client';

import { useState, useEffect, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Trophy,
  Flame,
  BookOpen,
  Star,
  Target,
  Compass,
  Zap,
  Lock,
  Check,
} from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { cn } from '@/lib/utils';
import type { Achievement } from '@/types';

interface AchievementsGridProps {
  achievements: Achievement[];
  className?: string;
}

// Icon mapping for achievement categories
const categoryIcons: Record<Achievement['category'], React.ReactNode> = {
  study: <BookOpen className="w-6 h-6" />,
  mastery: <Star className="w-6 h-6" />,
  streak: <Flame className="w-6 h-6" />,
  social: <Target className="w-6 h-6" />,
  exploration: <Compass className="w-6 h-6" />,
  xp: <Zap className="w-6 h-6" />,
};

const categoryColors: Record<Achievement['category'], string> = {
  study: 'from-blue-400 to-blue-600',
  mastery: 'from-amber-400 to-amber-600',
  streak: 'from-orange-400 to-red-500',
  social: 'from-pink-400 to-pink-600',
  exploration: 'from-cyan-400 to-cyan-600',
  xp: 'from-purple-400 to-purple-600',
};

export function AchievementsGrid({ achievements, className }: AchievementsGridProps) {
  const [selectedAchievement, setSelectedAchievement] = useState<Achievement | null>(null);

  // C-19 FIX: Handle Escape key to close modal
  const closeModal = useCallback(() => setSelectedAchievement(null), []);

  useEffect(() => {
    if (!selectedAchievement) return;
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        closeModal();
      }
    };
    window.addEventListener('keydown', handleEscape);
    return () => window.removeEventListener('keydown', handleEscape);
  }, [selectedAchievement, closeModal]);

  const unlockedCount = achievements.filter(a => a.unlockedAt).length;

  return (
    <Card className={className}>
      <CardHeader>
        <div className="flex items-center justify-between">
          <CardTitle className="flex items-center gap-2">
            <Trophy className="w-5 h-5 text-amber-500" />
            Trofei
          </CardTitle>
          <span className="text-sm text-slate-500">
            {unlockedCount}/{achievements.length} sbloccati
          </span>
        </div>
      </CardHeader>
      <CardContent>
        <div className="grid grid-cols-4 sm:grid-cols-5 md:grid-cols-6 gap-3">
          {achievements.map((achievement) => (
            <AchievementBadge
              key={achievement.id}
              achievement={achievement}
              onClick={() => setSelectedAchievement(achievement)}
            />
          ))}
        </div>

        {/* Achievement detail modal */}
        <AnimatePresence>
          {selectedAchievement && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
              onClick={() => setSelectedAchievement(null)}
            >
              <motion.div
                initial={{ scale: 0.9, opacity: 0 }}
                animate={{ scale: 1, opacity: 1 }}
                exit={{ scale: 0.9, opacity: 0 }}
                onClick={(e) => e.stopPropagation()}
                className="bg-white dark:bg-slate-900 rounded-2xl p-6 max-w-sm w-full shadow-xl"
              >
                <AchievementDetail achievement={selectedAchievement} />
              </motion.div>
            </motion.div>
          )}
        </AnimatePresence>
      </CardContent>
    </Card>
  );
}

interface AchievementBadgeProps {
  achievement: Achievement;
  onClick: () => void;
}

function AchievementBadge({ achievement, onClick }: AchievementBadgeProps) {
  const isUnlocked = !!achievement.unlockedAt;

  return (
    <motion.button
      onClick={onClick}
      className={cn(
        'relative w-14 h-14 rounded-xl flex items-center justify-center transition-all',
        isUnlocked
          ? `bg-gradient-to-br ${categoryColors[achievement.category]} text-white shadow-lg`
          : 'bg-slate-200 dark:bg-slate-700 text-slate-400'
      )}
      whileHover={{ scale: 1.1 }}
      whileTap={{ scale: 0.95 }}
    >
      {isUnlocked ? (
        categoryIcons[achievement.category]
      ) : (
        <Lock className="w-5 h-5" />
      )}

      {/* Unlocked indicator */}
      {isUnlocked && (
        <motion.div
          initial={{ scale: 0 }}
          animate={{ scale: 1 }}
          className="absolute -top-1 -right-1 w-5 h-5 bg-green-500 rounded-full flex items-center justify-center"
        >
          <Check className="w-3 h-3 text-white" />
        </motion.div>
      )}
    </motion.button>
  );
}

interface AchievementDetailProps {
  achievement: Achievement;
}

function AchievementDetail({ achievement }: AchievementDetailProps) {
  const isUnlocked = !!achievement.unlockedAt;

  return (
    <div className="text-center">
      {/* Badge */}
      <div
        className={cn(
          'w-20 h-20 mx-auto rounded-2xl flex items-center justify-center mb-4',
          isUnlocked
            ? `bg-gradient-to-br ${categoryColors[achievement.category]} text-white`
            : 'bg-slate-200 dark:bg-slate-700 text-slate-400'
        )}
      >
        {isUnlocked ? (
          categoryIcons[achievement.category]
        ) : (
          <Lock className="w-8 h-8" />
        )}
      </div>

      {/* Info */}
      <h3 className="text-xl font-bold mb-1">{achievement.name}</h3>
      <p className="text-slate-600 dark:text-slate-400 text-sm mb-4">
        {achievement.description}
      </p>

      {/* XP Reward */}
      <div className="flex items-center justify-center gap-2 mb-4">
        <Zap className="w-4 h-4 text-purple-500" />
        <span className="text-purple-600 font-medium">+{achievement.xpReward} XP</span>
      </div>

      {/* Status */}
      {isUnlocked ? (
        <div className="text-sm text-green-600 dark:text-green-400">
          Sbloccato il {new Date(achievement.unlockedAt!).toLocaleDateString('it-IT')}
        </div>
      ) : (
        <div className="text-sm text-slate-500">
          Completa l&apos;obiettivo per sbloccare
        </div>
      )}
    </div>
  );
}

// Predefined achievements for the app
export const defaultAchievements: Achievement[] = [
  // Study achievements
  { id: 'first_session', name: 'Prima Lezione', description: 'Completa la tua prima sessione di studio', icon: '📚', category: 'study', requirement: 1, xpReward: 50 },
  { id: 'study_10', name: 'Studente Attivo', description: 'Completa 10 sessioni di studio', icon: '📖', category: 'study', requirement: 10, xpReward: 100 },
  { id: 'study_50', name: 'Studente Dedicato', description: 'Completa 50 sessioni di studio', icon: '🎓', category: 'study', requirement: 50, xpReward: 250 },
  { id: 'study_100', name: 'Studioso', description: 'Completa 100 sessioni di studio', icon: '🏆', category: 'study', requirement: 100, xpReward: 500 },

  // Streak achievements
  { id: 'streak_3', name: 'Tre Giorni!', description: 'Mantieni una serie di 3 giorni', icon: '🔥', category: 'streak', requirement: 3, xpReward: 75 },
  { id: 'streak_7', name: 'Una Settimana!', description: 'Mantieni una serie di 7 giorni', icon: '🔥', category: 'streak', requirement: 7, xpReward: 150 },
  { id: 'streak_30', name: 'Un Mese!', description: 'Mantieni una serie di 30 giorni', icon: '🔥', category: 'streak', requirement: 30, xpReward: 500 },
  { id: 'streak_100', name: 'Leggenda!', description: 'Mantieni una serie di 100 giorni', icon: '🔥', category: 'streak', requirement: 100, xpReward: 1000 },

  // Mastery achievements
  { id: 'master_1', name: 'Primo Professore', description: 'Raggiungi la padronanza in una materia', icon: '⭐', category: 'mastery', requirement: 1, xpReward: 200 },
  { id: 'master_5', name: 'Multidisciplinare', description: 'Raggiungi la padronanza in 5 materie', icon: '⭐', category: 'mastery', requirement: 5, xpReward: 500 },
  { id: 'perfect_quiz', name: 'Perfezionista', description: 'Completa un quiz con il 100%', icon: '💯', category: 'mastery', requirement: 1, xpReward: 100 },

  // Exploration achievements
  { id: 'all_maestros', name: 'Collezionista', description: 'Studia con tutti i 17 professori', icon: '🧭', category: 'exploration', requirement: 17, xpReward: 300 },
  { id: 'curious', name: 'Curioso', description: 'Fai 50 domande ai professori', icon: '❓', category: 'exploration', requirement: 50, xpReward: 150 },

  // XP achievements
  { id: 'xp_1000', name: 'Mille Punti', description: 'Accumula 1000 XP', icon: '⚡', category: 'xp', requirement: 1000, xpReward: 100 },
  { id: 'xp_5000', name: 'Cinquemila', description: 'Accumula 5000 XP', icon: '⚡', category: 'xp', requirement: 5000, xpReward: 250 },
  { id: 'xp_10000', name: 'Diecimila!', description: 'Accumula 10000 XP', icon: '⚡', category: 'xp', requirement: 10000, xpReward: 500 },
];
