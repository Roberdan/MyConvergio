'use client';

import { motion } from 'framer-motion';
import Image from 'next/image';

interface Guide {
  id: string;
  name: string;
  role: string;
  description: string;
  avatar: string;
  color: string;
}

const GUIDES: Guide[] = [
  {
    id: 'melissa',
    name: 'Melissa',
    role: 'Learning Coach',
    description: 'Ti guida nel tuo percorso di apprendimento',
    avatar: '/avatars/melissa.jpg',
    color: 'from-pink-400 to-rose-500',
  },
  {
    id: 'andrea',
    name: 'Andrea',
    role: 'Buddy',
    description: 'Il tuo compagno di studio e supporto emotivo',
    avatar: '/avatars/andrea-buddy.jpg',
    color: 'from-blue-400 to-cyan-500',
  },
  {
    id: 'marco',
    name: 'Marco',
    role: 'Maestro di Matematica',
    description: 'Esperto di numeri, algebra e geometria',
    avatar: '/avatars/marco.jpg',
    color: 'from-indigo-400 to-blue-500',
  },
  {
    id: 'giulia',
    name: 'Giulia',
    role: 'Maestra di Italiano',
    description: 'Appassionata di letteratura e scrittura',
    avatar: '/avatars/giulia.jpg',
    color: 'from-amber-400 to-orange-500',
  },
];

/**
 * Guides Section for MirrorBuddy Welcome Page
 *
 * Introduces the AI characters:
 * - Coaches (learning support)
 * - Buddies (emotional support)
 * - Maestri (subject experts)
 *
 * Part of Wave 3: Welcome Experience Enhancement
 */
export function GuidesSection() {
  return (
    <motion.section
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.7 }}
      className="w-full max-w-3xl mx-auto px-4 mb-10"
      aria-labelledby="guides-heading"
    >
      <h2
        id="guides-heading"
        className="text-xl font-bold text-center text-gray-800 dark:text-gray-200 mb-6"
      >
        Incontra le tue Guide
      </h2>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        {GUIDES.map((guide, i) => (
          <motion.div
            key={guide.id}
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.8 + i * 0.1 }}
            className="bg-white/80 dark:bg-gray-800/80 backdrop-blur-sm rounded-xl p-4 text-center shadow-sm border border-gray-100 dark:border-gray-700 hover:shadow-md transition-shadow"
          >
            {/* Avatar */}
            <div className={`w-16 h-16 mx-auto mb-3 rounded-full bg-gradient-to-br ${guide.color} p-0.5`}>
              <div className="w-full h-full rounded-full bg-white dark:bg-gray-900 overflow-hidden">
                <Image
                  src={guide.avatar}
                  alt={`${guide.name} - ${guide.role}`}
                  width={64}
                  height={64}
                  className="w-full h-full object-cover"
                />
              </div>
            </div>

            {/* Info */}
            <h3 className="font-semibold text-gray-800 dark:text-gray-200">
              {guide.name}
            </h3>
            <p className="text-xs text-pink-600 dark:text-pink-400 font-medium mb-1">
              {guide.role}
            </p>
            <p className="text-xs text-gray-500 dark:text-gray-400 line-clamp-2">
              {guide.description}
            </p>
          </motion.div>
        ))}
      </div>

      <motion.p
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 1.2 }}
        className="text-center text-sm text-gray-500 dark:text-gray-400 mt-4"
      >
        E altri 13 Maestri specializzati in ogni materia!
      </motion.p>
    </motion.section>
  );
}
