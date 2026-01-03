'use client';

import { motion } from 'framer-motion';
import { GraduationCap, Map, BookOpen, Gamepad2, Mic, Sparkles, Brain, Target } from 'lucide-react';
import type { LucideIcon } from 'lucide-react';

interface Feature {
  icon: LucideIcon;
  label: string;
  description: string;
}

const FEATURES: Feature[] = [
  {
    icon: GraduationCap,
    label: '17 Maestri AI',
    description: 'Esperti in ogni materia pronti ad aiutarti',
  },
  {
    icon: Map,
    label: 'Mappe Mentali',
    description: 'Visualizza e organizza i concetti',
  },
  {
    icon: BookOpen,
    label: 'Flashcard FSRS',
    description: 'Memorizza con la ripetizione spaziata',
  },
  {
    icon: Gamepad2,
    label: 'Gamification',
    description: 'Guadagna XP e sblocca traguardi',
  },
  {
    icon: Mic,
    label: 'Conversazione Vocale',
    description: 'Parla con i tuoi Maestri',
  },
  {
    icon: Sparkles,
    label: 'Quiz Interattivi',
    description: 'Metti alla prova le tue conoscenze',
  },
  {
    icon: Brain,
    label: 'Adattivo',
    description: 'Si adatta al tuo stile di apprendimento',
  },
  {
    icon: Target,
    label: 'Accessibile',
    description: 'Progettato per tutti',
  },
];

/**
 * Features Section for MirrorBuddy Welcome Page
 *
 * Displays key features in a responsive grid with
 * staggered animations for visual interest.
 *
 * Part of Wave 3: Welcome Experience Enhancement
 */
export function FeaturesSection() {
  return (
    <motion.section
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.5 }}
      className="w-full max-w-3xl mx-auto px-4 mb-10"
      aria-labelledby="features-heading"
    >
      <h2 id="features-heading" className="sr-only">
        Funzionalita di MirrorBuddy
      </h2>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        {FEATURES.map((feature, i) => {
          const Icon = feature.icon;
          return (
            <motion.div
              key={feature.label}
              initial={{ opacity: 0, scale: 0.9 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ delay: 0.6 + i * 0.05 }}
              className="group bg-white/80 dark:bg-gray-800/80 backdrop-blur-sm rounded-xl p-4 shadow-sm border border-gray-100 dark:border-gray-700 hover:shadow-md hover:border-pink-200 dark:hover:border-pink-800 transition-all"
            >
              <div className="w-10 h-10 rounded-lg bg-gradient-to-br from-pink-100 to-purple-100 dark:from-pink-900/30 dark:to-purple-900/30 flex items-center justify-center mb-3 group-hover:scale-110 transition-transform">
                <Icon className="w-5 h-5 text-pink-600 dark:text-pink-400" aria-hidden="true" />
              </div>
              <h3 className="text-sm font-semibold text-gray-800 dark:text-gray-200 mb-1">
                {feature.label}
              </h3>
              <p className="text-xs text-gray-500 dark:text-gray-400">
                {feature.description}
              </p>
            </motion.div>
          );
        })}
      </div>
    </motion.section>
  );
}
