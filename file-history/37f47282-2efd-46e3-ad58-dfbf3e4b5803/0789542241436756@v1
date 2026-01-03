'use client';

import { useState, useEffect, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Plus,
  Play,
  Trash2,
  Edit,
  X,
  Save,
  Layers,
  MessageSquare,
  Loader2,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { FlashcardStudy } from './flashcard';
import { cn } from '@/lib/utils';
import { subjectNames, subjectIcons, subjectColors } from '@/data';
import type { FlashcardDeck, Flashcard, Subject, Rating, CardState, Maestro } from '@/types';
import { useUIStore } from '@/lib/stores/app-store';
import { ToolMaestroSelectionDialog } from './tool-maestro-selection-dialog';

// FSRS-5 Parameters (optimized defaults)
const FSRS_PARAMS = {
  w: [0.4, 0.6, 2.4, 5.8, 4.93, 0.94, 0.86, 0.01, 1.49, 0.14, 0.94, 2.18, 0.05, 0.34, 1.26, 0.29, 2.61],
  requestRetention: 0.9,
  maximumInterval: 36500,
};

// Calculate next review using FSRS-5
function fsrs5Schedule(card: Flashcard, rating: Rating): Partial<Flashcard> {
  const ratingMap: Record<Rating, number> = { again: 1, hard: 2, good: 3, easy: 4 };
  const r = ratingMap[rating];

  let newState: CardState = card.state;
  let newStability = card.stability;
  let newDifficulty = card.difficulty;
  let newReps = card.reps;
  let newLapses = card.lapses;
  let scheduledDays = 1;

  if (card.state === 'new') {
    // First review
    newState = 'learning';
    newStability = FSRS_PARAMS.w[r - 1];
    newDifficulty = FSRS_PARAMS.w[4] - Math.exp(FSRS_PARAMS.w[5] * (r - 3)) + 1;
    newDifficulty = Math.max(1, Math.min(10, newDifficulty));
    newReps = 1;
  } else if (rating === 'again') {
    // Lapse
    newState = 'relearning';
    newLapses = card.lapses + 1;
    newStability = Math.max(0.1, card.stability * FSRS_PARAMS.w[11]);
  } else {
    // Successful review
    newState = 'review';
    newReps = card.reps + 1;

    // Update difficulty
    const deltaDifficulty = -FSRS_PARAMS.w[6] * (r - 3);
    newDifficulty = Math.max(1, Math.min(10, card.difficulty + deltaDifficulty));

    // Update stability
    const retrievability = Math.pow(1 + card.elapsedDays / (9 * card.stability), -1);
    const stabilityIncrease = Math.exp(FSRS_PARAMS.w[8]) *
      (11 - newDifficulty) *
      Math.pow(card.stability, -FSRS_PARAMS.w[9]) *
      (Math.exp((1 - retrievability) * FSRS_PARAMS.w[10]) - 1);

    if (rating === 'hard') {
      newStability = card.stability * (1 + stabilityIncrease * FSRS_PARAMS.w[15]);
    } else if (rating === 'easy') {
      newStability = card.stability * (1 + stabilityIncrease * FSRS_PARAMS.w[16]);
    } else {
      newStability = card.stability * (1 + stabilityIncrease);
    }
  }

  // Calculate interval
  const requestedRetention = FSRS_PARAMS.requestRetention;
  scheduledDays = Math.round(
    9 * newStability * (1 / requestedRetention - 1)
  );
  scheduledDays = Math.max(1, Math.min(scheduledDays, FSRS_PARAMS.maximumInterval));

  return {
    state: newState,
    stability: newStability,
    difficulty: newDifficulty,
    reps: newReps,
    lapses: newLapses,
    scheduledDays,
    elapsedDays: 0,
    lastReview: new Date(),
    nextReview: new Date(Date.now() + scheduledDays * 24 * 60 * 60 * 1000),
  };
}

interface FlashcardsViewProps {
  className?: string;
}

// Get user ID for API calls
function getUserId(): string {
  if (typeof window === 'undefined') return 'default-user';
  let userId = sessionStorage.getItem('mirrorbuddy-user-id');
  if (!userId) {
    userId = `user-${crypto.randomUUID()}`;
    sessionStorage.setItem('mirrorbuddy-user-id', userId);
  }
  return userId;
}

export function FlashcardsView({ className }: FlashcardsViewProps) {
  const _router = useRouter();
  const { enterFocusMode } = useUIStore();

  // Load decks from database API
  const [decks, setDecks] = useState<FlashcardDeck[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedDeck, setSelectedDeck] = useState<FlashcardDeck | null>(null);
  const [isStudying, setIsStudying] = useState(false);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [editingDeck, setEditingDeck] = useState<FlashcardDeck | null>(null);
  const [showMaestroDialog, setShowMaestroDialog] = useState(false);

  // Handle maestro selection and enter focus mode
  const handleMaestroConfirm = useCallback((maestro: Maestro, mode: 'voice' | 'chat') => {
    setShowMaestroDialog(false);
    enterFocusMode('flashcard', maestro.id, mode);
  }, [enterFocusMode]);

  // Fetch decks from API
  const loadDecks = useCallback(async () => {
    setLoading(true);
    try {
      const userId = getUserId();
      const response = await fetch(`/api/materials?userId=${userId}&toolType=flashcard&status=active`);
      if (response.ok) {
        const data = await response.json();
        const loadedDecks: FlashcardDeck[] = (data.materials || []).map((m: { toolId: string; title: string; subject?: string; content: { cards?: Flashcard[] }; createdAt: string }) => ({
          id: m.toolId,
          name: m.title,
          subject: (m.subject || 'mathematics') as Subject,
          cards: (m.content?.cards || []).map((c: Flashcard) => ({
            ...c,
            nextReview: new Date(c.nextReview),
            lastReview: c.lastReview ? new Date(c.lastReview) : undefined,
          })),
          createdAt: new Date(m.createdAt),
        }));
        setDecks(loadedDecks);
      }
    } catch {
      // Silent failure
    }
    setLoading(false);
  }, []);

  // Load decks on mount - setState in effect is intentional for data fetching
  /* eslint-disable react-hooks/set-state-in-effect -- ADR 0015: Data loading pattern */
  useEffect(() => {
    loadDecks();
  }, [loadDecks]);
  /* eslint-enable react-hooks/set-state-in-effect */

  // Save deck to API
  const saveDeckToAPI = useCallback(async (deck: FlashcardDeck) => {
    const userId = getUserId();
    await fetch('/api/materials', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId,
        toolId: deck.id,
        toolType: 'flashcard',
        title: deck.name,
        content: { cards: deck.cards },
        subject: deck.subject,
      }),
    });
  }, []);

  // Save all decks
  const saveDecks = useCallback(async (newDecks: FlashcardDeck[]) => {
    setDecks(newDecks);
    // Find changed deck and save it
    for (const deck of newDecks) {
      await saveDeckToAPI(deck);
    }
  }, [saveDeckToAPI]);

  // Get cards due for review
  const getDueCards = (deck: FlashcardDeck) => {
    return deck.cards.filter(card =>
      card.state === 'new' || new Date(card.nextReview) <= new Date()
    );
  };

  // Handle card rating
  const handleRating = (cardId: string, rating: Rating) => {
    if (!selectedDeck) return;

    const updatedDecks = decks.map(deck => {
      if (deck.id !== selectedDeck.id) return deck;

      return {
        ...deck,
        cards: deck.cards.map(card => {
          if (card.id !== cardId) return card;
          const updates = fsrs5Schedule(card, rating);
          return { ...card, ...updates };
        }),
        lastStudied: new Date(),
      };
    });

    saveDecks(updatedDecks);
    setSelectedDeck(updatedDecks.find(d => d.id === selectedDeck.id) || null);
  };

  // Handle study complete
  const handleStudyComplete = () => {
    setIsStudying(false);
  };

  // Delete deck via API
  const deleteDeck = async (deckId: string) => {
    try {
      await fetch(`/api/materials?toolId=${deckId}`, { method: 'DELETE' });
      setDecks(decks.filter(d => d.id !== deckId));
      if (selectedDeck?.id === deckId) {
        setSelectedDeck(null);
      }
    } catch {
      // Silent failure
    }
  };

  // Handle Escape key to close modals
  const closeStudyModal = useCallback(() => {
    setIsStudying(false);
  }, []);

  const closeCreateModal = useCallback(() => {
    setShowCreateModal(false);
    setEditingDeck(null);
  }, []);

  useEffect(() => {
    if (!isStudying && !showCreateModal) return;

    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        if (isStudying) {
          closeStudyModal();
        } else if (showCreateModal) {
          closeCreateModal();
        }
      }
    };
    window.addEventListener('keydown', handleEscape);
    return () => window.removeEventListener('keydown', handleEscape);
  }, [isStudying, showCreateModal, closeStudyModal, closeCreateModal]);

  // Stats for a deck
  const getDeckStats = (deck: FlashcardDeck) => {
    const newCards = deck.cards.filter(c => c.state === 'new').length;
    const learning = deck.cards.filter(c => c.state === 'learning' || c.state === 'relearning').length;
    const review = deck.cards.filter(c => c.state === 'review').length;
    const dueToday = getDueCards(deck).length;
    return { newCards, learning, review, dueToday, total: deck.cards.length };
  };

  return (
    <div className={cn('space-y-6', className)}>
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-slate-900 dark:text-white">
            Flashcards
          </h2>
          <p className="text-slate-600 dark:text-slate-400">
            Sistema di ripetizione spaziata FSRS-5
          </p>
        </div>
        <div className="flex gap-2">
          {/* PRIMARY: Conversation-first approach (Phase 6) */}
          <Button onClick={() => setShowMaestroDialog(true)}>
            <MessageSquare className="w-4 h-4 mr-2" />
            Crea con un Professore
          </Button>
          {/* SECONDARY: Manual form fallback */}
          <Button variant="outline" onClick={() => setShowCreateModal(true)}>
            <Plus className="w-4 h-4 mr-2" />
            Modalità Manuale
          </Button>
        </div>
      </div>

      {/* Decks grid */}
      {loading ? (
        <Card className="p-12">
          <div className="text-center">
            <Loader2 className="w-16 h-16 mx-auto text-slate-400 mb-4 animate-spin" />
            <h3 className="text-xl font-semibold text-slate-900 dark:text-white mb-2">
              Caricamento...
            </h3>
          </div>
        </Card>
      ) : decks.length === 0 ? (
        <Card className="p-12">
          <div className="text-center">
            <Layers className="w-16 h-16 mx-auto text-slate-400 mb-4" />
            <h3 className="text-xl font-semibold text-slate-900 dark:text-white mb-2">
              Nessun mazzo creato
            </h3>
            <p className="text-slate-600 dark:text-slate-400 mb-6">
              Crea il tuo primo mazzo di flashcards per iniziare a studiare
            </p>
            <Button onClick={() => setShowCreateModal(true)}>
              <Plus className="w-4 h-4 mr-2" />
              Crea Mazzo
            </Button>
          </div>
        </Card>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {decks.map((deck) => {
            const stats = getDeckStats(deck);
            return (
              <Card
                key={deck.id}
                className="cursor-pointer hover:shadow-lg transition-shadow"
                onClick={() => setSelectedDeck(deck)}
              >
                <CardHeader className="pb-3">
                  <div className="flex items-start justify-between">
                    <div className="flex items-center gap-3">
                      <div
                        className="w-10 h-10 rounded-xl flex items-center justify-center text-lg"
                        style={{ backgroundColor: `${subjectColors[deck.subject]}20` }}
                      >
                        {subjectIcons[deck.subject]}
                      </div>
                      <div>
                        <CardTitle className="text-lg">{deck.name}</CardTitle>
                        <p className="text-sm text-slate-500">
                          {subjectNames[deck.subject]}
                        </p>
                      </div>
                    </div>
                    <div className="flex gap-1">
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          setEditingDeck(deck);
                          setShowCreateModal(true);
                        }}
                        className="p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800"
                      >
                        <Edit className="w-4 h-4 text-slate-500" />
                      </button>
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          deleteDeck(deck.id);
                        }}
                        className="p-2 rounded-lg hover:bg-red-100 dark:hover:bg-red-900/20"
                      >
                        <Trash2 className="w-4 h-4 text-red-500" />
                      </button>
                    </div>
                  </div>
                </CardHeader>
                <CardContent>
                  {/* Stats */}
                  <div className="grid grid-cols-4 gap-2 mb-4 text-center">
                    <div className="p-2 rounded-lg bg-blue-50 dark:bg-blue-900/20">
                      <p className="text-lg font-bold text-blue-600">{stats.newCards}</p>
                      <p className="text-xs text-blue-600/80">Nuove</p>
                    </div>
                    <div className="p-2 rounded-lg bg-orange-50 dark:bg-orange-900/20">
                      <p className="text-lg font-bold text-orange-600">{stats.learning}</p>
                      <p className="text-xs text-orange-600/80">Learning</p>
                    </div>
                    <div className="p-2 rounded-lg bg-green-50 dark:bg-green-900/20">
                      <p className="text-lg font-bold text-green-600">{stats.review}</p>
                      <p className="text-xs text-green-600/80">Review</p>
                    </div>
                    <div className="p-2 rounded-lg bg-purple-50 dark:bg-purple-900/20">
                      <p className="text-lg font-bold text-purple-600">{stats.dueToday}</p>
                      <p className="text-xs text-purple-600/80">Oggi</p>
                    </div>
                  </div>

                  {/* Study button */}
                  {stats.dueToday > 0 && (
                    <Button
                      className="w-full"
                      onClick={(e) => {
                        e.stopPropagation();
                        setSelectedDeck(deck);
                        setIsStudying(true);
                      }}
                    >
                      <Play className="w-4 h-4 mr-2" />
                      Studia ({stats.dueToday} carte)
                    </Button>
                  )}
                </CardContent>
              </Card>
            );
          })}
        </div>
      )}

      {/* Study modal */}
      <AnimatePresence>
        {isStudying && selectedDeck && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
          >
            <motion.div
              initial={{ scale: 0.95 }}
              animate={{ scale: 1 }}
              exit={{ scale: 0.95 }}
              className="bg-white dark:bg-slate-900 rounded-2xl p-6 max-w-xl w-full max-h-[90vh] overflow-y-auto"
            >
              <div className="flex items-center justify-between mb-6">
                <h3 className="text-xl font-bold">{selectedDeck.name}</h3>
                <button
                  onClick={() => setIsStudying(false)}
                  className="p-2 rounded-full hover:bg-slate-100 dark:hover:bg-slate-800"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>
              <FlashcardStudy
                deck={selectedDeck}
                onRating={handleRating}
                onComplete={handleStudyComplete}
              />
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Create/Edit modal */}
      <AnimatePresence>
        {showCreateModal && (
          <DeckEditor
            deck={editingDeck}
            onSave={(deck) => {
              if (editingDeck) {
                saveDecks(decks.map(d => d.id === deck.id ? deck : d));
              } else {
                saveDecks([...decks, deck]);
              }
              setShowCreateModal(false);
              setEditingDeck(null);
            }}
            onClose={() => {
              setShowCreateModal(false);
              setEditingDeck(null);
            }}
          />
        )}
      </AnimatePresence>

      {/* Maestro selection dialog */}
      <ToolMaestroSelectionDialog
        isOpen={showMaestroDialog}
        toolType="flashcard"
        onConfirm={handleMaestroConfirm}
        onClose={() => setShowMaestroDialog(false)}
      />
    </div>
  );
}

// Deck editor component
interface DeckEditorProps {
  deck: FlashcardDeck | null;
  onSave: (deck: FlashcardDeck) => void;
  onClose: () => void;
}

function DeckEditor({ deck, onSave, onClose }: DeckEditorProps) {
  const [name, setName] = useState(deck?.name || '');
  const [subject, setSubject] = useState<Subject>(deck?.subject || 'mathematics');
  const [cards, setCards] = useState<Array<{ front: string; back: string }>>(
    deck?.cards.map(c => ({ front: c.front, back: c.back })) || [{ front: '', back: '' }]
  );

  const subjects = Object.keys(subjectNames) as Subject[];

  const addCard = () => {
    setCards([...cards, { front: '', back: '' }]);
  };

  const removeCard = (index: number) => {
    setCards(cards.filter((_, i) => i !== index));
  };

  const updateCard = (index: number, field: 'front' | 'back', value: string) => {
    setCards(cards.map((card, i) =>
      i === index ? { ...card, [field]: value } : card
    ));
  };

  const handleSave = () => {
    if (!name.trim() || cards.length === 0) return;

    const validCards = cards.filter(c => c.front.trim() && c.back.trim());
    if (validCards.length === 0) return;

    const newDeck: FlashcardDeck = {
      id: deck?.id || crypto.randomUUID(),
      name: name.trim(),
      subject,
      cards: validCards.map((c, i): Flashcard => ({
        id: deck?.cards[i]?.id || crypto.randomUUID(),
        deckId: deck?.id || '',
        front: c.front.trim(),
        back: c.back.trim(),
        state: 'new',
        stability: 0,
        difficulty: 0,
        elapsedDays: 0,
        scheduledDays: 0,
        reps: 0,
        lapses: 0,
        nextReview: new Date(),
      })),
      createdAt: deck?.createdAt || new Date(),
      lastStudied: deck?.lastStudied,
    };

    onSave(newDeck);
  };

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
      onClick={onClose}
    >
      <motion.div
        initial={{ scale: 0.95 }}
        animate={{ scale: 1 }}
        exit={{ scale: 0.95 }}
        onClick={(e) => e.stopPropagation()}
        className="bg-white dark:bg-slate-900 rounded-2xl p-6 max-w-2xl w-full max-h-[90vh] overflow-y-auto"
      >
        <div className="flex items-center justify-between mb-6">
          <h3 className="text-xl font-bold">
            {deck ? 'Modifica Mazzo' : 'Nuovo Mazzo'}
          </h3>
          <button
            onClick={onClose}
            className="p-2 rounded-full hover:bg-slate-100 dark:hover:bg-slate-800"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Name */}
        <div className="mb-4">
          <label className="block text-sm font-medium mb-2">Nome del mazzo</label>
          <input
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Es: Verbi Irregolari Inglese"
            className="w-full px-4 py-2 rounded-xl bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-700"
          />
        </div>

        {/* Subject */}
        <div className="mb-6">
          <label className="block text-sm font-medium mb-2">Materia</label>
          <div className="flex flex-wrap gap-2">
            {subjects.map((s) => (
              <button
                key={s}
                onClick={() => setSubject(s)}
                className={cn(
                  'px-3 py-1.5 rounded-full text-sm flex items-center gap-1.5 transition-colors',
                  subject === s
                    ? 'text-white'
                    : 'bg-slate-100 dark:bg-slate-800'
                )}
                style={subject === s ? { backgroundColor: subjectColors[s] } : {}}
              >
                {subjectIcons[s]} {subjectNames[s]}
              </button>
            ))}
          </div>
        </div>

        {/* Cards */}
        <div className="mb-6">
          <label className="block text-sm font-medium mb-2">
            Carte ({cards.length})
          </label>
          <div className="space-y-3 max-h-[40vh] overflow-y-auto">
            {cards.map((card, index) => (
              <div
                key={index}
                className="p-4 rounded-xl bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700"
              >
                <div className="flex items-start gap-3">
                  <span className="text-sm text-slate-500 mt-2">{index + 1}</span>
                  <div className="flex-1 space-y-2">
                    <input
                      type="text"
                      value={card.front}
                      onChange={(e) => updateCard(index, 'front', e.target.value)}
                      placeholder="Domanda (fronte)"
                      className="w-full px-3 py-2 rounded-lg bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 text-sm"
                    />
                    <input
                      type="text"
                      value={card.back}
                      onChange={(e) => updateCard(index, 'back', e.target.value)}
                      placeholder="Risposta (retro)"
                      className="w-full px-3 py-2 rounded-lg bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 text-sm"
                    />
                  </div>
                  <button
                    onClick={() => removeCard(index)}
                    className="p-2 rounded-lg hover:bg-red-100 dark:hover:bg-red-900/20"
                    disabled={cards.length === 1}
                  >
                    <Trash2 className="w-4 h-4 text-red-500" />
                  </button>
                </div>
              </div>
            ))}
          </div>
          <Button variant="outline" onClick={addCard} className="mt-3 w-full">
            <Plus className="w-4 h-4 mr-2" />
            Aggiungi Carta
          </Button>
        </div>

        {/* Actions */}
        <div className="flex justify-end gap-3">
          <Button variant="outline" onClick={onClose}>
            Annulla
          </Button>
          <Button onClick={handleSave} disabled={!name.trim() || cards.every(c => !c.front.trim())}>
            <Save className="w-4 h-4 mr-2" />
            Salva
          </Button>
        </div>
      </motion.div>
    </motion.div>
  );
}
