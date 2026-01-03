// ============================================================================
// TOOL TYPES - Unified across voice and chat
// Related: ADR 0009 - Tool Execution Architecture
// ============================================================================

/**
 * All supported tool types in MirrorBuddy
 */
export type ToolType =
  | 'mindmap'      // Mappa mentale interattiva (MarkMap)
  | 'quiz'         // Quiz con domande a risposta multipla
  | 'flashcard'    // Set di flashcard per ripasso (FSRS)
  | 'demo'         // Simulazione HTML/JS interattiva
  | 'search'       // Ricerca web/YouTube
  | 'diagram'      // Diagramma (Mermaid)
  | 'timeline'     // Linea temporale
  | 'summary'      // Riassunto strutturato
  | 'formula'      // Formula matematica (KaTeX)
  | 'chart'        // Grafico (Chart.js)
  | 'webcam'       // Foto da webcam
  | 'pdf'          // PDF caricato
  | 'homework';    // Compiti con metodo maieutico

/**
 * OpenAI function definitions for chat API
 * These are passed to the `tools` parameter in chat completions
 */
export const CHAT_TOOL_DEFINITIONS = [
  {
    type: 'function' as const,
    function: {
      name: 'create_mindmap',
      description: `Crea una mappa mentale con GERARCHIA. OBBLIGATORIO usare parentId per i sotto-nodi.

SBAGLIATO (mappa piatta):
nodes: [{"id":"1","label":"A"},{"id":"2","label":"B"},{"id":"3","label":"C"}]

CORRETTO (mappa gerarchica):
nodes: [
  {"id":"1","label":"Geografia"},
  {"id":"2","label":"Posizione","parentId":"1"},
  {"id":"3","label":"Confini","parentId":"1"},
  {"id":"4","label":"Nord Italia","parentId":"2"}
]

REGOLE:
1. Nodi SENZA parentId = rami principali (max 4-5)
2. Nodi CON parentId = sotto-nodi (OBBLIGATORIO per creare gerarchia)
3. Almeno 2 livelli di profondità`,
      parameters: {
        type: 'object',
        properties: {
          title: {
            type: 'string',
            description: 'Titolo centrale della mappa',
          },
          nodes: {
            type: 'array',
            description: 'Nodi gerarchici. IMPORTANTE: i sotto-nodi DEVONO avere parentId!',
            items: {
              type: 'object',
              properties: {
                id: { type: 'string', description: 'ID univoco (es: "1", "2", "3")' },
                label: { type: 'string', description: 'Testo breve (max 5 parole)' },
                parentId: { type: 'string', description: 'ID del padre. OMETTI SOLO per rami principali, INCLUDI per sotto-nodi!' },
              },
              required: ['id', 'label'],
            },
          },
        },
        required: ['title', 'nodes'],
      },
    },
  },
  {
    type: 'function' as const,
    function: {
      name: 'create_quiz',
      description: 'Crea un quiz interattivo con domande a risposta multipla. Usa questo strumento quando lo studente vuole testare la sua comprensione o ripassare.',
      parameters: {
        type: 'object',
        properties: {
          topic: {
            type: 'string',
            description: 'Argomento del quiz',
          },
          questions: {
            type: 'array',
            description: 'Domande del quiz',
            items: {
              type: 'object',
              properties: {
                question: { type: 'string', description: 'Testo della domanda' },
                options: {
                  type: 'array',
                  items: { type: 'string' },
                  description: 'Opzioni di risposta (4 opzioni)',
                },
                correctIndex: {
                  type: 'number',
                  description: 'Indice della risposta corretta (0-3)',
                },
                explanation: {
                  type: 'string',
                  description: 'Spiegazione della risposta corretta',
                },
              },
              required: ['question', 'options', 'correctIndex'],
            },
          },
        },
        required: ['topic', 'questions'],
      },
    },
  },
  {
    type: 'function' as const,
    function: {
      name: 'create_demo',
      description: 'Crea una simulazione interattiva HTML/JS per visualizzare concetti scientifici o matematici. Usa per dimostrazioni visive come il sistema solare, moto dei proiettili, circuiti elettrici.',
      parameters: {
        type: 'object',
        properties: {
          title: {
            type: 'string',
            description: 'Titolo della simulazione',
          },
          description: {
            type: 'string',
            description: 'Breve descrizione di cosa mostra la demo',
          },
          html: {
            type: 'string',
            description: 'Codice HTML per la struttura',
          },
          css: {
            type: 'string',
            description: 'Codice CSS per lo stile (opzionale)',
          },
          js: {
            type: 'string',
            description: 'Codice JavaScript per l\'interattività (opzionale)',
          },
        },
        required: ['title', 'html'],
      },
    },
  },
  {
    type: 'function' as const,
    function: {
      name: 'web_search',
      description: 'Cerca contenuti educativi su web o YouTube. Usa quando lo studente ha bisogno di risorse esterne, video tutorial, o approfondimenti.',
      parameters: {
        type: 'object',
        properties: {
          query: {
            type: 'string',
            description: 'Query di ricerca',
          },
          type: {
            type: 'string',
            enum: ['web', 'youtube', 'all'],
            description: 'Tipo di ricerca: web, youtube, o entrambi',
          },
        },
        required: ['query'],
      },
    },
  },
  {
    type: 'function' as const,
    function: {
      name: 'create_flashcards',
      description: 'Crea un set di flashcard per il ripasso con spaced repetition. Usa quando lo studente vuole memorizzare definizioni, formule, o concetti.',
      parameters: {
        type: 'object',
        properties: {
          topic: {
            type: 'string',
            description: 'Argomento delle flashcard',
          },
          cards: {
            type: 'array',
            description: 'Le flashcard da creare',
            items: {
              type: 'object',
              properties: {
                front: { type: 'string', description: 'Fronte della carta (domanda)' },
                back: { type: 'string', description: 'Retro della carta (risposta)' },
              },
              required: ['front', 'back'],
            },
          },
        },
        required: ['topic', 'cards'],
      },
    },
  },
  {
    type: 'function' as const,
    function: {
      name: 'create_summary',
      description: 'Crea un riassunto strutturato di un argomento. Usa quando lo studente chiede una sintesi, un ripasso, o vuole i punti chiave.',
      parameters: {
        type: 'object',
        properties: {
          topic: {
            type: 'string',
            description: 'Argomento da riassumere',
          },
          sections: {
            type: 'array',
            description: 'Sezioni del riassunto',
            items: {
              type: 'object',
              properties: {
                title: { type: 'string', description: 'Titolo della sezione' },
                content: { type: 'string', description: 'Contenuto della sezione' },
                keyPoints: {
                  type: 'array',
                  items: { type: 'string' },
                  description: 'Punti chiave della sezione',
                },
              },
              required: ['title', 'content'],
            },
          },
          length: {
            type: 'string',
            enum: ['short', 'medium', 'long'],
            description: 'Lunghezza del riassunto',
          },
        },
        required: ['topic', 'sections'],
      },
    },
  },
  {
    type: 'function' as const,
    function: {
      name: 'open_student_summary',
      description: 'Apre l\'editor per far SCRIVERE un riassunto allo studente. NON genera contenuto automaticamente. Usa quando lo studente dice "devo fare un riassunto" o vuole scrivere lui stesso. Guida lo studente con il metodo maieutico.',
      parameters: {
        type: 'object',
        properties: {
          topic: {
            type: 'string',
            description: 'Argomento del riassunto che lo studente scriverà',
          },
        },
        required: ['topic'],
      },
    },
  },
  {
    type: 'function' as const,
    function: {
      name: 'student_summary_add_comment',
      description: 'Aggiunge un commento inline al riassunto dello studente. Usa per dare feedback su parti specifiche del testo.',
      parameters: {
        type: 'object',
        properties: {
          sectionId: {
            type: 'string',
            enum: ['intro', 'main', 'conclusion'],
            description: 'Sezione del riassunto',
          },
          startOffset: {
            type: 'number',
            description: 'Posizione iniziale del testo da commentare',
          },
          endOffset: {
            type: 'number',
            description: 'Posizione finale del testo da commentare',
          },
          text: {
            type: 'string',
            description: 'Il commento/feedback per lo studente',
          },
        },
        required: ['sectionId', 'startOffset', 'endOffset', 'text'],
      },
    },
  },
  {
    type: 'function' as const,
    function: {
      name: 'create_diagram',
      description: 'Crea un diagramma Mermaid (flowchart, sequence, class, ER). Usa per visualizzare processi, algoritmi, o relazioni tra entità.',
      parameters: {
        type: 'object',
        properties: {
          topic: {
            type: 'string',
            description: 'Argomento del diagramma',
          },
          diagramType: {
            type: 'string',
            enum: ['flowchart', 'sequence', 'class', 'er'],
            description: 'Tipo di diagramma',
          },
          mermaidCode: {
            type: 'string',
            description: 'Codice Mermaid per il diagramma',
          },
        },
        required: ['topic', 'diagramType', 'mermaidCode'],
      },
    },
  },
  {
    type: 'function' as const,
    function: {
      name: 'create_timeline',
      description: 'Crea una linea del tempo per eventi storici o sequenze temporali. Ideale per storia e cronologie.',
      parameters: {
        type: 'object',
        properties: {
          topic: {
            type: 'string',
            description: 'Argomento della timeline (es. "Seconda Guerra Mondiale")',
          },
          period: {
            type: 'string',
            description: 'Periodo coperto (es. "1939-1945")',
          },
          events: {
            type: 'array',
            description: 'Eventi della timeline',
            items: {
              type: 'object',
              properties: {
                date: { type: 'string', description: 'Data dell\'evento' },
                title: { type: 'string', description: 'Titolo dell\'evento' },
                description: { type: 'string', description: 'Descrizione dell\'evento' },
              },
              required: ['date', 'title'],
            },
          },
        },
        required: ['topic', 'events'],
      },
    },
  },
  {
    type: 'function' as const,
    function: {
      name: 'search_archive',
      description: 'Cerca materiali salvati nell\'archivio dello studente (mappe mentali, quiz, flashcard, riassunti, demo, compiti). Usa quando lo studente chiede di rivedere qualcosa che ha già creato o quando vuoi recuperare contenuti precedenti per la conversazione.',
      parameters: {
        type: 'object',
        properties: {
          query: {
            type: 'string',
            description: 'Testo da cercare nei titoli e contenuti dei materiali',
          },
          toolType: {
            type: 'string',
            enum: ['mindmap', 'quiz', 'flashcard', 'summary', 'demo', 'homework', 'diagram', 'timeline'],
            description: 'Tipo di materiale da cercare (opzionale)',
          },
          subject: {
            type: 'string',
            description: 'Materia dei materiali da cercare (opzionale)',
          },
        },
        required: [],
      },
    },
  },
] as const;

/**
 * Tool state for real-time UI updates
 */
export interface ToolState {
  id: string;
  type: ToolType;
  status: 'initializing' | 'building' | 'completed' | 'error';
  progress: number; // 0-1
  content: unknown;
  error?: string;
  createdAt: Date;
}

/**
 * Context passed to tool handlers
 */
export interface ToolContext {
  sessionId?: string;
  userId?: string;
  maestroId?: string;
  conversationId?: string;
}

/**
 * Result of tool execution
 */
export interface ToolExecutionResult {
  success: boolean;
  toolId: string;
  toolType: ToolType;
  data?: unknown;
  error?: string;
}

/**
 * Tool event types - matches tool-events.ts
 * Re-exported for convenience
 */
export type ToolEventType =
  | 'tool:created'      // New tool started
  | 'tool:update'       // Incremental update (content chunk)
  | 'tool:complete'     // Tool finished building
  | 'tool:error'        // Error during creation
  | 'tool:cancelled';   // User cancelled

// ============================================================================
// Mindmap specific types
// ============================================================================

export interface MindmapNode {
  id: string;
  label: string;
  parentId?: string | null;
}

export interface MindmapData {
  title: string; // ADR 0020: Standardized on 'title' (was 'topic')
  topic?: string; // Deprecated: for backward compatibility
  nodes: MindmapNode[];
  markdown?: string;
}

// ============================================================================
// Quiz specific types
// ============================================================================

export interface QuizQuestion {
  question: string;
  options: string[];
  correctIndex: number;
  explanation?: string;
}

export interface QuizData {
  topic: string;
  questions: QuizQuestion[];
}

// ============================================================================
// Demo specific types
// ============================================================================

export interface DemoData {
  title: string;
  description?: string;
  html: string;
  css?: string;
  js?: string;
}

// ============================================================================
// Search specific types
// ============================================================================

export interface SearchResult {
  type: 'web' | 'youtube';
  title: string;
  url: string;
  description?: string;
  thumbnail?: string;
  duration?: string; // YouTube only
}

export interface SearchData {
  query: string;
  searchType: 'web' | 'youtube' | 'all';
  results: SearchResult[];
}

// ============================================================================
// Flashcard specific types
// ============================================================================

export interface FlashcardItem {
  front: string;
  back: string;
}

export interface FlashcardData {
  topic: string;
  cards: FlashcardItem[];
}

// ============================================================================
// Summary specific types
// ============================================================================

export interface SummarySection {
  title: string;
  content: string;
  keyPoints?: string[];
}

export interface SummaryData {
  topic: string;
  sections: SummarySection[];
  length?: 'short' | 'medium' | 'long';
}

// ============================================================================
// Student Summary types (maieutic method - student writes, AI guides)
// Issue #70: Collaborative summary writing
// ============================================================================

/**
 * Inline comment from Maestro on student's text
 */
export interface InlineComment {
  id: string;
  startOffset: number;
  endOffset: number;
  text: string;
  maestroId: string;
  createdAt: Date;
  resolved?: boolean;
}

/**
 * A guided section in student's summary
 */
export interface StudentSummarySection {
  id: string;
  heading: string;
  guidingQuestion: string;
  content: string;
  comments: InlineComment[];
}

/**
 * Student-written summary
 */
export interface StudentSummaryData {
  id: string;
  title: string;
  topic: string;
  sections: StudentSummarySection[];
  wordCount: number;
  createdAt: Date;
  lastModifiedAt: Date;
  maestroId?: string;
  sessionId?: string;
}

/**
 * Default guided structure template
 */
export const SUMMARY_STRUCTURE_TEMPLATE: Omit<StudentSummarySection, 'comments'>[] = [
  {
    id: 'intro',
    heading: 'Introduzione',
    guidingQuestion: 'Di cosa parla questo argomento? Qual è il tema principale?',
    content: '',
  },
  {
    id: 'main',
    heading: 'Sviluppo',
    guidingQuestion: 'Quali sono i punti chiave? Cosa hai capito di importante?',
    content: '',
  },
  {
    id: 'conclusion',
    heading: 'Conclusione',
    guidingQuestion: 'Quali conclusioni puoi trarre? Cosa è importante ricordare?',
    content: '',
  },
];

/**
 * Creates a new empty student summary
 */
export function createEmptyStudentSummary(
  topic: string,
  maestroId?: string,
  sessionId?: string
): StudentSummaryData {
  const now = new Date();
  return {
    id: crypto.randomUUID(),
    title: topic,
    topic,
    sections: SUMMARY_STRUCTURE_TEMPLATE.map((section) => ({
      ...section,
      comments: [],
    })),
    wordCount: 0,
    createdAt: now,
    lastModifiedAt: now,
    maestroId,
    sessionId,
  };
}

// ============================================================================
// Diagram specific types
// ============================================================================

export interface DiagramData {
  topic: string;
  diagramType: 'flowchart' | 'sequence' | 'class' | 'er';
  mermaidCode: string;
}

// ============================================================================
// Timeline specific types
// ============================================================================

export interface TimelineEvent {
  date: string;
  title: string;
  description?: string;
}

export interface TimelineData {
  topic: string;
  period?: string;
  events: TimelineEvent[];
}
