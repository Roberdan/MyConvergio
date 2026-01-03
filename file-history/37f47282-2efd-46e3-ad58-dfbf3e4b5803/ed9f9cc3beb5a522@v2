'use client';

// ============================================================================
// SESSION RATING MODAL
// Student self-evaluation UI component shown at session end
// Part of Session Summary & Unified Archive feature
// ============================================================================

import React, { useState, useEffect } from 'react';
import { Star, X, Send, Loader2 } from 'lucide-react';

interface SessionRatingModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSubmit: (rating: number, feedback?: string) => Promise<void>;
  sessionInfo?: {
    maestroName: string;
    duration: number; // minutes
    topics: string[];
  };
}

export function SessionRatingModal({
  isOpen,
  onClose,
  onSubmit,
  sessionInfo,
}: SessionRatingModalProps) {
  const [rating, setRating] = useState<number>(0);
  const [hoveredRating, setHoveredRating] = useState<number>(0);
  const [feedback, setFeedback] = useState<string>('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

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

  const handleSubmit = async () => {
    if (rating === 0) {
      setError('Per favore seleziona un voto');
      return;
    }

    setIsSubmitting(true);
    setError(null);

    try {
      await onSubmit(rating, feedback.trim() || undefined);
      onClose();
    } catch (_err) {
      setError('Errore nel salvare la valutazione. Riprova.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleSkip = () => {
    onClose();
  };

  const ratingLabels = [
    '',
    'Per niente soddisfatto',
    'Poco soddisfatto',
    'Così così',
    'Soddisfatto',
    'Molto soddisfatto!',
  ];

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="w-full max-w-md rounded-2xl bg-white p-6 shadow-2xl dark:bg-gray-800">
        {/* Header */}
        <div className="mb-6 flex items-center justify-between">
          <h2 className="text-xl font-bold text-gray-900 dark:text-white">
            Come è andata?
          </h2>
          <button
            onClick={handleSkip}
            className="rounded-full p-1 text-gray-400 hover:bg-gray-100 hover:text-gray-600 dark:hover:bg-gray-700"
            aria-label="Chiudi"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        {/* Session info */}
        {sessionInfo && (
          <div className="mb-6 rounded-lg bg-gray-50 p-3 dark:bg-gray-700/50">
            <p className="text-sm text-gray-600 dark:text-gray-300">
              Sessione con <span className="font-medium">{sessionInfo.maestroName}</span>
              {sessionInfo.duration > 0 && (
                <> • {sessionInfo.duration} minuti</>
              )}
            </p>
            {sessionInfo.topics.length > 0 && (
              <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">
                Argomenti: {sessionInfo.topics.slice(0, 3).join(', ')}
              </p>
            )}
          </div>
        )}

        {/* Star rating */}
        <div className="mb-4 flex flex-col items-center">
          <div className="flex gap-2">
            {[1, 2, 3, 4, 5].map((star) => (
              <button
                key={star}
                onClick={() => setRating(star)}
                onMouseEnter={() => setHoveredRating(star)}
                onMouseLeave={() => setHoveredRating(0)}
                className="transition-transform hover:scale-110 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 rounded-full"
                aria-label={`${star} stelle`}
              >
                <Star
                  className={`h-10 w-10 transition-colors ${
                    star <= (hoveredRating || rating)
                      ? 'fill-yellow-400 text-yellow-400'
                      : 'text-gray-300 dark:text-gray-600'
                  }`}
                />
              </button>
            ))}
          </div>
          <p className="mt-2 h-6 text-sm text-gray-600 dark:text-gray-400">
            {ratingLabels[hoveredRating || rating] || 'Seleziona un voto'}
          </p>
        </div>

        {/* Optional feedback */}
        <div className="mb-6">
          <label
            htmlFor="feedback"
            className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300"
          >
            Vuoi aggiungere un commento? (opzionale)
          </label>
          <textarea
            id="feedback"
            value={feedback}
            onChange={(e) => setFeedback(e.target.value)}
            placeholder="Cosa ti è piaciuto? Cosa potrebbe migliorare?"
            className="w-full rounded-lg border border-gray-300 p-3 text-sm focus:border-blue-500 focus:ring-1 focus:ring-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white dark:placeholder-gray-400"
            rows={3}
            maxLength={500}
          />
        </div>

        {/* Error message */}
        {error && (
          <p className="mb-4 text-center text-sm text-red-500">{error}</p>
        )}

        {/* Actions */}
        <div className="flex gap-3">
          <button
            onClick={handleSkip}
            className="flex-1 rounded-lg border border-gray-300 px-4 py-2.5 text-sm font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-700"
          >
            Salta
          </button>
          <button
            onClick={handleSubmit}
            disabled={isSubmitting || rating === 0}
            className="flex flex-1 items-center justify-center gap-2 rounded-lg bg-blue-600 px-4 py-2.5 text-sm font-medium text-white hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-50"
          >
            {isSubmitting ? (
              <>
                <Loader2 className="h-4 w-4 animate-spin" />
                Invio...
              </>
            ) : (
              <>
                <Send className="h-4 w-4" />
                Invia
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}

export default SessionRatingModal;
