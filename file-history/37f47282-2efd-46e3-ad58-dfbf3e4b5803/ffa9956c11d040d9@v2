/**
 * Hook for saved materials (mindmaps, quizzes, flashcards)
 *
 * Replaces localStorage usage with database API.
 * Issue #64: Consolidate localStorage to Database
 */

import { useState, useEffect, useCallback } from 'react';
import { logger } from '@/lib/logger';
import type { ToolType } from '@/types/tools';
import type { Subject } from '@/types';

// Material types matching the API
export interface SavedMaterial {
  id: string;
  toolId: string;
  toolType: ToolType;
  title: string;
  content: Record<string, unknown>;
  maestroId?: string;
  sessionId?: string;
  subject?: string;
  preview?: string;
  status: 'active' | 'archived' | 'deleted';
  userRating?: number;
  isBookmarked: boolean;
  viewCount: number;
  createdAt: string;
  updatedAt: string;
}

// Mindmap-specific type - ADR 0020
export interface SavedMindmap {
  id: string;
  title: string;
  nodes: MindmapNode[];
  markdown?: string; // Pre-generated markdown for rendering
  subject: Subject;
  createdAt: Date;
  maestroId?: string;
}

interface MindmapNode {
  id: string;
  label: string;
  children?: MindmapNode[];
  icon?: string;
  color?: string;
}

// Quiz-specific type
export interface SavedQuiz {
  id: string;
  title: string;
  subject: string;
  questions: QuizQuestion[];
  createdAt: Date;
}

interface QuizQuestion {
  question: string;
  options: string[];
  correctIndex: number;
  explanation?: string;
}

// Flashcard deck type
export interface SavedFlashcardDeck {
  id: string;
  name: string;
  subject: string;
  cards: FlashcardCard[];
  createdAt: Date;
}

interface FlashcardCard {
  front: string;
  back: string;
}

// Homework-specific types
export interface HomeworkStep {
  id: string;
  description: string;
  hints: string[];
  studentNotes: string;
  completed: boolean;
}

export interface SavedHomework {
  id: string;
  title: string;
  subject: Subject;
  problemType: string;
  photoUrl?: string;
  steps: HomeworkStep[];
  createdAt: Date;
  completedAt?: Date;
}

// Get default user ID - will be replaced by proper auth
function getUserId(): string {
  // In production, this would come from auth context
  // For now, use a session-based ID
  if (typeof window === 'undefined') return 'default-user';

  let userId = sessionStorage.getItem('mirrorbuddy-user-id');
  if (!userId) {
    userId = `user-${crypto.randomUUID()}`;
    sessionStorage.setItem('mirrorbuddy-user-id', userId);
  }
  return userId;
}

/**
 * Fetch materials from API
 */
async function fetchMaterials(
  toolType: ToolType,
  userId: string
): Promise<SavedMaterial[]> {
  try {
    const response = await fetch(
      `/api/materials?userId=${userId}&toolType=${toolType}&status=active`
    );
    if (!response.ok) {
      throw new Error(`API error: ${response.status}`);
    }
    const data = await response.json();
    return data.materials || [];
  } catch (error) {
    logger.error('Failed to fetch materials', { error, toolType });
    return [];
  }
}

/**
 * Save material to API
 */
async function saveMaterialToAPI(
  userId: string,
  toolType: ToolType,
  title: string,
  content: Record<string, unknown>,
  options?: {
    subject?: string;
    maestroId?: string;
    preview?: string;
  }
): Promise<SavedMaterial | null> {
  try {
    const toolId = crypto.randomUUID();
    const response = await fetch('/api/materials', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId,
        toolId,
        toolType,
        title,
        content,
        ...options,
      }),
    });
    if (!response.ok) {
      throw new Error(`API error: ${response.status}`);
    }
    const data = await response.json();
    return data.material;
  } catch (error) {
    logger.error('Failed to save material', { error, toolType, title });
    return null;
  }
}

/**
 * Delete material via API
 */
async function deleteMaterialFromAPI(toolId: string): Promise<boolean> {
  try {
    const response = await fetch(`/api/materials?toolId=${toolId}`, {
      method: 'DELETE',
    });
    return response.ok;
  } catch (error) {
    logger.error('Failed to delete material', { error, toolId });
    return false;
  }
}

/**
 * Update material via API
 */
async function updateMaterialInAPI(
  toolId: string,
  content: Record<string, unknown>,
  title?: string
): Promise<boolean> {
  try {
    const response = await fetch('/api/materials', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ toolId, content, title }),
    });
    return response.ok;
  } catch (error) {
    logger.error('Failed to update material', { error, toolId });
    return false;
  }
}

/**
 * Hook for mindmaps
 */
export function useMindmaps() {
  const [mindmaps, setMindmaps] = useState<SavedMindmap[]>([]);
  const [loading, setLoading] = useState(true);
  const userId = getUserId();

  // Load mindmaps from API - ADR 0020: Extract markdown and handle topic->title compat
  const loadMindmaps = useCallback(async () => {
    setLoading(true);
    const materials = await fetchMaterials('mindmap', userId);
    const mapped: SavedMindmap[] = materials.map((m) => {
      const content = m.content as {
        nodes?: MindmapNode[];
        markdown?: string;
        title?: string;
        topic?: string;
      };
      return {
        id: m.toolId,
        // Prefer title from content, fallback to topic for backward compat
        title: m.title || content.title || content.topic || 'Untitled',
        nodes: content.nodes || [],
        markdown: content.markdown,
        subject: (m.subject || 'general') as Subject,
        createdAt: new Date(m.createdAt),
        maestroId: m.maestroId,
      };
    });
    setMindmaps(mapped);
    setLoading(false);
  }, [userId]);

  /* eslint-disable react-hooks/set-state-in-effect -- ADR 0015: Data loading pattern, see docs/adr/0015-database-first-architecture.md */
  useEffect(() => {
    loadMindmaps();
  }, [loadMindmaps]);
  /* eslint-enable react-hooks/set-state-in-effect */

  // Save mindmap - ADR 0020: Include markdown in content
  const saveMindmap = useCallback(
    async (mindmap: Omit<SavedMindmap, 'id' | 'createdAt'>) => {
      const saved = await saveMaterialToAPI(
        userId,
        'mindmap',
        mindmap.title,
        {
          nodes: mindmap.nodes,
          markdown: mindmap.markdown,
          title: mindmap.title, // Store title in content for redundancy
        },
        { subject: mindmap.subject, maestroId: mindmap.maestroId }
      );
      if (saved) {
        await loadMindmaps();
      }
      return saved;
    },
    [userId, loadMindmaps]
  );

  // Delete mindmap
  const deleteMindmap = useCallback(
    async (id: string) => {
      const success = await deleteMaterialFromAPI(id);
      if (success) {
        setMindmaps((prev) => prev.filter((m) => m.id !== id));
      }
      return success;
    },
    []
  );

  return { mindmaps, loading, saveMindmap, deleteMindmap, reload: loadMindmaps };
}

/**
 * Hook for quizzes
 */
export function useQuizzes() {
  const [quizzes, setQuizzes] = useState<SavedQuiz[]>([]);
  const [loading, setLoading] = useState(true);
  const userId = getUserId();

  const loadQuizzes = useCallback(async () => {
    setLoading(true);
    const materials = await fetchMaterials('quiz', userId);
    const mapped: SavedQuiz[] = materials.map((m) => ({
      id: m.toolId,
      title: m.title,
      subject: m.subject || '',
      questions: (m.content as { questions?: QuizQuestion[] }).questions || [],
      createdAt: new Date(m.createdAt),
    }));
    setQuizzes(mapped);
    setLoading(false);
  }, [userId]);

  /* eslint-disable react-hooks/set-state-in-effect -- ADR 0015: Data loading pattern, see docs/adr/0015-database-first-architecture.md */
  useEffect(() => {
    loadQuizzes();
  }, [loadQuizzes]);
  /* eslint-enable react-hooks/set-state-in-effect */

  const saveQuiz = useCallback(
    async (quiz: { title: string; subject: string; questions: QuizQuestion[] }) => {
      const saved = await saveMaterialToAPI(
        userId,
        'quiz',
        quiz.title,
        { questions: quiz.questions },
        { subject: quiz.subject }
      );
      if (saved) {
        await loadQuizzes();
      }
      return saved;
    },
    [userId, loadQuizzes]
  );

  const deleteQuiz = useCallback(async (id: string) => {
    const success = await deleteMaterialFromAPI(id);
    if (success) {
      setQuizzes((prev) => prev.filter((q) => q.id !== id));
    }
    return success;
  }, []);

  return { quizzes, loading, saveQuiz, deleteQuiz, reload: loadQuizzes };
}

/**
 * Hook for flashcard decks
 */
export function useFlashcardDecks() {
  const [decks, setDecks] = useState<SavedFlashcardDeck[]>([]);
  const [loading, setLoading] = useState(true);
  const userId = getUserId();

  const loadDecks = useCallback(async () => {
    setLoading(true);
    const materials = await fetchMaterials('flashcard', userId);
    const mapped: SavedFlashcardDeck[] = materials.map((m) => ({
      id: m.toolId,
      name: m.title,
      subject: m.subject || '',
      cards: (m.content as { cards?: FlashcardCard[] }).cards || [],
      createdAt: new Date(m.createdAt),
    }));
    setDecks(mapped);
    setLoading(false);
  }, [userId]);

  /* eslint-disable react-hooks/set-state-in-effect -- ADR 0015: Data loading pattern, see docs/adr/0015-database-first-architecture.md */
  useEffect(() => {
    loadDecks();
  }, [loadDecks]);
  /* eslint-enable react-hooks/set-state-in-effect */

  const saveDeck = useCallback(
    async (deck: { name: string; subject: string; cards: FlashcardCard[] }) => {
      const saved = await saveMaterialToAPI(
        userId,
        'flashcard',
        deck.name,
        { cards: deck.cards },
        { subject: deck.subject }
      );
      if (saved) {
        await loadDecks();
      }
      return saved;
    },
    [userId, loadDecks]
  );

  const deleteDeck = useCallback(async (id: string) => {
    const success = await deleteMaterialFromAPI(id);
    if (success) {
      setDecks((prev) => prev.filter((d) => d.id !== id));
    }
    return success;
  }, []);

  return { decks, loading, saveDeck, deleteDeck, reload: loadDecks };
}

/**
 * Hook for homework sessions
 */
export function useHomeworkSessions() {
  const [sessions, setSessions] = useState<SavedHomework[]>([]);
  const [loading, setLoading] = useState(true);
  const userId = getUserId();

  const loadSessions = useCallback(async () => {
    setLoading(true);
    const materials = await fetchMaterials('homework', userId);
    const mapped: SavedHomework[] = materials.map((m) => {
      const content = m.content as {
        steps?: HomeworkStep[];
        problemType?: string;
        photoUrl?: string;
        completedAt?: string;
      };
      return {
        id: m.toolId,
        title: m.title,
        subject: (m.subject || 'mathematics') as Subject,
        problemType: content.problemType || 'Esercizio',
        photoUrl: content.photoUrl,
        steps: content.steps || [],
        createdAt: new Date(m.createdAt),
        completedAt: content.completedAt ? new Date(content.completedAt) : undefined,
      };
    });
    setSessions(mapped);
    setLoading(false);
  }, [userId]);

  /* eslint-disable react-hooks/set-state-in-effect -- ADR 0015: Data loading pattern, see docs/adr/0015-database-first-architecture.md */
  useEffect(() => {
    loadSessions();
  }, [loadSessions]);
  /* eslint-enable react-hooks/set-state-in-effect */

  const saveSession = useCallback(
    async (homework: Omit<SavedHomework, 'id' | 'createdAt'>) => {
      const saved = await saveMaterialToAPI(
        userId,
        'homework',
        homework.title,
        {
          steps: homework.steps,
          problemType: homework.problemType,
          photoUrl: homework.photoUrl,
          completedAt: homework.completedAt?.toISOString(),
        },
        { subject: homework.subject }
      );
      if (saved) {
        await loadSessions();
      }
      return saved;
    },
    [userId, loadSessions]
  );

  const updateSession = useCallback(
    async (homework: SavedHomework) => {
      const success = await updateMaterialInAPI(
        homework.id,
        {
          steps: homework.steps,
          problemType: homework.problemType,
          photoUrl: homework.photoUrl,
          completedAt: homework.completedAt?.toISOString(),
        },
        homework.title
      );
      if (success) {
        setSessions((prev) =>
          prev.map((s) => (s.id === homework.id ? homework : s))
        );
      }
      return success;
    },
    []
  );

  const deleteSession = useCallback(async (id: string) => {
    const success = await deleteMaterialFromAPI(id);
    if (success) {
      setSessions((prev) => prev.filter((s) => s.id !== id));
    }
    return success;
  }, []);

  return {
    sessions,
    loading,
    saveSession,
    updateSession,
    deleteSession,
    reload: loadSessions,
  };
}

// Demo/HTML snippet type (migrated from useHTMLSnippetsStore)
export interface SavedDemo {
  id: string;
  title: string;
  description?: string;
  code: string;
  subject?: string;
  maestroId?: string;
  tags: string[];
  createdAt: Date;
}

/**
 * Hook for interactive demos (HTML snippets)
 * Replaces useHTMLSnippetsStore (Zustand) with database API
 * ADR 0015: Database-First Architecture
 */
export function useDemos() {
  const [demos, setDemos] = useState<SavedDemo[]>([]);
  const [loading, setLoading] = useState(true);
  const userId = getUserId();

  const loadDemos = useCallback(async () => {
    setLoading(true);
    const materials = await fetchMaterials('demo', userId);
    const mapped: SavedDemo[] = materials.map((m) => {
      const content = m.content as {
        code?: string;
        html?: string;
        css?: string;
        js?: string;
        description?: string;
        tags?: string[];
      };
      // Support both legacy 'code' format and new 'html/css/js' format
      let code = content.code || '';
      if (!code && content.html) {
        // Reconstruct full HTML from components
        code = content.html;
        if (content.css) {
          code = `<style>${content.css}</style>\n${code}`;
        }
        if (content.js) {
          code = `${code}\n<script>${content.js}</script>`;
        }
      }
      return {
        id: m.toolId,
        title: m.title,
        description: content.description,
        code,
        subject: m.subject,
        maestroId: m.maestroId,
        tags: content.tags || [],
        createdAt: new Date(m.createdAt),
      };
    });
    setDemos(mapped);
    setLoading(false);
  }, [userId]);

  /* eslint-disable react-hooks/set-state-in-effect -- ADR 0015: Data loading pattern, see docs/adr/0015-database-first-architecture.md */
  useEffect(() => {
    loadDemos();
  }, [loadDemos]);
  /* eslint-enable react-hooks/set-state-in-effect */

  const saveDemo = useCallback(
    async (demo: Omit<SavedDemo, 'id' | 'createdAt'>) => {
      const saved = await saveMaterialToAPI(
        userId,
        'demo',
        demo.title,
        { code: demo.code, description: demo.description, tags: demo.tags },
        { subject: demo.subject, maestroId: demo.maestroId }
      );
      if (saved) {
        await loadDemos();
      }
      return saved;
    },
    [userId, loadDemos]
  );

  const deleteDemo = useCallback(async (id: string) => {
    const success = await deleteMaterialFromAPI(id);
    if (success) {
      setDemos((prev) => prev.filter((d) => d.id !== id));
    }
    return success;
  }, []);

  return { demos, loading, saveDemo, deleteDemo, reload: loadDemos };
}

/**
 * Generic hook for saved tools (summaries, etc.)
 * Works with any ToolType and returns raw SavedMaterial objects
 */
export function useSavedTools(toolType: ToolType) {
  const [tools, setTools] = useState<SavedMaterial[]>([]);
  const [loading, setLoading] = useState(true);
  const userId = getUserId();

  const loadTools = useCallback(async () => {
    setLoading(true);
    const materials = await fetchMaterials(toolType, userId);
    setTools(materials);
    setLoading(false);
  }, [userId, toolType]);

  /* eslint-disable react-hooks/set-state-in-effect -- ADR 0015: Data loading pattern, see docs/adr/0015-database-first-architecture.md */
  useEffect(() => {
    loadTools();
  }, [loadTools]);
  /* eslint-enable react-hooks/set-state-in-effect */

  const deleteTool = useCallback(async (id: string) => {
    const success = await deleteMaterialFromAPI(id);
    if (success) {
      setTools((prev) => prev.filter((t) => t.toolId !== id));
    }
    return success;
  }, []);

  return { tools, loading, deleteTool, reload: loadTools };
}

/**
 * Auto-save utility for tool results (used by tool-result-display.tsx)
 * C-14 FIX: Now accepts toolId to enable proper upsert behavior
 * C-15 FIX: Removed silent failure - logs errors properly
 */
export async function autoSaveMaterial(
  toolType: ToolType,
  title: string,
  content: Record<string, unknown>,
  options?: { subject?: string; toolId?: string }
): Promise<boolean> {
  if (typeof window === 'undefined') return false;

  try {
    const userId = getUserId();
    // C-14 FIX: Use provided toolId or generate one based on content hash
    // This ensures the same content gets the same ID for proper upsert
    const toolId = options?.toolId || generateContentHash(toolType, title, content);

    const result = await saveMaterialToAPIWithId(userId, toolId, toolType, title, content, options);
    return result !== null;
  } catch (error) {
    // C-15 FIX: Log error instead of silent failure
    logger.error('Auto-save material failed', {
      toolType,
      title,
      error: error instanceof Error ? error.message : String(error)
    });
    return false;
  }
}

/**
 * Generate a stable hash for content to use as toolId
 * This ensures the same content always gets the same ID (for upsert)
 */
function generateContentHash(toolType: string, title: string, content: Record<string, unknown>): string {
  const str = `${toolType}-${title}-${JSON.stringify(content)}`;
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash; // Convert to 32bit integer
  }
  return `auto-${Math.abs(hash).toString(36)}`;
}

/**
 * Save material with explicit toolId (for upsert behavior)
 */
async function saveMaterialToAPIWithId(
  userId: string,
  toolId: string,
  toolType: ToolType,
  title: string,
  content: Record<string, unknown>,
  options?: { subject?: string; maestroId?: string; preview?: string }
): Promise<SavedMaterial | null> {
  try {
    const response = await fetch('/api/materials', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId,
        toolId,
        toolType,
        title,
        content,
        ...options,
      }),
    });
    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(`API error: ${response.status} - ${JSON.stringify(errorData)}`);
    }
    const data = await response.json();
    return data.material;
  } catch (error) {
    logger.error('Failed to save material', {
      error: error instanceof Error ? error.message : String(error),
      toolType,
      title
    });
    return null;
  }
}
