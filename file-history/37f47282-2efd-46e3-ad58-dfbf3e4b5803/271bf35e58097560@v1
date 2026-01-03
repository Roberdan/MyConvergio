'use client';

import { motion } from 'framer-motion';
import { ArrowRight, Settings, Mic, MousePointer, SkipForward } from 'lucide-react';
import { Button } from '@/components/ui/button';

interface QuickStartProps {
  isReturningUser: boolean;
  onStartWithVoice: () => void;
  onStartWithoutVoice: () => void;
  onSkip: () => void;
  onUpdateProfile?: () => void;
}

/**
 * Quick Start Section for MirrorBuddy Welcome Page
 *
 * Provides clear CTAs for:
 * - Start with voice (recommended)
 * - Start without voice
 * - Skip to dashboard
 * - Update profile (returning users)
 *
 * Part of Wave 3: Welcome Experience Enhancement
 */
export function QuickStart({
  isReturningUser,
  onStartWithVoice,
  onStartWithoutVoice,
  onSkip,
  onUpdateProfile,
}: QuickStartProps) {
  return (
    <motion.section
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.9 }}
      className="w-full max-w-md mx-auto px-4"
      aria-labelledby="quickstart-heading"
    >
      <h2 id="quickstart-heading" className="sr-only">
        Inizia
      </h2>

      {isReturningUser ? (
        <div className="flex flex-col items-center gap-4">
          {/* Primary: Go to app */}
          <Button
            size="lg"
            onClick={onSkip}
            className="w-full sm:w-auto bg-gradient-to-r from-pink-500 to-purple-600 hover:from-pink-600 hover:to-purple-700 text-white px-8 py-6 text-lg rounded-xl shadow-lg shadow-purple-500/25 hover:shadow-xl hover:shadow-purple-500/30 transition-all"
          >
            Vai all&apos;app
            <ArrowRight className="w-5 h-5 ml-2" aria-hidden="true" />
          </Button>

          {/* Secondary: Update profile */}
          {onUpdateProfile && (
            <Button
              size="lg"
              variant="outline"
              onClick={onUpdateProfile}
              className="w-full sm:w-auto px-8 py-6 text-lg rounded-xl border-2"
            >
              <Settings className="w-5 h-5 mr-2" aria-hidden="true" />
              Aggiorna profilo
            </Button>
          )}
        </div>
      ) : (
        <div className="flex flex-col items-center gap-4">
          {/* Primary: Start with voice */}
          <Button
            size="lg"
            onClick={onStartWithVoice}
            className="w-full sm:w-auto bg-gradient-to-r from-pink-500 to-purple-600 hover:from-pink-600 hover:to-purple-700 text-white px-8 py-6 text-lg rounded-xl shadow-lg shadow-purple-500/25 hover:shadow-xl hover:shadow-purple-500/30 transition-all"
          >
            <Mic className="w-5 h-5 mr-2" aria-hidden="true" />
            Inizia con Melissa
            <ArrowRight className="w-5 h-5 ml-2" aria-hidden="true" />
          </Button>

          {/* Secondary: Start without voice */}
          <Button
            size="lg"
            variant="outline"
            onClick={onStartWithoutVoice}
            className="w-full sm:w-auto px-8 py-6 text-lg rounded-xl border-2 border-gray-200 dark:border-gray-700"
          >
            <MousePointer className="w-5 h-5 mr-2" aria-hidden="true" />
            Continua senza voce
          </Button>

          {/* Skip link */}
          <button
            onClick={onSkip}
            className="flex items-center gap-1 text-sm text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200 transition-colors underline-offset-2 hover:underline mt-2"
          >
            <SkipForward className="w-4 h-4" aria-hidden="true" />
            Salta intro e inizia subito
          </button>
        </div>
      )}

      {/* Voice indicator for new users */}
      {!isReturningUser && (
        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 1.1 }}
          className="mt-6 text-center text-sm text-gray-500 dark:text-gray-400"
        >
          Puoi sempre tornare a vedere l&apos;introduzione dalle Impostazioni
        </motion.p>
      )}
    </motion.section>
  );
}
