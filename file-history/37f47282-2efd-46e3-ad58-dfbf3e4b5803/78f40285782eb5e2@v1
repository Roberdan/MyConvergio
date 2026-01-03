/**
 * MirrorBuddy Intent Detection System
 *
 * Analyzes student messages to determine:
 * 1. What the student needs (subject help, method help, emotional support)
 * 2. Who should respond (Maestro, Coach, Buddy)
 *
 * Part of the Support Triangle routing system.
 * Related: #24 MirrorBuddy Issue, ManifestoEdu.md
 */

import type { Subject, CharacterType } from '@/types';

// ============================================================================
// TYPES
// ============================================================================

/**
 * Detected intent from student message.
 */
export interface DetectedIntent {
  /** Primary intent type */
  type: IntentType;
  /** Confidence score (0-1) */
  confidence: number;
  /** Detected subject if academic */
  subject?: Subject;
  /** Detected topic within subject */
  topic?: string;
  /** Emotional indicators if any */
  emotionalIndicators?: EmotionalIndicator[];
  /** Recommended character to respond */
  recommendedCharacter: CharacterType;
  /** Reason for recommendation */
  reason: string;
  /** Tool type if tool_request intent */
  toolType?: ToolType;
}

/**
 * Intent types that can be detected.
 */
export type IntentType =
  | 'academic_help' // Needs subject explanation
  | 'method_help' // Needs study method/organization help
  | 'emotional_support' // Needs peer support/validation
  | 'crisis' // Urgent emotional distress
  | 'general_chat' // Casual conversation
  | 'tool_request' // Wants to create flashcards, mindmaps, etc.
  | 'tech_support'; // Needs help with app features/configuration (Issue #16)

/**
 * Tool types that can be created via conversation.
 */
export type ToolType = 'mindmap' | 'quiz' | 'flashcard' | 'demo';

/**
 * Emotional indicators detected in message.
 */
export type EmotionalIndicator =
  | 'frustration'
  | 'anxiety'
  | 'sadness'
  | 'loneliness'
  | 'overwhelm'
  | 'confusion'
  | 'excitement'
  | 'curiosity';

// ============================================================================
// PATTERN DEFINITIONS
// ============================================================================

/**
 * Subject detection patterns (Italian).
 */
const SUBJECT_PATTERNS: Record<Subject, RegExp[]> = {
  mathematics: [
    /\b(matematica|mate|algebra|geometria|equazion[ei]|funzion[ei]|derivat[ae]|integral[ei]|logaritm[oi]|esponenzial[ei]|trigonometria|percentual[ei])\b/i,
    /\b(numeri|calcol[oi]|formul[ae]|problem[ai]|operazion[ei])\b/i,
  ],
  physics: [
    /\b(fisica|cinematica|dinamica|termodinamica|elettromagnetismo|ottica|onde|gravitazione|meccanica)\b/i,
    /\b(newton|joule|watt|velocità|accelerazione|forza|energia|lavoro)\b/i,
  ],
  chemistry: [
    /\b(chimica|molecol[ae]|atom[oi]|reazion[ei]|element[oi]|tavola periodica|legami|ossidazione)\b/i,
    /\b(acido|base|ph|soluzioni|concentrazione)\b/i,
  ],
  biology: [
    /\b(biologia|cellul[ae]|dna|rna|evoluzione|genetica|ecologia|fotosintesi|metabolismo)\b/i,
    /\b(organi|tessuti|mitosi|meiosi|proteine|enzimi)\b/i,
  ],
  history: [
    /\b(storia|storico|guerra|rivoluzione|impero|medioevo|rinascimento|illuminismo|risorgimento)\b/i,
    /\b(romani|greci|egizi|napoleone|fascismo|nazismo|guerra mondiale)\b/i,
  ],
  geography: [
    /\b(geografia|geografico|continenti|paesi|capitali|fiumi|montagne|clima|popolazione)\b/i,
    /\b(europa|asia|africa|america|oceania|italia|regioni)\b/i,
  ],
  italian: [
    /\b(italiano|grammatica|analisi (logica|grammaticale|del periodo)|letteratura|dante|manzoni|leopardi)\b/i,
    /\b(verbi|nomi|aggettivi|complementi|proposizioni|tema|riassunto)\b/i,
  ],
  english: [
    /\b(inglese|english|grammar|vocabulary|reading|writing|speaking)\b/i,
    /\b(verbs|tenses|present|past|future|conditional)\b/i,
  ],
  art: [
    /\b(arte|artistica|pittura|scultura|architettura|rinascimento|barocco|impressionismo)\b/i,
    /\b(leonardo|michelangelo|raffaello|caravaggio|van gogh|monet)\b/i,
  ],
  music: [
    /\b(musica|musicale|note|spartito|strumento|compositore|orchestra|opera)\b/i,
    /\b(mozart|beethoven|bach|verdi|melodia|armonia|ritmo)\b/i,
  ],
  civics: [
    /\b(educazione civica|cittadinanza|costituzione|diritti|doveri|democrazia|parlamento)\b/i,
    /\b(leggi|stato|governo|elezioni|cittadino)\b/i,
  ],
  economics: [
    /\b(economia|economica|mercato|domanda|offerta|pil|inflazione|bilancio)\b/i,
    /\b(azienda|impresa|costi|ricavi|profitto)\b/i,
  ],
  computerScience: [
    /\b(informatica|programmazione|coding|algoritmo|computer|software|hardware)\b/i,
    /\b(python|java|html|css|javascript|database|variabili)\b/i,
  ],
  health: [
    /\b(educazione (alla )?salute|igiene|alimentazione|nutrizione|prevenzione)\b/i,
    /\b(vitamine|proteine|carboidrati|grassi|calorie)\b/i,
  ],
  philosophy: [
    /\b(filosofia|filosofico|socrate|platone|aristotele|kant|hegel|nietzsche)\b/i,
    /\b(etica|metafisica|epistemologia|logica|essere|pensiero)\b/i,
  ],
  internationalLaw: [
    /\b(diritto internazionale|trattati|onu|unione europea|convenzioni)\b/i,
    /\b(nazioni unite|diritti umani|corte internazionale)\b/i,
  ],
};

/**
 * Emotional support indicators (Italian).
 */
const EMOTIONAL_PATTERNS: Record<EmotionalIndicator, RegExp[]> = {
  frustration: [
    /\b(non ce la faccio|non capisco|è impossibile|stufo|stuf[ao]|odio|mi arrendo)\b/i,
    /\b(che palle|che schifo|sono incapace|non sono capace)\b/i,
  ],
  anxiety: [
    /\b(ansia|ansios[oa]|preoccupat[oa]|paura|panico|stress|stressat[oa])\b/i,
    /\b(ho paura|mi spaventa|non riesco a dormire|sono agitat[oa])\b/i,
  ],
  sadness: [
    /\b(trist[oe]|depresso|depressa|giù|male|piango|piangere)\b/i,
    /\b(mi sento male|sto male|non ho voglia|non mi va)\b/i,
  ],
  loneliness: [
    /\b(sol[oa]|isolat[oa]|nessuno mi capisce|nessuno mi aiuta)\b/i,
    /\b(non ho amici|sono divers[oa]|mi sento esclus[oa])\b/i,
  ],
  overwhelm: [
    /\b(troppo|troppe cose|non so da dove iniziare|sopraffatt[oa])\b/i,
    /\b(non ho tempo|sono in ritardo|devo fare tutto)\b/i,
  ],
  confusion: [
    /\b(confus[oa]|non ho capito|non capisco|cosa significa|come funziona)\b/i,
    /\b(perché|spiegami|non è chiaro|mi sono pers[oa])\b/i,
  ],
  excitement: [
    /\b(fantastico|bellissimo|ce l'ho fatta|ho capito|evviva)\b/i,
    /\b(che bello|finalmente|sono content[oa]|felice)\b/i,
  ],
  curiosity: [
    /\b(mi piacerebbe sapere|sono curios[oa]|come mai|perché|interessante)\b/i,
    /\b(dimmi di più|racconta|spiega)\b/i,
  ],
};

/**
 * Method/organization help patterns (Italian).
 */
const METHOD_PATTERNS: RegExp[] = [
  /\b(come (faccio|posso|devo) studiare|metodo di studio|organizzare|organizzazione)\b/i,
  /\b(mappa (mentale|concettuale)|flashcard|riassunto|schema|appunti)\b/i,
  /\b(non so (come|da dove) iniziare|come mi organizzo|come preparo)\b/i,
  /\b(tecnica|strategia|consiglio per studiare|memorizzare|ricordare)\b/i,
  /\b(tempo|gestione del tempo|quanto tempo|quando studiare)\b/i,
  /\b(concentrazione|concentrarmi|distrarsi|distra[ez]ione)\b/i,
];

/**
 * Tool request patterns (Italian).
 */
const TOOL_PATTERNS: RegExp[] = [
  /\b(crea(mi)?|fai|genera|prepara) (una )?(mappa|flashcard|quiz|schema)\b/i,
  /\b(voglio|vorrei) (una )?(mappa|flashcard|quiz|schema)\b/i,
  /\b(mi (aiuti|fai) (a fare|con) (le )?flashcard)\b/i,
];

/**
 * Technical support patterns (Italian).
 * Detects when student needs help with app features/configuration.
 * Issue #16: Tech support handled by student's preferred coach.
 *
 * IMPORTANT: Patterns must be specific to app/platform context.
 * Generic patterns like "come posso" would match study method questions.
 */
const TECH_SUPPORT_PATTERNS: RegExp[] = [
  // App-specific navigation (bidirectional - app context can appear before or after question)
  /\b(app|applicazione|sito|mirrorbuddy|piattaforma)\b/i,
  /\b(come si usa|come (funziona|uso) (l'|la )?app)\b/i,

  // Voice/audio features (bidirectional matching)
  /\b(voce|microfono|audio|chiamat[ae] vocal[ei])\b/i,

  // Settings and configuration (explicit settings words)
  /\b(impostazion[ei]|settings?|config|preferenz[ae])\b/i,

  // Theme/contrast settings
  /\b(tema|scuro|chiaro|dark mode|light mode)\b.*\b(cambi|attiv|dove|come)\b/i,
  /\b(cambi|attiv)\w*\b.*\b(tema|scuro|chiaro)\b/i,

  // Font and accessibility features
  /\b(font|carattere|opendyslexic)\b.*\b(cambiare|attivare|dove)\b/i,
  /\b(modalit[àa])\b.*\b(dislessia|adhd|accessibilit[àa])\b/i,
  /\b(dislessia|adhd)\b.*\b(attivare|funzionalit[àa]|opzioni|modalit[àa])\b/i,

  // Timer Pomodoro (app feature)
  /\b(timer|pomodoro)\b/i,

  // Notifications
  /\b(notific[ah]e?|promemoria|avvis[oi])\b.*\b(attivare|disattivare|non arrivano|dove)\b/i,
  /\b(notific[ah]e?)\b.*\b(non|come|dove)\b/i,

  // Account and data
  /\b(account|profilo|login|accesso|password)\b.*\b(creare|cambiare|recuperare|dove)\b/i,
  /\b(esport|scaric|download)\b.*\b(dati|progressi)\b/i,
  /\b(cancell|elimin)\b.*\b(dati|account)\b/i,
  /\b(genitor[ei]|parent|dashboard)\b.*\b(accesso|vedere|dove|come)\b/i,

  // Gamification
  /\b(xp|punti esperienza)\b/i,
  /\b(streak)\b/i,
  /\b(badge|traguard[oi]|achievement)\b/i,

  // General tech issues (requires explicit problem words)
  /\b(bug|errore|problema tecnico|bloccato)\b/i,
  /\b(non (carica|funziona|si apre|risponde|va))\b/i,
  /\b(lent[ao]|crash)\b/i,
];

/**
 * Tool type detection patterns (Italian).
 * Used to distinguish which specific tool is being requested.
 */
const TOOL_TYPE_PATTERNS: Record<ToolType, RegExp[]> = {
  mindmap: [
    /\b(mappa\s*(mentale|concettuale)?)\b/i,
    /\b(schema|diagramma)\b/i,
    /\b(organizza\s*(le\s+)?idee)\b/i,
  ],
  quiz: [
    /\b(quiz|test|verifica|interrogazione)\b/i,
    /\b(domande|esercizi)\b/i,
    /\b(mi\s+interroghi?)\b/i,
  ],
  flashcard: [
    /\b(flashcard|flash\s*card)\b/i,
    /\b(carte\s+(per\s+)?ripass(o|are))\b/i,
    /\b(schede\s+di\s+studio)\b/i,
  ],
  demo: [
    /\b(demo|simulazione|animazione)\b/i,
    /\b(mostra(mi)?\s+(come|cosa))\b/i,
    /\b(interattiv[ao])\b/i,
  ],
};

/**
 * Crisis patterns (Italian) - require immediate adult referral.
 * These are imported from safety-prompts.ts to maintain single source of truth.
 */
const CRISIS_PATTERNS: RegExp[] = [
  /\b(voglio morire|non voglio vivere|farmi del male|suicid)\b/i,
  /\b(ammazzar(mi|si)|tagliar(mi|si))\b/i,
  /\b(nessuno mi vuole|nessuno mi ama|sarebbe meglio se non esistessi)\b/i,
  /\b(mi odio|mi faccio schifo)\b/i,
];

// ============================================================================
// DETECTION FUNCTIONS
// ============================================================================

/**
 * Detects the subject from a student message.
 */
function detectSubject(message: string): Subject | undefined {
  for (const [subject, patterns] of Object.entries(SUBJECT_PATTERNS)) {
    for (const pattern of patterns) {
      if (pattern.test(message)) {
        return subject as Subject;
      }
    }
  }
  return undefined;
}

/**
 * Detects emotional indicators from a student message.
 */
function detectEmotions(message: string): EmotionalIndicator[] {
  const detected: EmotionalIndicator[] = [];

  for (const [emotion, patterns] of Object.entries(EMOTIONAL_PATTERNS)) {
    for (const pattern of patterns) {
      if (pattern.test(message)) {
        detected.push(emotion as EmotionalIndicator);
        break; // Only count each emotion once
      }
    }
  }

  return detected;
}

/**
 * Checks if message contains crisis keywords.
 */
function isCrisis(message: string): boolean {
  return CRISIS_PATTERNS.some((pattern) => pattern.test(message));
}

/**
 * Checks if message is requesting study method help.
 */
function isMethodRequest(message: string): boolean {
  return METHOD_PATTERNS.some((pattern) => pattern.test(message));
}

/**
 * Checks if message is requesting a tool (flashcard, mindmap, etc.).
 */
function isToolRequest(message: string): boolean {
  return TOOL_PATTERNS.some((pattern) => pattern.test(message));
}

/**
 * Checks if message is requesting technical support with the app.
 * Issue #16: Routes to student's preferred coach.
 */
function isTechSupport(message: string): boolean {
  return TECH_SUPPORT_PATTERNS.some((pattern) => pattern.test(message));
}

/**
 * Detects the specific tool type being requested.
 *
 * @param message - The student's message to analyze
 * @returns The detected tool type, or null if no specific tool detected
 *
 * @example
 * detectToolType("Fammi una mappa mentale sulla Liguria")
 * // Returns: 'mindmap'
 *
 * detectToolType("Crea delle flashcard per ripassare storia")
 * // Returns: 'flashcard'
 */
export function detectToolType(message: string): ToolType | null {
  const normalizedMessage = message.toLowerCase().trim();

  for (const [toolType, patterns] of Object.entries(TOOL_TYPE_PATTERNS)) {
    for (const pattern of patterns) {
      if (pattern.test(normalizedMessage)) {
        return toolType as ToolType;
      }
    }
  }

  return null;
}

// ============================================================================
// MAIN DETECTION FUNCTION
// ============================================================================

/**
 * Analyzes a student message and detects their intent.
 *
 * @param message - The student's message to analyze
 * @returns Detected intent with routing recommendation
 *
 * @example
 * const intent = detectIntent("Non capisco la matematica, è troppo difficile");
 * // Returns: {
 * //   type: 'academic_help',
 * //   subject: 'mathematics',
 * //   emotionalIndicators: ['frustration'],
 * //   recommendedCharacter: 'maestro',
 * //   reason: 'Subject help needed with emotional support element'
 * // }
 */
export function detectIntent(message: string): DetectedIntent {
  const normalizedMessage = message.toLowerCase().trim();

  // 1. CRISIS takes absolute priority
  if (isCrisis(normalizedMessage)) {
    return {
      type: 'crisis',
      confidence: 1.0,
      emotionalIndicators: ['sadness', 'loneliness'],
      recommendedCharacter: 'buddy',
      reason: 'Crisis keywords detected - needs immediate support and adult referral',
    };
  }

  // 2. Detect components
  const subject = detectSubject(normalizedMessage);
  const emotions = detectEmotions(normalizedMessage);
  const wantsMethod = isMethodRequest(normalizedMessage);
  const wantsTool = isToolRequest(normalizedMessage);
  const wantsTechSupport = isTechSupport(normalizedMessage);

  // 2.5. Tech support → Coach (Issue #16)
  // Check early because tech support patterns can overlap with other patterns
  if (wantsTechSupport && !subject) {
    return {
      type: 'tech_support',
      confidence: 0.85,
      emotionalIndicators: emotions,
      recommendedCharacter: 'coach',
      reason: "Technical support with app features - coach will use knowledge base",
    };
  }

  // 3. Determine intent type and routing
  const hasStrongNegativeEmotion = emotions.some((e) =>
    ['frustration', 'anxiety', 'sadness', 'loneliness', 'overwhelm'].includes(e)
  );

  // Strong emotional content → Buddy first
  if (emotions.length >= 2 && hasStrongNegativeEmotion && !subject) {
    return {
      type: 'emotional_support',
      confidence: 0.85,
      emotionalIndicators: emotions,
      recommendedCharacter: 'buddy',
      reason: 'Multiple emotional indicators without specific academic focus',
    };
  }

  // Tool request with subject → Maestro (they can create the tool)
  if (wantsTool && subject) {
    const toolType = detectToolType(normalizedMessage);
    return {
      type: 'tool_request',
      confidence: 0.8,
      subject,
      toolType: toolType ?? undefined,
      emotionalIndicators: emotions,
      recommendedCharacter: 'maestro',
      reason: `Tool creation request (${toolType || 'unspecified'}) for specific subject`,
    };
  }

  // Tool request without subject → Coach can help guide
  if (wantsTool) {
    const toolType = detectToolType(normalizedMessage);
    return {
      type: 'tool_request',
      confidence: 0.7,
      toolType: toolType ?? undefined,
      emotionalIndicators: emotions,
      recommendedCharacter: 'coach',
      reason: `Tool creation request (${toolType || 'unspecified'}) - coach can help identify subject`,
    };
  }

  // Method/organization help → Coach
  if (wantsMethod) {
    return {
      type: 'method_help',
      confidence: 0.8,
      subject, // May have subject context
      emotionalIndicators: emotions,
      recommendedCharacter: 'coach',
      reason: 'Requesting study method or organization help',
    };
  }

  // Subject-specific question → Maestro
  if (subject) {
    return {
      type: 'academic_help',
      confidence: 0.75,
      subject,
      emotionalIndicators: emotions,
      recommendedCharacter: 'maestro',
      reason: hasStrongNegativeEmotion
        ? 'Subject help needed, but may benefit from emotional acknowledgment first'
        : 'Clear academic question for subject expert',
    };
  }

  // Emotional content without subject → Buddy
  if (hasStrongNegativeEmotion) {
    return {
      type: 'emotional_support',
      confidence: 0.7,
      emotionalIndicators: emotions,
      recommendedCharacter: 'buddy',
      reason: 'Emotional support needed without specific academic content',
    };
  }

  // Default: general chat → Coach (neutral starting point)
  return {
    type: 'general_chat',
    confidence: 0.5,
    emotionalIndicators: emotions,
    recommendedCharacter: 'coach',
    reason: 'General conversation - coach can help identify needs',
  };
}

/**
 * Gets the name of the recommended character type in Italian.
 */
export function getCharacterTypeLabel(type: CharacterType): string {
  switch (type) {
    case 'maestro':
      return 'Professore';
    case 'coach':
      return 'Il tuo Coach';
    case 'buddy':
      return 'Il tuo Buddy';
  }
}

/**
 * Checks if the intent suggests the student might benefit
 * from being redirected to a different character.
 */
export function shouldSuggestRedirect(
  intent: DetectedIntent,
  currentCharacter: CharacterType
): { should: boolean; suggestion?: string } {
  if (intent.recommendedCharacter === currentCharacter) {
    return { should: false };
  }

  // Only suggest redirect for high-confidence mismatches
  if (intent.confidence < 0.7) {
    return { should: false };
  }

  const suggestions: Record<CharacterType, string> = {
    maestro: `Per questa domanda di ${intent.subject || 'materia'}, un Professore potrebbe aiutarti meglio!`,
    coach: 'Per organizzare meglio lo studio, il tuo Coach puo\' aiutarti!',
    buddy: 'Se vuoi parlare con qualcuno che ti capisce, il tuo Buddy e\' qui!',
  };

  return {
    should: true,
    suggestion: suggestions[intent.recommendedCharacter],
  };
}
