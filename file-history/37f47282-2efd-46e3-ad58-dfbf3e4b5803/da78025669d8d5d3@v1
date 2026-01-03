/**
 * Tests for use-saved-materials.ts hook
 * Issue #64: Consolidate localStorage to Database
 *
 * @vitest-environment jsdom
 * @module hooks/__tests__/use-saved-materials.test
 */

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { renderHook, act, waitFor } from '@testing-library/react';
import {
  useMindmaps,
  useQuizzes,
  useFlashcardDecks,
  useHomeworkSessions,
  autoSaveMaterial,
} from '../use-saved-materials';

// Mock fetch globally
const mockFetch = vi.fn();
global.fetch = mockFetch;

// Mock crypto.randomUUID
const mockUUID = 'test-uuid-12345';
vi.stubGlobal('crypto', {
  randomUUID: () => mockUUID,
});

// Mock sessionStorage
const mockSessionStorage: Record<string, string> = {};
vi.stubGlobal('sessionStorage', {
  getItem: (key: string) => mockSessionStorage[key] || null,
  setItem: (key: string, value: string) => {
    mockSessionStorage[key] = value;
  },
  removeItem: (key: string) => {
    delete mockSessionStorage[key];
  },
  clear: () => {
    for (const key in mockSessionStorage) {
      delete mockSessionStorage[key];
    }
  },
});

// Mock logger
vi.mock('@/lib/logger', () => ({
  logger: {
    error: vi.fn(),
    warn: vi.fn(),
    info: vi.fn(),
    debug: vi.fn(),
  },
}));

describe('use-saved-materials', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockFetch.mockReset();
    sessionStorage.clear();
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  // ============================================================================
  // useMindmaps
  // ============================================================================
  describe('useMindmaps', () => {
    const mockMindmapMaterial = {
      id: '1',
      toolId: 'mindmap-1',
      toolType: 'mindmap',
      title: 'Test Mindmap',
      content: { nodes: [{ id: 'root', label: 'Root' }] },
      subject: 'mathematics',
      maestroId: 'archimede',
      status: 'active',
      isBookmarked: false,
      viewCount: 0,
      createdAt: '2026-01-01T00:00:00Z',
      updatedAt: '2026-01-01T00:00:00Z',
    };

    it('should load mindmaps from API on mount', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ materials: [mockMindmapMaterial] }),
      });

      const { result } = renderHook(() => useMindmaps());

      expect(result.current.loading).toBe(true);

      await waitFor(() => {
        expect(result.current.loading).toBe(false);
      });

      expect(result.current.mindmaps).toHaveLength(1);
      expect(result.current.mindmaps[0].title).toBe('Test Mindmap');
      expect(result.current.mindmaps[0].nodes).toEqual([{ id: 'root', label: 'Root' }]);
    });

    it('should return empty array when API fails', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 500,
      });

      const { result } = renderHook(() => useMindmaps());

      await waitFor(() => {
        expect(result.current.loading).toBe(false);
      });

      expect(result.current.mindmaps).toEqual([]);
    });

    it('should save mindmap and reload list', async () => {
      // Initial load
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ materials: [] }),
      });

      const { result } = renderHook(() => useMindmaps());

      await waitFor(() => {
        expect(result.current.loading).toBe(false);
      });

      // Save request
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ material: mockMindmapMaterial }),
      });

      // Reload after save
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ materials: [mockMindmapMaterial] }),
      });

      await act(async () => {
        await result.current.saveMindmap({
          title: 'Test Mindmap',
          nodes: [{ id: 'root', label: 'Root' }],
          subject: 'mathematics',
          maestroId: 'archimede',
        });
      });

      expect(mockFetch).toHaveBeenCalledWith('/api/materials', expect.objectContaining({
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      }));
    });

    it('should delete mindmap and update local state', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ materials: [mockMindmapMaterial] }),
      });

      const { result } = renderHook(() => useMindmaps());

      await waitFor(() => {
        expect(result.current.mindmaps).toHaveLength(1);
      });

      // Delete request
      mockFetch.mockResolvedValueOnce({ ok: true });

      await act(async () => {
        const success = await result.current.deleteMindmap('mindmap-1');
        expect(success).toBe(true);
      });

      expect(result.current.mindmaps).toHaveLength(0);
    });
  });

  // ============================================================================
  // useQuizzes
  // ============================================================================
  describe('useQuizzes', () => {
    const mockQuizMaterial = {
      id: '2',
      toolId: 'quiz-1',
      toolType: 'quiz',
      title: 'Math Quiz',
      content: {
        questions: [
          { question: '2+2?', options: ['3', '4', '5'], correctIndex: 1 },
        ],
      },
      subject: 'mathematics',
      status: 'active',
      isBookmarked: false,
      viewCount: 0,
      createdAt: '2026-01-01T00:00:00Z',
      updatedAt: '2026-01-01T00:00:00Z',
    };

    it('should load quizzes from API on mount', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ materials: [mockQuizMaterial] }),
      });

      const { result } = renderHook(() => useQuizzes());

      await waitFor(() => {
        expect(result.current.loading).toBe(false);
      });

      expect(result.current.quizzes).toHaveLength(1);
      expect(result.current.quizzes[0].title).toBe('Math Quiz');
      expect(result.current.quizzes[0].questions).toHaveLength(1);
    });

    it('should save quiz and reload list', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ materials: [] }),
      });

      const { result } = renderHook(() => useQuizzes());

      await waitFor(() => {
        expect(result.current.loading).toBe(false);
      });

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ material: mockQuizMaterial }),
      });
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ materials: [mockQuizMaterial] }),
      });

      await act(async () => {
        await result.current.saveQuiz({
          title: 'Math Quiz',
          subject: 'mathematics',
          questions: [{ question: '2+2?', options: ['3', '4', '5'], correctIndex: 1 }],
        });
      });

      expect(mockFetch).toHaveBeenCalledWith('/api/materials', expect.objectContaining({
        method: 'POST',
      }));
    });

    it('should delete quiz and update state', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ materials: [mockQuizMaterial] }),
      });

      const { result } = renderHook(() => useQuizzes());

      await waitFor(() => {
        expect(result.current.quizzes).toHaveLength(1);
      });

      mockFetch.mockResolvedValueOnce({ ok: true });

      await act(async () => {
        const success = await result.current.deleteQuiz('quiz-1');
        expect(success).toBe(true);
      });

      expect(result.current.quizzes).toHaveLength(0);
    });
  });

  // ============================================================================
  // useFlashcardDecks
  // ============================================================================
  describe('useFlashcardDecks', () => {
    const mockDeckMaterial = {
      id: '3',
      toolId: 'deck-1',
      toolType: 'flashcard',
      title: 'Vocabulary Deck',
      content: {
        cards: [{ front: 'Hello', back: 'Ciao' }],
      },
      subject: 'english',
      status: 'active',
      isBookmarked: false,
      viewCount: 0,
      createdAt: '2026-01-01T00:00:00Z',
      updatedAt: '2026-01-01T00:00:00Z',
    };

    it('should load decks from API on mount', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ materials: [mockDeckMaterial] }),
      });

      const { result } = renderHook(() => useFlashcardDecks());

      await waitFor(() => {
        expect(result.current.loading).toBe(false);
      });

      expect(result.current.decks).toHaveLength(1);
      expect(result.current.decks[0].name).toBe('Vocabulary Deck');
      expect(result.current.decks[0].cards).toHaveLength(1);
    });

    it('should save deck and reload list', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ materials: [] }),
      });

      const { result } = renderHook(() => useFlashcardDecks());

      await waitFor(() => {
        expect(result.current.loading).toBe(false);
      });

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ material: mockDeckMaterial }),
      });
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ materials: [mockDeckMaterial] }),
      });

      await act(async () => {
        await result.current.saveDeck({
          name: 'Vocabulary Deck',
          subject: 'english',
          cards: [{ front: 'Hello', back: 'Ciao' }],
        });
      });

      expect(mockFetch).toHaveBeenCalledWith('/api/materials', expect.objectContaining({
        method: 'POST',
      }));
    });

    it('should delete deck and update state', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ materials: [mockDeckMaterial] }),
      });

      const { result } = renderHook(() => useFlashcardDecks());

      await waitFor(() => {
        expect(result.current.decks).toHaveLength(1);
      });

      mockFetch.mockResolvedValueOnce({ ok: true });

      await act(async () => {
        const success = await result.current.deleteDeck('deck-1');
        expect(success).toBe(true);
      });

      expect(result.current.decks).toHaveLength(0);
    });
  });

  // ============================================================================
  // useHomeworkSessions
  // ============================================================================
  describe('useHomeworkSessions', () => {
    const mockHomeworkMaterial = {
      id: '4',
      toolId: 'homework-1',
      toolType: 'homework',
      title: 'Math Homework',
      content: {
        steps: [{ id: 's1', description: 'Step 1', hints: [], studentNotes: '', completed: false }],
        problemType: 'Esercizio',
        photoUrl: 'https://example.com/photo.jpg',
      },
      subject: 'mathematics',
      status: 'active',
      isBookmarked: false,
      viewCount: 0,
      createdAt: '2026-01-01T00:00:00Z',
      updatedAt: '2026-01-01T00:00:00Z',
    };

    it('should load homework sessions from API on mount', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ materials: [mockHomeworkMaterial] }),
      });

      const { result } = renderHook(() => useHomeworkSessions());

      await waitFor(() => {
        expect(result.current.loading).toBe(false);
      });

      expect(result.current.sessions).toHaveLength(1);
      expect(result.current.sessions[0].title).toBe('Math Homework');
      expect(result.current.sessions[0].steps).toHaveLength(1);
    });

    it('should update homework session', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ materials: [mockHomeworkMaterial] }),
      });

      const { result } = renderHook(() => useHomeworkSessions());

      await waitFor(() => {
        expect(result.current.loading).toBe(false);
      });

      mockFetch.mockResolvedValueOnce({ ok: true });

      await act(async () => {
        const success = await result.current.updateSession({
          ...result.current.sessions[0],
          steps: [{ id: 's1', description: 'Step 1 Updated', hints: [], studentNotes: 'Done!', completed: true }],
        });
        expect(success).toBe(true);
      });

      expect(mockFetch).toHaveBeenCalledWith('/api/materials', expect.objectContaining({
        method: 'PATCH',
      }));
    });

    it('should delete homework session', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ materials: [mockHomeworkMaterial] }),
      });

      const { result } = renderHook(() => useHomeworkSessions());

      await waitFor(() => {
        expect(result.current.sessions).toHaveLength(1);
      });

      mockFetch.mockResolvedValueOnce({ ok: true });

      await act(async () => {
        const success = await result.current.deleteSession('homework-1');
        expect(success).toBe(true);
      });

      expect(result.current.sessions).toHaveLength(0);
    });
  });

  // ============================================================================
  // autoSaveMaterial
  // ============================================================================
  describe('autoSaveMaterial', () => {
    // C-14/C-15 FIX: autoSaveMaterial now uses upsert pattern (single POST call)
    // and returns boolean instead of void
    it('should save material using upsert pattern', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ material: { id: '1' } }),
      });

      const result = await autoSaveMaterial('mindmap', 'New Mindmap', { nodes: [] });

      expect(result).toBe(true);
      expect(mockFetch).toHaveBeenCalledTimes(1);
      expect(mockFetch).toHaveBeenCalledWith('/api/materials', expect.objectContaining({
        method: 'POST',
      }));
    });

    it('should return false when save fails', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        json: async () => ({ error: 'Failed to save' }),
      });

      const result = await autoSaveMaterial('mindmap', 'Test Mindmap', { nodes: [] });

      expect(result).toBe(false);
    });

    it('should handle fetch errors and return false', async () => {
      mockFetch.mockRejectedValueOnce(new Error('Network error'));

      // Should not throw, returns false on error
      const result = await autoSaveMaterial('quiz', 'Test Quiz', { questions: [] });
      expect(result).toBe(false);
    });
  });

  // ============================================================================
  // Error handling
  // ============================================================================
  describe('error handling', () => {
    it('should handle network errors gracefully', async () => {
      mockFetch.mockRejectedValueOnce(new Error('Network error'));

      const { result } = renderHook(() => useMindmaps());

      await waitFor(() => {
        expect(result.current.loading).toBe(false);
      });

      expect(result.current.mindmaps).toEqual([]);
    });

    it('should return false when delete fails', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          materials: [{
            id: '1',
            toolId: 'test-1',
            toolType: 'mindmap',
            title: 'Test',
            content: { nodes: [] },
            status: 'active',
          }],
        }),
      });

      const { result } = renderHook(() => useMindmaps());

      await waitFor(() => {
        expect(result.current.loading).toBe(false);
      });

      mockFetch.mockResolvedValueOnce({ ok: false, status: 500 });

      await act(async () => {
        const success = await result.current.deleteMindmap('test-1');
        expect(success).toBe(false);
      });
    });
  });
});
