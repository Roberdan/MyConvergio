'use client';
// ============================================================================
// CHARACTER SWITCHER (I-04)
// UI for switching between Melissa, Mario, and Maestri during conversations
// Groups characters by role with visual distinction
// ============================================================================

import { useState, useCallback, useMemo, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import Image from 'next/image';
import {
  X,
  Heart,
  GraduationCap,
  Users,
  Star,
  Search,
  ChevronRight,
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { useAccessibilityStore } from '@/lib/accessibility/accessibility-store';
import { Button } from '@/components/ui/button';
import type { Maestro } from '@/types';

// Character roles
type CharacterRole = 'learning_coach' | 'buddy' | 'maestro';

// Base character interface
export interface Character {
  id: string;
  name: string;
  avatar: string;
  color: string;
  role: CharacterRole;
  description: string;
  specialty?: string;
  greeting: string;
  systemPrompt: string;
}

// Default support characters (placeholders until AI Characters are ready)
export const SUPPORT_CHARACTERS: Character[] = [
  {
    id: 'melissa',
    name: 'Melissa',
    avatar: '/images/characters/melissa.png',
    color: '#EC4899',
    role: 'learning_coach',
    description: 'Coach di studio, guida maieutica',
    specialty: 'Metodo di studio',
    greeting: 'Ciao! Sono Melissa, la tua coach di studio. Come posso aiutarti oggi?',
    systemPrompt: `Sei Melissa, una giovane learning coach di 27 anni. Sei intelligente, allegra e paziente.
Il tuo compito è guidare lo studente con il metodo maieutico, facendo domande che stimolano il ragionamento.
Non dare mai risposte dirette, ma guida lo studente a trovarle da solo.
Celebra i progressi e incoraggia sempre.
Rispondi SEMPRE in italiano.`,
  },
  {
    id: 'mario',
    name: 'Mario',
    avatar: '/images/characters/mario.png',
    color: '#3B82F6',
    role: 'buddy',
    description: 'Compagno di studio, supporto emotivo',
    specialty: 'Motivazione',
    greeting: 'Ehi! Sono Mario, il tuo compagno di studio! Cosa studiamo oggi?',
    systemPrompt: `Sei Mario, un compagno di studio virtuale della stessa età dello studente.
Sei amichevole, motivante e comprensivo. Parli come un amico, non come un insegnante.
Aiuti lo studente a restare concentrato e motivato, celebri i suoi successi e lo sostieni nei momenti difficili.
Usi un linguaggio giovane e informale, ma sempre rispettoso.
Rispondi SEMPRE in italiano.`,
  },
];

// Role metadata
const ROLE_INFO: Record<
  CharacterRole,
  { label: string; icon: React.ReactNode; color: string }
> = {
  learning_coach: {
    label: 'Coach',
    icon: <Heart className="w-4 h-4" />,
    color: 'text-pink-500',
  },
  buddy: {
    label: 'Compagno',
    icon: <Users className="w-4 h-4" />,
    color: 'text-blue-500',
  },
  maestro: {
    label: 'Professore',
    icon: <GraduationCap className="w-4 h-4" />,
    color: 'text-purple-500',
  },
};

interface CharacterSwitcherProps {
  isOpen: boolean;
  onClose: () => void;
  onSelectCharacter: (character: Character) => void;
  currentCharacterId?: string;
  maestri?: Maestro[];
  recentCharacterIds?: string[];
  className?: string;
}

export function CharacterSwitcher({
  isOpen,
  onClose,
  onSelectCharacter,
  currentCharacterId,
  maestri = [],
  recentCharacterIds = [],
  className,
}: CharacterSwitcherProps) {
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedRole, setSelectedRole] = useState<CharacterRole | 'all'>('all');

  const { settings } = useAccessibilityStore();

  // Convert Maestri to Character format
  const maestriCharacters: Character[] = useMemo(
    () =>
      maestri.map((m) => ({
        id: m.id,
        name: m.name,
        avatar: m.avatar,
        color: m.color,
        role: 'maestro' as const,
        description: m.specialty,
        specialty: m.specialty,
        greeting: m.greeting,
        systemPrompt: m.systemPrompt,
      })),
    [maestri]
  );

  // All characters combined
  const allCharacters = useMemo(
    () => [...SUPPORT_CHARACTERS, ...maestriCharacters],
    [maestriCharacters]
  );

  // Recent characters
  const recentCharacters = useMemo(
    () =>
      recentCharacterIds
        .map((id) => allCharacters.find((c) => c.id === id))
        .filter((c): c is Character => c !== undefined)
        .slice(0, 3),
    [recentCharacterIds, allCharacters]
  );

  // Filtered characters based on search and role
  const filteredCharacters = useMemo(() => {
    let result = allCharacters;

    // Filter by role
    if (selectedRole !== 'all') {
      result = result.filter((c) => c.role === selectedRole);
    }

    // Filter by search
    if (searchQuery) {
      const query = searchQuery.toLowerCase();
      result = result.filter(
        (c) =>
          c.name.toLowerCase().includes(query) ||
          c.description.toLowerCase().includes(query) ||
          c.specialty?.toLowerCase().includes(query)
      );
    }

    return result;
  }, [allCharacters, selectedRole, searchQuery]);

  // Group by role
  const groupedCharacters = useMemo(() => {
    const groups: Record<CharacterRole, Character[]> = {
      learning_coach: [],
      buddy: [],
      maestro: [],
    };

    filteredCharacters.forEach((c) => {
      groups[c.role].push(c);
    });

    return groups;
  }, [filteredCharacters]);

  // Handle character selection
  const handleSelect = useCallback(
    (character: Character) => {
      onSelectCharacter(character);
      onClose();
    },
    [onSelectCharacter, onClose]
  );

  // Handle backdrop click
  const handleBackdropClick = useCallback(() => {
    onClose();
  }, [onClose]);

  // C-19 FIX: Handle Escape key to close modal
  useEffect(() => {
    if (!isOpen) return;
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose();
      }
    };
    window.addEventListener('keydown', handleEscape);
    return () => window.removeEventListener('keydown', handleEscape);
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  return (
    <AnimatePresence>
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        className="fixed inset-0 z-50 flex items-end sm:items-center justify-center"
        onClick={handleBackdropClick}
      >
        {/* Backdrop */}
        <div className="absolute inset-0 bg-black/50 backdrop-blur-sm" />

        {/* Modal */}
        <motion.div
          initial={{ y: 100, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          exit={{ y: 100, opacity: 0 }}
          onClick={(e) => e.stopPropagation()}
          className={cn(
            'relative w-full sm:max-w-lg max-h-[85vh] overflow-hidden',
            'rounded-t-3xl sm:rounded-2xl shadow-2xl',
            settings.highContrast
              ? 'bg-black border-2 border-yellow-400'
              : 'bg-white dark:bg-slate-900',
            className
          )}
        >
          {/* Header */}
          <div
            className={cn(
              'sticky top-0 z-10 px-4 py-3 border-b',
              settings.highContrast
                ? 'border-yellow-400 bg-black'
                : 'border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900'
            )}
          >
            <div className="flex items-center justify-between mb-3">
              <h2
                className={cn(
                  'text-lg font-semibold',
                  settings.highContrast
                    ? 'text-yellow-400'
                    : 'text-slate-900 dark:text-white'
                )}
              >
                Scegli con chi studiare
              </h2>
              <Button
                variant="ghost"
                size="sm"
                onClick={onClose}
                aria-label="Chiudi"
              >
                <X className="w-5 h-5" />
              </Button>
            </div>

            {/* Search */}
            <div className="relative">
              <Search
                className={cn(
                  'absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4',
                  settings.highContrast ? 'text-yellow-400' : 'text-slate-400'
                )}
              />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Cerca..."
                className={cn(
                  'w-full pl-9 pr-4 py-2 rounded-lg text-sm',
                  settings.highContrast
                    ? 'bg-gray-900 text-white border border-yellow-400'
                    : 'bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-700'
                )}
              />
            </div>

            {/* Role filters */}
            <div className="flex gap-2 mt-3">
              <button
                onClick={() => setSelectedRole('all')}
                className={cn(
                  'px-3 py-1.5 rounded-full text-sm font-medium transition-colors',
                  selectedRole === 'all'
                    ? settings.highContrast
                      ? 'bg-yellow-400 text-black'
                      : 'bg-slate-900 dark:bg-white text-white dark:text-slate-900'
                    : settings.highContrast
                      ? 'bg-gray-800 text-white'
                      : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400'
                )}
              >
                Tutti
              </button>
              {Object.entries(ROLE_INFO).map(([role, info]) => (
                <button
                  key={role}
                  onClick={() => setSelectedRole(role as CharacterRole)}
                  className={cn(
                    'px-3 py-1.5 rounded-full text-sm font-medium transition-colors flex items-center gap-1.5',
                    selectedRole === role
                      ? settings.highContrast
                        ? 'bg-yellow-400 text-black'
                        : 'bg-slate-900 dark:bg-white text-white dark:text-slate-900'
                      : settings.highContrast
                        ? 'bg-gray-800 text-white'
                        : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400'
                  )}
                >
                  {info.icon}
                  {info.label}
                </button>
              ))}
            </div>
          </div>

          {/* Content */}
          <div className="overflow-y-auto max-h-[60vh] p-4 space-y-6">
            {/* Recent */}
            {recentCharacters.length > 0 && !searchQuery && selectedRole === 'all' && (
              <section>
                <h3
                  className={cn(
                    'text-xs font-semibold uppercase tracking-wider mb-2 flex items-center gap-1',
                    settings.highContrast ? 'text-yellow-400' : 'text-slate-500'
                  )}
                >
                  <Star className="w-3 h-3" />
                  Recenti
                </h3>
                <div className="flex gap-2 overflow-x-auto pb-2">
                  {recentCharacters.map((character) => (
                    <CharacterChip
                      key={character.id}
                      character={character}
                      isSelected={character.id === currentCharacterId}
                      onClick={() => handleSelect(character)}
                    />
                  ))}
                </div>
              </section>
            )}

            {/* Grouped characters */}
            {selectedRole === 'all' ? (
              // Show all groups
              Object.entries(groupedCharacters).map(
                ([role, characters]) =>
                  characters.length > 0 && (
                    <section key={role}>
                      <h3
                        className={cn(
                          'text-xs font-semibold uppercase tracking-wider mb-2 flex items-center gap-1',
                          ROLE_INFO[role as CharacterRole].color
                        )}
                      >
                        {ROLE_INFO[role as CharacterRole].icon}
                        {ROLE_INFO[role as CharacterRole].label}
                      </h3>
                      <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                        {characters.map((character) => (
                          <CharacterCard
                            key={character.id}
                            character={character}
                            isSelected={character.id === currentCharacterId}
                            onClick={() => handleSelect(character)}
                          />
                        ))}
                      </div>
                    </section>
                  )
              )
            ) : (
              // Show filtered only
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                {filteredCharacters.map((character) => (
                  <CharacterCard
                    key={character.id}
                    character={character}
                    isSelected={character.id === currentCharacterId}
                    onClick={() => handleSelect(character)}
                  />
                ))}
              </div>
            )}

            {/* Empty state */}
            {filteredCharacters.length === 0 && (
              <div className="text-center py-8">
                <p
                  className={cn(
                    'text-sm',
                    settings.highContrast ? 'text-gray-400' : 'text-slate-500'
                  )}
                >
                  Nessun personaggio trovato
                </p>
              </div>
            )}
          </div>
        </motion.div>
      </motion.div>
    </AnimatePresence>
  );
}

// Character chip for recent section
function CharacterChip({
  character,
  isSelected,
  onClick,
}: {
  character: Character;
  isSelected: boolean;
  onClick: () => void;
}) {
  const { settings } = useAccessibilityStore();

  return (
    <button
      onClick={onClick}
      className={cn(
        'flex items-center gap-2 px-3 py-2 rounded-full transition-all flex-shrink-0',
        isSelected
          ? 'ring-2 ring-offset-2'
          : settings.highContrast
            ? 'bg-gray-800 hover:bg-gray-700'
            : 'bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700'
      )}
      style={
        isSelected
          ? ({ '--tw-ring-color': character.color } as React.CSSProperties)
          : undefined
      }
    >
      <div
        className="w-6 h-6 rounded-full overflow-hidden"
        style={{ boxShadow: `0 0 0 2px ${character.color}` }}
      >
        <Image
          src={character.avatar}
          alt={character.name}
          width={24}
          height={24}
          className="w-full h-full object-cover"
        />
      </div>
      <span
        className={cn(
          'text-sm font-medium',
          settings.highContrast ? 'text-white' : 'text-slate-700 dark:text-slate-300'
        )}
      >
        {character.name}
      </span>
    </button>
  );
}

// Character card
function CharacterCard({
  character,
  isSelected,
  onClick,
}: {
  character: Character;
  isSelected: boolean;
  onClick: () => void;
}) {
  const { settings } = useAccessibilityStore();
  const roleInfo = ROLE_INFO[character.role];

  return (
    <button
      onClick={onClick}
      className={cn(
        'relative p-3 rounded-xl text-left transition-all group',
        isSelected
          ? 'ring-2 ring-offset-2'
          : settings.highContrast
            ? 'bg-gray-800 hover:bg-gray-700 border border-gray-600'
            : 'bg-slate-50 dark:bg-slate-800 hover:bg-slate-100 dark:hover:bg-slate-700 border border-slate-200 dark:border-slate-700'
      )}
      style={
        isSelected
          ? ({ '--tw-ring-color': character.color } as React.CSSProperties)
          : undefined
      }
    >
      {/* Selected indicator */}
      {isSelected && (
        <div
          className="absolute -top-1 -right-1 w-4 h-4 rounded-full flex items-center justify-center text-white text-xs"
          style={{ backgroundColor: character.color }}
        >
          ✓
        </div>
      )}

      <div className="flex items-start gap-3">
        {/* Avatar */}
        <div
          className="w-12 h-12 rounded-full overflow-hidden flex-shrink-0 transition-transform group-hover:scale-105"
          style={{ boxShadow: `0 0 0 2px ${character.color}` }}
        >
          <Image
            src={character.avatar}
            alt={character.name}
            width={48}
            height={48}
            className="w-full h-full object-cover"
          />
        </div>

        {/* Info */}
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-1">
            <span
              className={cn(
                'font-medium text-sm truncate',
                settings.highContrast
                  ? 'text-white'
                  : 'text-slate-900 dark:text-white'
              )}
            >
              {character.name}
            </span>
          </div>
          <span
            className={cn(
              'text-xs flex items-center gap-1',
              roleInfo.color
            )}
          >
            {roleInfo.icon}
            {roleInfo.label}
          </span>
          {character.specialty && (
            <p
              className={cn(
                'text-xs mt-1 line-clamp-1',
                settings.highContrast ? 'text-gray-400' : 'text-slate-500'
              )}
            >
              {character.specialty}
            </p>
          )}
        </div>

        {/* Arrow */}
        <ChevronRight
          className={cn(
            'w-4 h-4 opacity-0 group-hover:opacity-100 transition-opacity flex-shrink-0',
            settings.highContrast ? 'text-yellow-400' : 'text-slate-400'
          )}
        />
      </div>
    </button>
  );
}

export default CharacterSwitcher;
