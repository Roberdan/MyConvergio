'use client';

/**
 * MaestroSession - Unified conversation layout matching Coach/Buddy pattern
 *
 * Layout identical to CharacterChatView:
 * - Flex layout with chat on left, voice panel on right (side by side)
 * - Header with avatar, name, specialty, voice call button
 * - Messages area with inline tools
 * - Input area with tool buttons at bottom
 * - VoicePanel as sibling when voice active (NOT overlay)
 * - Evaluation inline in chat when session ends
 */

import { useState, useRef, useEffect, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import Image from 'next/image';
import {
  Send,
  X,
  Phone,
  PhoneOff,
  Loader2,
  Volume2,
  VolumeX,
  Camera,
  Brain,
  BookOpen,
  Layers,
  Search,
  RotateCcw,
  Sparkles,
  FileText,
  GitBranch,
  Clock,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { useTTS } from '@/components/accessibility';
import { useVoiceSession } from '@/lib/hooks/use-voice-session';
import { useProgressStore, useUIStore } from '@/lib/stores/app-store';
import { ToolResultDisplay } from '@/components/tools';
import { WebcamCapture } from '@/components/tools/webcam-capture';
import { EvaluationCard } from '@/components/chat/evaluation-card';
import { VoicePanel } from '@/components/voice';
import { logger } from '@/lib/logger';
import toast from '@/components/ui/toast';
import type { Maestro, ChatMessage, ToolCall, SessionEvaluation } from '@/types';
import { MAESTRI_XP } from '@/lib/constants/xp-rewards';

// Constants for score calculations (extracted for clarity)
const SCORE_QUESTIONS_WEIGHT = 0.5; // Points per question (max 2 points)
const SCORE_DURATION_WEIGHT = 0.1;  // Points per minute (max 2 points)
const SCORE_XP_WEIGHT = 0.005;      // Points per XP (max 0.5 points)

interface MaestroSessionProps {
  maestro: Maestro;
  onClose: () => void;
  initialMode?: 'voice' | 'chat';
}

/**
 * Generates evaluation based on session metrics.
 */
function generateAutoEvaluation(
  questionsAsked: number,
  sessionDuration: number,
  xpEarned: number
): SessionEvaluation {
  const baseScore = Math.min(10, Math.max(1,
    5 +
    Math.min(2, questionsAsked * SCORE_QUESTIONS_WEIGHT) +
    Math.min(2, sessionDuration * SCORE_DURATION_WEIGHT) +
    Math.min(0.5, xpEarned * SCORE_XP_WEIGHT)
  ));
  const score = Math.round(baseScore);

  let feedback: string;
  if (score >= 9) {
    feedback = 'Sessione eccezionale! Hai dimostrato grande impegno e curiosità. Continua così!';
  } else if (score >= 7) {
    feedback = 'Ottima sessione di studio. Hai fatto buoni progressi e posto domande interessanti.';
  } else if (score >= 5) {
    feedback = 'Buona sessione. C\'è ancora margine di miglioramento, ma stai andando nella direzione giusta.';
  } else {
    feedback = 'La sessione è stata breve. Prova a dedicare più tempo allo studio per risultati migliori.';
  }

  const strengths: string[] = [];
  if (questionsAsked >= 5) strengths.push('Curiosità e voglia di approfondire');
  if (sessionDuration >= 10) strengths.push('Buona concentrazione durante la sessione');
  if (questionsAsked >= 3 && sessionDuration >= 5) strengths.push('Interazione attiva con il professore');
  if (strengths.length === 0) strengths.push('Hai iniziato il percorso di apprendimento');

  const areasToImprove: string[] = [];
  if (questionsAsked < 3) areasToImprove.push('Fai più domande per chiarire i dubbi');
  if (sessionDuration < 10) areasToImprove.push('Prova sessioni più lunghe per approfondire meglio');
  if (areasToImprove.length === 0) areasToImprove.push('Continua a esercitarti regolarmente');

  return {
    score,
    feedback,
    strengths,
    areasToImprove,
    sessionDuration,
    questionsAsked,
    xpEarned,
    savedToDiary: false,
  };
}


/**
 * Message bubble component matching CharacterChatView style.
 */
function MessageBubble({
  message,
  maestro,
  ttsEnabled,
  speak,
}: {
  message: ChatMessage;
  maestro: Maestro;
  ttsEnabled: boolean;
  speak: (text: string) => void;
}) {
  const isUser = message.role === 'user';
  const isVoice = message.isVoice;

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      className={cn('flex gap-3', isUser ? 'justify-end' : 'justify-start')}
    >
      {!isUser && (
        <div className="flex-shrink-0">
          <Image
            src={maestro.avatar}
            alt={maestro.name}
            width={36}
            height={36}
            className="rounded-full object-cover"
          />
        </div>
      )}
      <div
        className={cn(
          'max-w-[75%] rounded-2xl px-4 py-3',
          isUser
            ? 'text-white rounded-br-md'
            : 'bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 rounded-bl-md shadow-sm'
        )}
        style={isUser ? { backgroundColor: maestro.color } : undefined}
      >
        {isVoice && (
          <span className="text-xs opacity-60 mb-1 flex items-center gap-1">
            <Volume2 className="w-3 h-3" /> Trascrizione vocale
          </span>
        )}
        <p className="text-sm whitespace-pre-wrap">{message.content}</p>
        <div className="flex items-center justify-between mt-1 gap-2">
          <span className="text-xs opacity-60">
            {new Date(message.timestamp).toLocaleTimeString('it-IT', {
              hour: '2-digit',
              minute: '2-digit',
            })}
          </span>
          {!isUser && ttsEnabled && (
            <button
              onClick={() => speak(message.content)}
              className="text-xs opacity-60 hover:opacity-100 ml-auto"
              title="Leggi ad alta voce"
            >
              <Volume2 className="w-3 h-3" />
            </button>
          )}
        </div>
      </div>
    </motion.div>
  );
}

export function MaestroSession({ maestro, onClose, initialMode = 'voice' }: MaestroSessionProps) {
  // Chat state
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [toolCalls, setToolCalls] = useState<ToolCall[]>([]);
  const [isVoiceActive, setIsVoiceActive] = useState(initialMode === 'voice');
  const [showWebcam, setShowWebcam] = useState(false);
  const [webcamRequest, setWebcamRequest] = useState<{ purpose: string; instructions?: string; callId: string } | null>(null);
  const [configError, setConfigError] = useState<string | null>(null);
  const [connectionInfo, setConnectionInfo] = useState<{ provider: 'azure'; proxyPort: number; configured: boolean } | null>(null);

  // Session tracking
  const [sessionEnded, setSessionEnded] = useState(false);
  const sessionStartTime = useRef(Date.now());
  const questionCount = useRef(0);
  const lastTranscriptIdRef = useRef<string | null>(null);
  const previousMessageCount = useRef(0);
  const closeTimeoutRef = useRef<NodeJS.Timeout | null>(null);

  // Refs
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLTextAreaElement>(null);

  // Stores
  const { addXP, endSession } = useProgressStore();
  const { speak, stop: stopTTS, enabled: ttsEnabled } = useTTS();

  // C-17 FIX: UI store for focus mode on tool creation
  const { enterFocusMode, setFocusTool } = useUIStore();

  // C-17 FIX: Track which tool calls we've already processed for focus mode
  const processedToolsRef = useRef<Set<string>>(new Set());

  // Voice session hook
  const {
    isConnected,
    isListening,
    isSpeaking,
    isMuted,
    inputLevel,
    connectionState,
    connect,
    disconnect,
    toggleMute,
    sessionId: voiceSessionId,
  } = useVoiceSession({
    onError: (error) => {
      const message = error instanceof Error ? error.message : String(error);
      logger.error('Voice call error', { message });
      setConfigError(message || 'Errore di connessione vocale');
    },
    onTranscript: (role, text) => {
      // Add voice transcripts to the chat messages
      const transcriptId = `voice-${role}-${Date.now()}`;

      // Avoid duplicate transcripts
      if (lastTranscriptIdRef.current === text.substring(0, 50)) {
        return;
      }
      lastTranscriptIdRef.current = text.substring(0, 50);

      // Only count as question if it contains a question mark
      if (role === 'user' && text.includes('?')) {
        questionCount.current += 1;
      }

      setMessages(prev => [...prev, {
        id: transcriptId,
        role,
        content: text,
        timestamp: new Date(),
        isVoice: true,
      }]);
    },
  });

  // Add greeting message on mount and check for pending tool request
  useEffect(() => {
    setMessages([{
      id: 'greeting',
      role: 'assistant',
      content: maestro.greeting,
      timestamp: new Date(),
    }]);

    // Check for pending tool request from maestri-grid
    const pendingRequest = sessionStorage.getItem('pendingToolRequest');
    if (pendingRequest) {
      try {
        const { tool, maestroId } = JSON.parse(pendingRequest);
        if (maestroId === maestro.id) {
          // Trigger the tool request
          const toolPrompts: Record<string, string> = {
            mindmap: `Crea una mappa mentale sull'argomento di cui stiamo parlando`,
            quiz: `Crea un quiz per verificare la mia comprensione`,
            flashcards: `Crea delle flashcard per aiutarmi a memorizzare`,
            demo: `Crea una demo interattiva per spiegarmi meglio il concetto`,
          };
          if (toolPrompts[tool]) {
            setInput(toolPrompts[tool]);
          }
          sessionStorage.removeItem('pendingToolRequest');
        }
      } catch {
        sessionStorage.removeItem('pendingToolRequest');
      }
    }

    // Cleanup timeouts on unmount
    const timeoutRef = closeTimeoutRef.current;
    return () => {
      if (timeoutRef) {
        clearTimeout(timeoutRef);
      }
    };
  }, [maestro.greeting, maestro.id]);

  // Fetch voice connection info on mount (like CharacterChatView pattern)
  useEffect(() => {
    async function fetchConnectionInfo() {
      try {
        const response = await fetch('/api/realtime/token');
        const data = await response.json();
        if (data.error) {
          logger.error('Voice API error', { error: data.error });
          setConfigError(data.message || 'Servizio vocale non configurato');
          return;
        }
        setConnectionInfo(data);
      } catch (error) {
        logger.error('Failed to get voice connection info', { error: String(error) });
        setConfigError('Impossibile connettersi al servizio vocale');
      }
    }
    fetchConnectionInfo();
  }, []);

  // Connect when voice is activated AND connection info is available
  useEffect(() => {
    if (!isVoiceActive || !connectionInfo || connectionState !== 'idle') return;

    const startVoice = async () => {
      setConfigError(null);
      try {
        await connect(maestro, connectionInfo);
      } catch (error) {
        logger.error('Voice connection failed', { error: String(error) });
        if (error instanceof DOMException && error.name === 'NotAllowedError') {
          setConfigError('Microfono non autorizzato. Abilita il microfono nelle impostazioni del browser.');
        } else {
          setConfigError('Errore di connessione vocale');
        }
        setIsVoiceActive(false);
      }
    };

    startVoice();
  }, [isVoiceActive, connectionInfo, connectionState, maestro, connect]);

  // Auto-scroll to bottom only when new messages are added
  useEffect(() => {
    const currentCount = messages.length + toolCalls.length;
    if (currentCount > previousMessageCount.current) {
      messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
    }
    previousMessageCount.current = currentCount;
  }, [messages.length, toolCalls.length]);

  // C-17 FIX: Auto-switch to focus mode when a tool is created
  // This provides fullscreen tool experience during maestro sessions
  useEffect(() => {
    // Find newly completed tool calls that we haven't processed yet
    const completedTools = toolCalls.filter(
      (tc) => tc.status === 'completed' && !processedToolsRef.current.has(tc.id)
    );

    if (completedTools.length === 0) return;

    // Process the first new completed tool
    const toolCall = completedTools[0];
    processedToolsRef.current.add(toolCall.id);

    // Map tool type from function name to ToolType
    const toolTypeMap: Record<string, string> = {
      create_mindmap: 'mindmap',
      create_quiz: 'quiz',
      create_flashcards: 'flashcard',
      create_summary: 'summary',
      create_demo: 'demo',
      create_diagram: 'diagram',
      create_timeline: 'timeline',
      web_search: 'search',
    };
    const mappedToolType = (toolTypeMap[toolCall.type] || 'mindmap') as import('@/types/tools').ToolType;

    // Extract tool content
    const toolContent = toolCall.result?.data || toolCall.result || toolCall.arguments;

    // Enter focus mode with the completed tool
    enterFocusMode(mappedToolType, maestro.id, isVoiceActive ? 'voice' : 'chat');
    setFocusTool({
      id: toolCall.id,
      type: mappedToolType,
      status: 'completed',
      progress: 1,
      content: toolContent,
      createdAt: new Date(),
    });

    logger.debug('[MaestroSession] C-17: Entered focus mode for tool', {
      toolId: toolCall.id,
      toolType: mappedToolType,
    });
  }, [toolCalls, enterFocusMode, setFocusTool, maestro.id, isVoiceActive]);

  // Focus input when not in voice mode
  useEffect(() => {
    if (!isVoiceActive) {
      inputRef.current?.focus();
    }
  }, [isVoiceActive]);

  // Handle voice call toggle
  const handleVoiceCall = useCallback(() => {
    if (isVoiceActive) {
      disconnect();
    }
    setIsVoiceActive(prev => !prev);
  }, [isVoiceActive, disconnect]);

  // End voice and generate evaluation
  const handleEndSession = useCallback(async () => {
    if (isVoiceActive) {
      disconnect();
      setIsVoiceActive(false);
    }
    setSessionEnded(true);

    const sessionDuration = Math.round((Date.now() - sessionStartTime.current) / 60000);
    const xpEarned = Math.min(MAESTRI_XP.MAX_PER_SESSION, sessionDuration * MAESTRI_XP.PER_MINUTE + questionCount.current * MAESTRI_XP.PER_QUESTION);

    const evaluation = generateAutoEvaluation(questionCount.current, sessionDuration, xpEarned);

    // Try to save to diary - silent failure is intentional to not distract from evaluation
    // The savedToDiary flag controls whether the success indicator is shown
    try {
      const response = await fetch('/api/learnings/extract', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          conversationId: `maestro-${maestro.id}-${Date.now()}`,
          maestroId: maestro.id,
          messages: messages.map(m => ({ role: m.role, content: m.content })),
        }),
      });
      evaluation.savedToDiary = response.ok;
    } catch (error) {
      // Silent failure - diary save is non-critical functionality
      // We don't want to distract from the evaluation experience
      logger.warn('Failed to save to diary (non-critical)', { error });
      evaluation.savedToDiary = false;
    }

    // Add evaluation message to chat
    setMessages(prev => [...prev, {
      id: `eval-${Date.now()}`,
      role: 'assistant',
      content: '',
      timestamp: new Date(),
      type: 'evaluation',
      evaluation,
    }]);

    // Update progress
    addXP(xpEarned);
    endSession();

    // Show XP toast notification
    toast.success(
      `+${xpEarned} XP guadagnati!`,
      `${sessionDuration} minuti di studio, ${questionCount.current} domande fatte. Ottimo lavoro!`,
      { duration: 6000 }
    );
  }, [isVoiceActive, disconnect, maestro.id, messages, addXP, endSession]);

  // Handle text submit - wrapped in useCallback for performance
  const handleSubmit = useCallback(async (e?: React.FormEvent) => {
    e?.preventDefault();
    if (!input.trim() || isLoading) return;

    const userContent = input.trim();
    const userMessage: ChatMessage = {
      id: `user-${Date.now()}`,
      role: 'user',
      content: userContent,
      timestamp: new Date(),
    };

    setMessages(prev => [...prev, userMessage]);
    setInput('');
    setIsLoading(true);
    // Only count as question if it contains a question mark
    if (userContent.includes('?')) {
      questionCount.current += 1;
    }

    try {
      const response = await fetch('/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          messages: [
            { role: 'system', content: maestro.systemPrompt },
            ...messages.map(m => ({ role: m.role, content: m.content })),
            { role: 'user', content: userContent },
          ],
          maestroId: maestro.id,
        }),
      });

      if (!response.ok) throw new Error('Failed to get response');
      const data = await response.json();

      const assistantMessage: ChatMessage = {
        id: `assistant-${Date.now()}`,
        role: 'assistant',
        content: data.content || data.message || '',
        timestamp: new Date(),
      };
      setMessages(prev => [...prev, assistantMessage]);

      // Handle tool calls
      if (data.toolCalls?.length > 0) {
        setToolCalls(prev => [...prev, ...data.toolCalls]);
      }
    } catch (error) {
      logger.error('Chat error', { error });
      setMessages(prev => [...prev, {
        id: `error-${Date.now()}`,
        role: 'assistant',
        content: 'Mi dispiace, ho avuto un problema. Puoi riprovare?',
        timestamp: new Date(),
      }]);
    } finally {
      setIsLoading(false);
      inputRef.current?.focus();
    }
  }, [input, isLoading, messages, maestro.systemPrompt, maestro.id]);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSubmit();
    }
  };

  const clearChat = () => {
    setMessages([{
      id: 'greeting',
      role: 'assistant',
      content: maestro.greeting,
      timestamp: new Date(),
    }]);
    setToolCalls([]);
    questionCount.current = 0;
    setSessionEnded(false);
  };

  // Handle webcam capture
  const handleWebcamCapture = useCallback((imageData: string) => {
    setShowWebcam(false);
    setWebcamRequest(null);
    // Add user message showing photo was captured
    setMessages(prev => [
      ...prev,
      {
        id: `webcam-${Date.now()}`,
        role: 'user',
        content: '[Foto catturata]',
        timestamp: new Date(),
      },
      {
        id: `webcam-info-${Date.now()}`,
        role: 'assistant',
        content: 'Ho ricevuto la tua foto! Per ora non posso analizzarla automaticamente, ma puoi descrivermi cosa vedi o cosa vorresti che ti spiegassi.',
        timestamp: new Date(),
      },
    ]);
    logger.debug('Webcam captured', { imageDataLength: imageData.length });
  }, []);

  // Request tool from input
  const requestTool = (tool: 'mindmap' | 'quiz' | 'flashcards' | 'demo' | 'search' | 'summary' | 'diagram' | 'timeline') => {
    const toolPrompts: Record<string, string> = {
      mindmap: `Crea una mappa mentale sull'argomento di cui stiamo parlando`,
      quiz: `Crea un quiz per verificare la mia comprensione`,
      flashcards: `Crea delle flashcard per aiutarmi a memorizzare`,
      demo: `Crea una demo interattiva per spiegarmi meglio il concetto`,
      search: `Cerca informazioni utili sull'argomento`,
      summary: `Fammi un riassunto strutturato dell'argomento`,
      diagram: `Crea un diagramma per visualizzare il concetto`,
      timeline: `Crea una linea temporale degli eventi`,
    };
    setInput(toolPrompts[tool]);
    inputRef.current?.focus();
  };

  return (
    <div className="flex gap-4 h-[calc(100vh-8rem)]">
      {/* Main Chat Area */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Chat Header */}
        <div
          className="flex items-center gap-4 p-4 rounded-t-2xl text-white"
          style={{ background: `linear-gradient(to right, ${maestro.color}, ${maestro.color}dd)` }}
        >
          <div className="relative">
            <Image
              src={maestro.avatar}
              alt={maestro.name}
              width={56}
              height={56}
              className="rounded-full border-2 border-white/30 object-cover"
            />
            <span className={cn(
              "absolute bottom-0 right-0 w-4 h-4 border-2 border-white rounded-full",
              isVoiceActive && isConnected ? "bg-green-400 animate-pulse" : "bg-green-400"
            )} />
          </div>
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2">
              <h2 className="text-xl font-bold truncate">{maestro.name}</h2>
              <span className="text-xs px-2 py-0.5 rounded-full font-medium bg-white/20">
                Maestro
              </span>
            </div>
            <p className="text-sm text-white/80 truncate">
              {isVoiceActive && isConnected ? 'In chiamata vocale' : maestro.specialty}
            </p>
          </div>

          {/* Voice Call Button */}
          <Button
            variant={isVoiceActive ? 'destructive' : 'ghost'}
            size="icon"
            onClick={handleVoiceCall}
            disabled={!!configError && !isVoiceActive}
            aria-label={
              configError && !isVoiceActive
                ? `Voce non disponibile: ${configError}`
                : isVoiceActive
                  ? 'Termina chiamata'
                  : 'Avvia chiamata vocale'
            }
            title={configError && !isVoiceActive ? configError : undefined}
            className={cn(
              'text-white hover:bg-white/20 transition-all',
              isVoiceActive && 'bg-red-500 hover:bg-red-600 animate-pulse',
              configError && !isVoiceActive && 'opacity-50 cursor-not-allowed'
            )}
          >
            {isVoiceActive ? (
              <PhoneOff className="w-5 h-5" />
            ) : (
              <Phone className="w-5 h-5" />
            )}
          </Button>

          {/* TTS toggle */}
          <Button
            variant="ghost"
            size="icon"
            onClick={ttsEnabled ? stopTTS : undefined}
            disabled={!ttsEnabled}
            className="text-white hover:bg-white/20"
            aria-label={ttsEnabled ? 'Disattiva lettura vocale' : 'Lettura vocale disattivata'}
          >
            {ttsEnabled ? <Volume2 className="w-4 h-4" /> : <VolumeX className="w-4 h-4" />}
          </Button>

          {/* Clear chat */}
          <Button
            variant="ghost"
            size="icon"
            onClick={clearChat}
            className="text-white hover:bg-white/20"
            aria-label="Nuova conversazione"
          >
            <RotateCcw className="w-4 h-4" />
          </Button>

          {/* Close */}
          <Button
            variant="ghost"
            size="icon"
            onClick={onClose}
            className="text-white hover:bg-white/20"
            aria-label="Chiudi"
          >
            <X className="w-4 h-4" />
          </Button>
        </div>

        {/* Webcam overlay */}
        <AnimatePresence>
          {showWebcam && webcamRequest && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="absolute inset-0 z-40 bg-black/90 flex items-center justify-center rounded-2xl"
            >
              <div className="w-full max-w-lg">
                <WebcamCapture
                  purpose={webcamRequest.purpose}
                  onCapture={handleWebcamCapture}
                  onClose={() => { setShowWebcam(false); setWebcamRequest(null); }}
                  instructions={webcamRequest.instructions}
                />
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Messages Area */}
        <div
          className="flex-1 overflow-y-auto p-4 space-y-4 bg-slate-50 dark:bg-slate-900/50"
          role="log"
          aria-live="polite"
          aria-label="Messaggi della conversazione"
        >
          {messages.map((message) => (
            message.type === 'evaluation' && message.evaluation ? (
              <EvaluationCard
                key={message.id}
                evaluation={message.evaluation}
                maestroName={maestro.name}
                maestroColor={maestro.color}
                className="mb-4"
              />
            ) : (
              <MessageBubble
                key={message.id}
                message={message}
                maestro={maestro}
                ttsEnabled={ttsEnabled}
                speak={speak}
              />
            )
          ))}

          {/* Tool results inline - pass sessionId for real-time mindmap collaboration */}
          {toolCalls.map((tool) => (
            <motion.div
              key={tool.id}
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              className="mb-4"
            >
              <ToolResultDisplay toolCall={tool} sessionId={voiceSessionId} />
            </motion.div>
          ))}

          {/* Loading indicator */}
          {isLoading && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              className="flex gap-3"
            >
              <div className="flex-shrink-0">
                <Image
                  src={maestro.avatar}
                  alt={maestro.name}
                  width={36}
                  height={36}
                  className="rounded-full object-cover"
                />
              </div>
              <div className="bg-white dark:bg-slate-800 rounded-2xl rounded-bl-md px-4 py-3 shadow-sm">
                <div className="flex gap-1">
                  <span className="w-2 h-2 bg-slate-400 rounded-full animate-bounce" style={{ animationDelay: '0ms' }} />
                  <span className="w-2 h-2 bg-slate-400 rounded-full animate-bounce" style={{ animationDelay: '150ms' }} />
                  <span className="w-2 h-2 bg-slate-400 rounded-full animate-bounce" style={{ animationDelay: '300ms' }} />
                </div>
              </div>
            </motion.div>
          )}

          <div ref={messagesEndRef} />
        </div>

        {/* Input Area */}
        <div className="p-4 bg-white dark:bg-slate-900 border-t border-slate-200 dark:border-slate-800 rounded-b-2xl">
          {/* Tool buttons */}
          <div className="flex gap-1 mb-2">
            <Button
              variant="ghost"
              size="sm"
              onClick={() => {
                setWebcamRequest({ purpose: 'homework', instructions: 'Mostra il tuo compito', callId: `cam-${Date.now()}` });
                setShowWebcam(true);
              }}
              disabled={isLoading || sessionEnded}
              className="text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white"
              title="Scatta foto"
            >
              <Camera className="w-4 h-4 mr-1" />
              <span className="text-xs">Foto</span>
            </Button>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => requestTool('mindmap')}
              disabled={isLoading || sessionEnded}
              className="text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white"
              title="Crea mappa mentale"
            >
              <Brain className="w-4 h-4 mr-1" />
              <span className="text-xs">Mappa</span>
            </Button>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => requestTool('quiz')}
              disabled={isLoading || sessionEnded}
              className="text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white"
              title="Crea quiz"
            >
              <BookOpen className="w-4 h-4 mr-1" />
              <span className="text-xs">Quiz</span>
            </Button>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => requestTool('demo')}
              disabled={isLoading || sessionEnded}
              className="text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white"
              title="Crea demo interattiva"
            >
              <Sparkles className="w-4 h-4 mr-1" />
              <span className="text-xs">Demo</span>
            </Button>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => requestTool('flashcards')}
              disabled={isLoading || sessionEnded}
              className="text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white"
              title="Crea flashcard"
            >
              <Layers className="w-4 h-4 mr-1" />
              <span className="text-xs">Flashcard</span>
            </Button>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => requestTool('search')}
              disabled={isLoading || sessionEnded}
              className="text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white"
              title="Cerca su web"
            >
              <Search className="w-4 h-4 mr-1" />
              <span className="text-xs">Cerca</span>
            </Button>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => requestTool('summary')}
              disabled={isLoading || sessionEnded}
              className="text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white"
              title="Crea riassunto"
            >
              <FileText className="w-4 h-4 mr-1" />
              <span className="text-xs">Riassunto</span>
            </Button>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => requestTool('diagram')}
              disabled={isLoading || sessionEnded}
              className="text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white"
              title="Crea diagramma"
            >
              <GitBranch className="w-4 h-4 mr-1" />
              <span className="text-xs">Diagramma</span>
            </Button>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => requestTool('timeline')}
              disabled={isLoading || sessionEnded}
              className="text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white"
              title="Crea linea temporale"
            >
              <Clock className="w-4 h-4 mr-1" />
              <span className="text-xs">Timeline</span>
            </Button>
          </div>

          <div className="flex gap-3">
            <textarea
              ref={inputRef}
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder={
                sessionEnded
                  ? 'Sessione terminata - Clicca "Nuova conversazione" per ricominciare'
                  : isVoiceActive
                    ? 'Parla o scrivi...'
                    : `Scrivi un messaggio a ${maestro.name}...`
              }
              className="flex-1 resize-none rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800 px-4 py-3 text-sm focus:outline-none focus:ring-2"
              style={{ '--tw-ring-color': maestro.color } as React.CSSProperties}
              rows={1}
              disabled={isLoading || sessionEnded}
            />
            <Button
              onClick={() => handleSubmit()}
              disabled={!input.trim() || isLoading || sessionEnded}
              style={{ backgroundColor: maestro.color }}
              className="hover:opacity-90"
            >
              {isLoading ? (
                <Loader2 className="h-5 w-5 animate-spin" />
              ) : (
                <Send className="h-5 w-5" />
              )}
            </Button>
          </div>

          {/* End session button */}
          {!sessionEnded && messages.length > 1 && (
            <div className="flex justify-center mt-3">
              <Button
                variant="outline"
                size="sm"
                onClick={handleEndSession}
                className="text-slate-600"
              >
                Termina sessione e valuta
              </Button>
            </div>
          )}
        </div>
      </div>

      {/* Voice Panel (Side by Side) */}
      <AnimatePresence>
        {isVoiceActive && (
          <VoicePanel
            character={{
              name: maestro.name,
              avatar: maestro.avatar,
              specialty: maestro.specialty,
              color: maestro.color,
            }}
            isConnected={isConnected}
            isListening={isListening}
            isSpeaking={isSpeaking}
            isMuted={isMuted}
            inputLevel={inputLevel}
            connectionState={connectionState}
            configError={configError}
            onToggleMute={toggleMute}
            onEndCall={handleVoiceCall}
          />
        )}
      </AnimatePresence>
    </div>
  );
}
