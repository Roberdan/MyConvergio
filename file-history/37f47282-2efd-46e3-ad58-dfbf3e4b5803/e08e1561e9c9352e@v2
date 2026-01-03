'use client';

import { motion } from 'framer-motion';
import Image from 'next/image';
import { Sparkles } from 'lucide-react';

interface HeroSectionProps {
  userName?: string;
  isReturningUser: boolean;
}

/**
 * Hero Section for MirrorBuddy Welcome Page
 *
 * Displays:
 * - Animated Melissa avatar with sparkle decoration
 * - Personalized welcome message (new vs returning user)
 * - MirrorBuddy branding and value proposition
 *
 * Part of Wave 3: Welcome Experience Enhancement
 */
export function HeroSection({ userName, isReturningUser }: HeroSectionProps) {
  return (
    <div className="text-center max-w-2xl mx-auto">
      {/* Avatar with animation */}
      <motion.div
        initial={{ scale: 0.8, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        transition={{ delay: 0.2, duration: 0.5, type: 'spring' }}
        className="relative w-32 h-32 mx-auto mb-8"
      >
        <div className="absolute inset-0 bg-gradient-to-br from-pink-300/20 to-transparent rounded-full blur-xl opacity-50" />
        <div className="relative w-full h-full rounded-full bg-gradient-to-br from-pink-400 to-purple-600 p-1">
          <div className="w-full h-full rounded-full bg-white dark:bg-gray-900 flex items-center justify-center overflow-hidden">
            <Image
              src="/avatars/melissa.jpg"
              alt="Melissa - La tua coach di apprendimento"
              width={120}
              height={120}
              className="w-full h-full object-cover"
              priority
            />
          </div>
        </div>
        {/* Sparkle decoration */}
        <motion.div
          animate={{ rotate: 360 }}
          transition={{ duration: 20, repeat: Infinity, ease: 'linear' }}
          className="absolute -top-2 -right-2"
        >
          <Sparkles className="w-6 h-6 text-yellow-400" aria-hidden="true" />
        </motion.div>
      </motion.div>

      {/* Welcome Text */}
      <div aria-live="polite" aria-atomic="true">
        {isReturningUser ? (
          <>
            <motion.h1
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.3 }}
              className="text-4xl md:text-5xl font-bold text-gray-900 dark:text-white mb-4"
            >
              Bentornato,{' '}
              <span className="bg-gradient-to-r from-pink-500 to-purple-600 bg-clip-text text-transparent">
                {userName}!
              </span>
            </motion.h1>
            <motion.p
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.4 }}
              className="text-xl text-gray-600 dark:text-gray-300 mb-8"
            >
              E bello rivederti. Vuoi aggiornare il tuo profilo o continuare a studiare?
            </motion.p>
          </>
        ) : (
          <>
            <motion.h1
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.3 }}
              className="text-4xl md:text-5xl font-bold text-gray-900 dark:text-white mb-4"
            >
              Benvenuto in{' '}
              <span className="bg-gradient-to-r from-pink-500 to-purple-600 bg-clip-text text-transparent">
                MirrorBuddy
              </span>
            </motion.h1>
            <motion.p
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.4 }}
              className="text-xl text-gray-600 dark:text-gray-300 mb-8"
            >
              Il tuo compagno di studio intelligente, personalizzato per te.
              Impara con i nostri Maestri AI, crea mappe mentali, flashcard e molto altro!
            </motion.p>
          </>
        )}
      </div>
    </div>
  );
}
