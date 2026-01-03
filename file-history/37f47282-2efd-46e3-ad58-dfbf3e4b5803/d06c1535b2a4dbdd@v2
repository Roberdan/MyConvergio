'use client';

import { useState, useEffect, useCallback, useRef } from 'react';
import Image from 'next/image';
import { motion, AnimatePresence } from 'framer-motion';
import { Mic, MicOff, PhoneOff, VolumeX, Send, MessageSquare, Camera, Brain, BookOpen, Search, Network, AlertCircle, Clock, Trophy } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { CanvasWaveform, CircularWaveform } from './waveform';
import { useVoiceSession } from '@/lib/hooks/use-voice-session';
import { usePermissions } from '@/lib/hooks/use-permissions';
import { ToolResultDisplay } from '@/components/tools';
import { WebcamCapture } from '@/components/tools/webcam-capture';
import { SessionGradeDisplay } from './session-grade';
import { useProgressStore, useUIStore } from '@/lib/stores/app-store';
import { useAmbientAudioStore } from '@/lib/stores/ambient-audio-store';
import { cn } from '@/lib/utils';
import { logger } from '@/lib/logger';
import type { Maestro } from '@/types';
import { XP_PER_LEVEL } from '@/lib/constants/xp-rewards';

// C-2 FIX: Helper to get userId from cookie or sessionStorage
function getUserId(): string | null {
  if (typeof window === 'undefined') return null;
  // Try cookie first (server-compatible)
  const cookieMatch = document.cookie.match(/mirrorbuddy-user-id=([^;]+)/);
  if (cookieMatch) return cookieMatch[1];
  // Fallback to sessionStorage
  return sessionStorage.getItem('mirrorbuddy-user-id');
}

interface ConnectionInfo {
  provider: 'azure';
  proxyPort: number;
  configured: boolean;
}

interface ConnectionError {
  error: string;
  missingVariables?: string[];
  message?: string;
}

interface VoiceSessionProps {
  maestro: Maestro;
  onClose: () => void;
  onSwitchToChat?: () => void;
}

export function VoiceSession({ maestro, onClose, onSwitchToChat }: VoiceSessionProps) {
  const [connectionInfo, setConnectionInfo] = useState<ConnectionInfo | null>(null);
  const [configError, setConfigError] = useState<ConnectionError | null>(null);
  const [textInput, setTextInput] = useState('');
  const [showTextInput, setShowTextInput] = useState(false);
  const [showWebcam, setShowWebcam] = useState(false);
  const [webcamRequest, setWebcamRequest] = useState<{ purpose: string; instructions?: string; callId: string } | null>(null);
  const [permissionError, setPermissionError] = useState<string | null>(null);
  const [showGrade, setShowGrade] = useState(false);
  const [finalSessionDuration, setFinalSessionDuration] = useState(0);
  const [finalQuestionCount, setFinalQuestionCount] = useState(0);
  const [_sessionSummary, setSessionSummary] = useState<string | null>(null);

  // Track session start time
  const sessionStartTime = useRef<Date>(new Date());
  const questionCount = useRef<number>(0);

  // C-2 FIX: Track conversation ID for memory persistence
  const conversationIdRef = useRef<string | null>(null);
  const savedMessagesRef = useRef<Set<string>>(new Set()); // Track which messages we've saved

  // Progress store for session tracking
  const { currentSession, endSession, startSession, xp, level } = useProgressStore();

  // C-17 FIX: UI store for focus mode on tool creation
  const { enterFocusMode, setFocusTool } = useUIStore();

  // C-17 FIX: Track which tool calls we've already processed for focus mode
  const processedToolsRef = useRef<Set<string>>(new Set());

  // C-6 FIX: Timer state for elapsed session time
  const [elapsedSeconds, setElapsedSeconds] = useState(0);

  // Check permissions before starting
  const { permissions, requestMicrophone, isLoading: permissionsLoading } = usePermissions();

  const {
    isConnected,
    isListening,
    isSpeaking,
    isMuted,
    transcript,
    toolCalls,
    inputLevel,
    outputLevel,
    connectionState,
    inputAnalyser,
    connect,
    disconnect,
    toggleMute,
    sendText,
    cancelResponse,
    clearTranscript: _clearTranscript,
    clearToolCalls,
    sendWebcamResult,
    sessionId: voiceSessionId,
  } = useVoiceSession({
    onError: (error) => {
      const message = error instanceof Error ? error.message : String(error);
      logger.error('Voice error', { message });
    },
    onTranscript: (role, text) => {
      logger.debug('Transcript', { role, text: text.substring(0, 100) });
      // Count user questions
      if (role === 'user' && text.includes('?')) {
        questionCount.current++;
      }
    },
    onWebcamRequest: (request) => {
      logger.debug('Webcam requested', { purpose: request.purpose });
      setWebcamRequest(request);
      setShowWebcam(true);
    },
  });

  // Start session when connected
  useEffect(() => {
    if (isConnected && !currentSession) {
      sessionStartTime.current = new Date();
      startSession(maestro.id, maestro.specialty);
    }
  }, [isConnected, currentSession, maestro.id, maestro.specialty, startSession]);

  // C-17 FIX: Auto-switch to focus mode when a tool is created
  // This provides fullscreen tool experience during voice sessions
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
    enterFocusMode(mappedToolType, maestro.id, 'voice');
    setFocusTool({
      id: toolCall.id,
      type: mappedToolType,
      status: 'completed',
      progress: 1,
      content: toolContent,
      createdAt: new Date(),
    });

    logger.debug('[VoiceSession] C-17: Entered focus mode for tool', {
      toolId: toolCall.id,
      toolType: mappedToolType,
    });
  }, [toolCalls, enterFocusMode, setFocusTool, maestro.id]);

  // C-2 FIX: Create conversation in DB when voice session connects
  useEffect(() => {
    if (!isConnected || conversationIdRef.current) return;

    const createConversation = async () => {
      try {
        const response = await fetch('/api/conversations', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            maestroId: maestro.id,
            title: `Sessione vocale con ${maestro.name}`,
          }),
        });
        if (response.ok) {
          const data = await response.json();
          conversationIdRef.current = data.id;
          logger.debug('[VoiceSession] Conversation created for memory persistence', { conversationId: data.id });
        }
      } catch (error) {
        logger.error('[VoiceSession] Failed to create conversation', { error: String(error) });
      }
    };

    createConversation();
  }, [isConnected, maestro.id, maestro.name]);

  // C-2 FIX: Save transcript messages to DB for memory persistence
  useEffect(() => {
    if (!conversationIdRef.current || transcript.length === 0) return;

    const saveNewMessages = async () => {
      for (const entry of transcript) {
        const messageKey = `${entry.role}-${entry.content.slice(0, 50)}`;
        if (savedMessagesRef.current.has(messageKey)) continue;

        try {
          await fetch(`/api/conversations/${conversationIdRef.current}/messages`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              role: entry.role,
              content: entry.content,
            }),
          });
          savedMessagesRef.current.add(messageKey);
        } catch (error) {
          logger.error('[VoiceSession] Failed to save message', { error: String(error) });
        }
      }
    };

    saveNewMessages();
  }, [transcript]);

  // Auto-pause ambient audio during voice session (ADR-0018)
  const ambientPlaybackState = useAmbientAudioStore((s) => s.playbackState);
  const pauseAmbient = useAmbientAudioStore((s) => s.pause);
  const playAmbient = useAmbientAudioStore((s) => s.play);
  const wasPlayingRef = useRef(false);

  useEffect(() => {
    if (isConnected) {
      // Voice session started - pause ambient if playing
      if (ambientPlaybackState === 'playing') {
        wasPlayingRef.current = true;
        pauseAmbient();
        logger.debug('[VoiceSession] Paused ambient audio for voice session');
      }
    } else {
      // Voice session ended - resume ambient if it was playing before
      if (wasPlayingRef.current) {
        wasPlayingRef.current = false;
        playAmbient();
        logger.debug('[VoiceSession] Resumed ambient audio after voice session');
      }
    }
  }, [isConnected, ambientPlaybackState, pauseAmbient, playAmbient]);

  // C-6 FIX: Timer that increments every second when connected
  useEffect(() => {
    if (!isConnected) return; // Early return, reset handled in cleanup

    const interval = setInterval(() => {
      setElapsedSeconds((prev) => prev + 1);
    }, 1000);

    return () => {
      clearInterval(interval);
      setElapsedSeconds(0); // Reset on cleanup
    };
  }, [isConnected]);

  // C-6 FIX: Calculate XP progress for current level
  const currentLevelXP = XP_PER_LEVEL[level - 1] || 0;
  const nextLevelXP = XP_PER_LEVEL[level] || XP_PER_LEVEL[XP_PER_LEVEL.length - 1];
  const xpProgress = nextLevelXP > currentLevelXP
    ? ((xp - currentLevelXP) / (nextLevelXP - currentLevelXP)) * 100
    : 100;

  // C-6 FIX: Format elapsed time as MM:SS
  const formatTime = (seconds: number): string => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  // Handle webcam capture completion
  const handleWebcamCapture = useCallback((imageData: string) => {
    if (webcamRequest) {
      sendWebcamResult(webcamRequest.callId, imageData);
      setShowWebcam(false);
      setWebcamRequest(null);
    }
  }, [webcamRequest, sendWebcamResult]);

  // Handle webcam close/cancel
  const handleWebcamClose = useCallback(() => {
    if (webcamRequest) {
      sendWebcamResult(webcamRequest.callId, null);
    }
    setShowWebcam(false);
    setWebcamRequest(null);
  }, [webcamRequest, sendWebcamResult]);

  // Fetch connection info and connect
  useEffect(() => {
    async function init() {
      try {
        const response = await fetch('/api/realtime/token');
        const data = await response.json();
        if (data.error) {
          logger.error('API error', { error: data.error });
          setConfigError(data as ConnectionError);
          return;
        }
        // Store Azure connection info
        setConnectionInfo(data as ConnectionInfo);
      } catch (error) {
        logger.error('Failed to get connection info', { error: String(error) });
        setConfigError({
          error: 'Connection failed',
          message: 'Unable to connect to the API server',
        });
      }
    }
    init();
  }, []);

  // Track if we've already attempted connection to prevent retry loops
  const hasAttemptedConnection = useRef(false);

  // Connect when connection info is available
  // Permission handling is done inside connect() to avoid duplicate getUserMedia calls
  useEffect(() => {
    const startConnection = async () => {
      // Prevent retry loops - only attempt once per mount
      if (hasAttemptedConnection.current) {
        return;
      }

      if (!connectionInfo || isConnected || connectionState !== 'idle' || permissionsLoading) {
        return;
      }

      // Only block if permission was explicitly denied
      if (permissions.microphone === 'denied') {
        setPermissionError('Microphone access was denied. Please enable it in your browser settings.');
        return;
      }

      // Mark that we've attempted connection
      hasAttemptedConnection.current = true;

      // Clear any previous permission error and connect
      // The connect() function handles getUserMedia internally,
      // so we don't need to request permission separately (avoids double prompts)
      setPermissionError(null);

      try {
        await connect(maestro, connectionInfo);
      } catch (error) {
        // Handle permission denial during connect
        if (error instanceof DOMException && error.name === 'NotAllowedError') {
          setPermissionError('Microphone access is required for voice sessions. Please grant permission.');
        }
      }
    };

    startConnection();
  }, [connectionInfo, isConnected, connectionState, maestro, connect, permissions.microphone, permissionsLoading]);

  // Handle close - show grade first
  const handleClose = useCallback(async () => {
    disconnect();

    // C-2 FIX: End conversation and generate summary for memory persistence
    if (conversationIdRef.current && transcript.length > 0) {
      const userId = getUserId();
      if (userId) {
        try {
          const response = await fetch(`/api/conversations/${conversationIdRef.current}/end`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ userId, reason: 'explicit' }),
          });
          if (response.ok) {
            const result = await response.json();
            setSessionSummary(result.summary || null);
            logger.info('[VoiceSession] Conversation ended with summary', {
              conversationId: conversationIdRef.current,
              summaryLength: result.summary?.length || 0,
              topicsCount: result.topics?.length || 0,
            });
          }
        } catch (error) {
          logger.error('[VoiceSession] Failed to end conversation', { error: String(error) });
        }
      }
    }

    // Show grade if session was active
    if (currentSession || transcript.length > 0) {
      // Calculate metrics at the moment of closing (not during render)
      const durationMinutes = Math.round(
        (Date.now() - sessionStartTime.current.getTime()) / 60000
      );
      setFinalSessionDuration(durationMinutes);
      setFinalQuestionCount(questionCount.current);
      setShowGrade(true);
    } else {
      onClose();
    }
  }, [disconnect, onClose, currentSession, transcript]);

  // Handle Escape key to close modal
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        handleClose();
      }
    };
    window.addEventListener('keydown', handleEscape);
    return () => window.removeEventListener('keydown', handleEscape);
  }, [handleClose]);

  // Handle grade close
  const handleGradeClose = useCallback(() => {
    endSession();
    setShowGrade(false);
    onClose();
  }, [endSession, onClose]);

  // XP earned from session
  const xpEarned = currentSession?.xpEarned || Math.max(5, transcript.length * 2);

  // Handle switch to chat
  const handleSwitchToChat = useCallback(() => {
    disconnect();
    onSwitchToChat?.();
  }, [disconnect, onSwitchToChat]);

  // Handle text submit
  const handleTextSubmit = useCallback(() => {
    if (textInput.trim()) {
      sendText(textInput);
      setTextInput('');
    }
  }, [textInput, sendText]);

  // State indicator
  const stateText = configError
    ? 'Errore di configurazione'
    : permissionsLoading
    ? 'Controllo permessi...'
    : connectionState === 'connecting'
    ? 'Connessione in corso...'
    : isListening
    ? 'Ti sto ascoltando...'
    : isSpeaking
    ? `${maestro.name} sta parlando...`
    : isConnected
    ? 'Pronto - parla ora'
    : 'Disconnesso';

  // Manual tool trigger function
  // IMPORTANT: These prompts MUST instruct the AI to USE THE TOOL, not just describe what a tool would do
  const triggerManualTool = useCallback((toolName: string) => {
    if (toolName === 'capture_homework') {
      setWebcamRequest({ purpose: 'homework', instructions: 'Mostra il tuo compito o libro', callId: `manual-${Date.now()}` });
      setShowWebcam(true);
    }
    // For other tools, we send explicit tool-call requests
    else {
      const toolPrompts: Record<string, string> = {
        // Each prompt explicitly asks for tool creation, not description
        mindmap: 'Usa lo strumento create_mindmap per creare ORA una mappa mentale visiva sull\'argomento che stiamo discutendo. Genera i nodi e mostrala.',
        quiz: 'Usa lo strumento create_quiz per creare ORA un quiz interattivo con domande a scelta multipla sull\'argomento. Genera le domande.',
        flashcard: 'Usa lo strumento create_flashcards per creare ORA delle flashcard interattive sugli argomenti trattati. Genera le card.',
        search: 'Usa lo strumento web_search per cercare ORA informazioni aggiornate sull\'argomento.',
      };
      if (toolPrompts[toolName]) {
        sendText(toolPrompts[toolName]);
      }
    }
  }, [sendText]);

  // Show permission error
  if (permissionError) {
    return (
      <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm">
        <motion.div
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          className="w-full max-w-md mx-4"
        >
          <Card className="bg-gradient-to-b from-amber-900 to-slate-950 border-amber-700 text-white">
            <div className="p-6">
              <div className="flex items-center gap-3 mb-4">
                <div className="w-12 h-12 rounded-full bg-amber-500/20 flex items-center justify-center">
                  <AlertCircle className="w-6 h-6 text-amber-400" />
                </div>
                <div>
                  <h2 className="text-xl font-semibold">Permesso Microfono Richiesto</h2>
                  <p className="text-sm text-amber-300">La voce richiede accesso al microfono</p>
                </div>
              </div>

              <div className="bg-amber-950/50 rounded-lg p-4 mb-4">
                <p className="text-sm text-amber-200">{permissionError}</p>
              </div>

              <div className="space-y-2 mb-4">
                <p className="text-sm text-slate-300">Per abilitare il microfono:</p>
                <ol className="text-sm text-slate-400 list-decimal list-inside space-y-1">
                  <li>Clicca sull&apos;icona del lucchetto nella barra degli indirizzi</li>
                  <li>Trova &quot;Microfono&quot; nelle impostazioni del sito</li>
                  <li>Seleziona &quot;Consenti&quot;</li>
                  <li>Ricarica la pagina</li>
                </ol>
              </div>

              <div className="flex gap-2">
                <Button
                  onClick={() => requestMicrophone().then((granted) => {
                    if (granted) setPermissionError(null);
                  })}
                  className="flex-1 bg-amber-600 hover:bg-amber-700"
                >
                  Riprova
                </Button>
                {onSwitchToChat && (
                  <Button
                    onClick={onSwitchToChat}
                    variant="outline"
                    className="flex-1 border-amber-600 text-amber-400 hover:bg-amber-950"
                  >
                    <MessageSquare className="w-4 h-4 mr-2" />
                    Usa Chat Testuale
                  </Button>
                )}
                <Button
                  onClick={onClose}
                  variant="outline"
                  className="flex-1 border-slate-600"
                >
                  Chiudi
                </Button>
              </div>
            </div>
          </Card>
        </motion.div>
      </div>
    );
  }

  // Show configuration error
  if (configError) {
    return (
      <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm">
        <motion.div
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          className="w-full max-w-md mx-4"
        >
          <Card className="bg-gradient-to-b from-red-900 to-slate-950 border-red-700 text-white">
            <div className="p-6">
              <div className="flex items-center gap-3 mb-4">
                <div className="w-12 h-12 rounded-full bg-red-500/20 flex items-center justify-center">
                  <PhoneOff className="w-6 h-6 text-red-400" />
                </div>
                <div>
                  <h2 className="text-xl font-semibold">Azure OpenAI Non Configurato</h2>
                  <p className="text-sm text-red-300">La voce richiede Azure OpenAI Realtime</p>
                </div>
              </div>

              <div className="bg-red-950/50 rounded-lg p-4 mb-4">
                <p className="text-sm text-red-200 mb-2">{configError.message}</p>
                {configError.missingVariables && (
                  <div className="mt-2">
                    <p className="text-xs text-red-300 mb-1">Variabili mancanti:</p>
                    <ul className="text-xs text-red-400 space-y-1">
                      {configError.missingVariables.map((v) => (
                        <li key={v} className="font-mono">- {v}</li>
                      ))}
                    </ul>
                  </div>
                )}
              </div>

              <div className="space-y-2">
                <p className="text-sm text-slate-300">
                  Configura le variabili di ambiente nel file <code className="text-xs bg-slate-800 px-1 rounded">.env.local</code>:
                </p>
                <pre className="text-xs bg-slate-900 p-3 rounded-lg overflow-x-auto">
{`AZURE_OPENAI_REALTIME_ENDPOINT=https://your-resource.openai.azure.com
AZURE_OPENAI_REALTIME_API_KEY=your-api-key
AZURE_OPENAI_REALTIME_DEPLOYMENT=gpt-4o-realtime-preview
AZURE_OPENAI_REALTIME_API_VERSION=2024-10-01-preview`}
                </pre>
              </div>

              <div className="flex gap-2 mt-4">
                {onSwitchToChat && (
                  <Button
                    onClick={onSwitchToChat}
                    className="flex-1 bg-blue-600 hover:bg-blue-700"
                  >
                    <MessageSquare className="w-4 h-4 mr-2" />
                    Usa Chat Testuale
                  </Button>
                )}
                <Button
                  onClick={onClose}
                  className={cn(
                    'bg-red-600 hover:bg-red-700',
                    onSwitchToChat ? 'flex-1' : 'w-full'
                  )}
                >
                  Chiudi
                </Button>
              </div>
            </div>
          </Card>
        </motion.div>
      </div>
    );
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm">
      <motion.div
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        exit={{ opacity: 0, scale: 0.95 }}
        className="w-full max-w-2xl mx-4"
      >
        <Card className="bg-gradient-to-b from-slate-900 to-slate-950 border-slate-700 text-white overflow-hidden">
          {/* Header */}
          <div className="p-6 border-b border-slate-700/50">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-4">
                <div
                  className="w-12 h-12 rounded-full overflow-hidden ring-2 ring-white/20"
                  style={{ backgroundColor: maestro.color }}
                >
                  <Image
                    src={maestro.avatar}
                    alt={maestro.name}
                    width={48}
                    height={48}
                    className="w-full h-full object-cover"
                  />
                </div>
                <div>
                  <h2 className="text-xl font-semibold">{maestro.name}</h2>
                  <p className="text-sm text-slate-400">{maestro.specialty}</p>
                </div>
              </div>
              <Button
                variant="ghost"
                size="icon"
                onClick={handleClose}
                className="text-slate-400 hover:text-white hover:bg-slate-700"
                aria-label="Chiudi sessione"
              >
                <PhoneOff className="h-5 w-5" />
              </Button>
            </div>

            {/* C-6 FIX: Timer + XP Bar */}
            {isConnected && (
              <div className="mt-4 flex items-center gap-4">
                {/* Timer */}
                <div className="flex items-center gap-2 px-3 py-1.5 bg-slate-800/50 rounded-lg">
                  <Clock className="h-4 w-4 text-slate-400" />
                  <span className="text-sm font-mono text-slate-200">{formatTime(elapsedSeconds)}</span>
                </div>

                {/* XP Progress Bar */}
                <div className="flex-1 flex items-center gap-2">
                  <div className="flex items-center gap-1.5">
                    <Trophy className="h-4 w-4 text-amber-400" />
                    <span className="text-xs font-medium text-amber-400">Lv.{level}</span>
                  </div>
                  <div className="flex-1 h-2 bg-slate-800/50 rounded-full overflow-hidden">
                    <div
                      className="h-full bg-gradient-to-r from-amber-500 to-amber-400 transition-all duration-300"
                      style={{ width: `${Math.min(100, Math.max(0, xpProgress))}%` }}
                    />
                  </div>
                  <span className="text-xs text-slate-400">{xp} XP</span>
                </div>
              </div>
            )}
          </div>

          {/* Main visualization */}
          <div className="p-8 flex flex-col items-center gap-6">
            {/* Avatar with waveform */}
            <CircularWaveform
              level={isSpeaking ? outputLevel : inputLevel}
              isActive={isListening || isSpeaking}
              color={maestro.color}
              size={160}
              image={maestro.avatar}
            />

            {/* State indicator */}
            <motion.div
              key={stateText}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              className="text-center"
            >
              <p className="text-lg font-medium text-slate-200">{stateText}</p>
              {connectionState === 'connecting' && (
                <div className="mt-2 flex items-center justify-center gap-1">
                  <div className="w-2 h-2 rounded-full bg-accent-themed animate-pulse" />
                  <div className="w-2 h-2 rounded-full bg-accent-themed animate-pulse delay-100" />
                  <div className="w-2 h-2 rounded-full bg-accent-themed animate-pulse delay-200" />
                </div>
              )}
            </motion.div>

            {/* Waveform visualization */}
            <div className="w-full">
              <CanvasWaveform
                analyser={inputAnalyser}
                isActive={isListening || isSpeaking}
                color={isListening ? '#22C55E' : maestro.color}
                height={64}
              />
            </div>
          </div>

          {/* Transcript */}
          <div className="px-6 pb-4">
            <div className="max-h-48 overflow-y-auto space-y-3 p-4 bg-slate-800/50 rounded-xl">
              <AnimatePresence>
                {transcript.length === 0 ? (
                  <p className="text-center text-slate-500 text-sm italic">
                    {maestro.greeting}
                  </p>
                ) : (
                  transcript.map((entry, index) => (
                    <motion.div
                      key={index}
                      initial={{ opacity: 0, y: 10 }}
                      animate={{ opacity: 1, y: 0 }}
                      className={cn(
                        'p-3 rounded-lg max-w-[85%]',
                        entry.role === 'user'
                          ? 'bg-accent-themed/30 ml-auto text-right'
                          : 'bg-slate-700/50 mr-auto'
                      )}
                    >
                      <p className="text-sm text-slate-200">{entry.content}</p>
                    </motion.div>
                  ))
                )}
              </AnimatePresence>
            </div>
          </div>

          {/* Tool calls visualization */}
          {toolCalls.length > 0 && (
            <div className="px-6 pb-4">
              <div className="space-y-3 p-4 bg-slate-800/30 rounded-xl border border-slate-700/50">
                <div className="flex items-center justify-between">
                  <h4 className="text-sm font-medium text-slate-400">Strumenti utilizzati</h4>
                  <button
                    onClick={clearToolCalls}
                    className="text-xs text-slate-500 hover:text-slate-300"
                  >
                    Cancella
                  </button>
                </div>
                <AnimatePresence>
                  {toolCalls.map((toolCall) => (
                    <motion.div
                      key={toolCall.id}
                      initial={{ opacity: 0, y: 10 }}
                      animate={{ opacity: 1, y: 0 }}
                      exit={{ opacity: 0, y: -10 }}
                    >
                      <ToolResultDisplay toolCall={toolCall} sessionId={voiceSessionId} />
                    </motion.div>
                  ))}
                </AnimatePresence>
              </div>
            </div>
          )}

          {/* Tool buttons */}
          <div className="px-6 py-3 border-t border-slate-700/30 bg-slate-800/20">
            <div className="flex items-center justify-center gap-2 flex-wrap">
              <Button
                variant="ghost"
                size="sm"
                onClick={() => triggerManualTool('capture_homework')}
                className="rounded-full bg-slate-700/50 text-slate-300 hover:bg-slate-600/50 hover:text-white"
                title="Mostra compiti via webcam"
              >
                <Camera className="h-4 w-4 mr-2" />
                <span className="text-xs">Webcam</span>
              </Button>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => triggerManualTool('mindmap')}
                className="rounded-full bg-slate-700/50 text-slate-300 hover:bg-slate-600/50 hover:text-white"
                title="Crea mappa mentale"
              >
                <Network className="h-4 w-4 mr-2" />
                <span className="text-xs">Mappa</span>
              </Button>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => triggerManualTool('quiz')}
                className="rounded-full bg-slate-700/50 text-slate-300 hover:bg-slate-600/50 hover:text-white"
                title="Crea quiz"
              >
                <Brain className="h-4 w-4 mr-2" />
                <span className="text-xs">Quiz</span>
              </Button>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => triggerManualTool('flashcard')}
                className="rounded-full bg-slate-700/50 text-slate-300 hover:bg-slate-600/50 hover:text-white"
                title="Crea flashcard"
              >
                <BookOpen className="h-4 w-4 mr-2" />
                <span className="text-xs">Flashcard</span>
              </Button>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => triggerManualTool('search')}
                className="rounded-full bg-slate-700/50 text-slate-300 hover:bg-slate-600/50 hover:text-white"
                title="Cerca sul web"
              >
                <Search className="h-4 w-4 mr-2" />
                <span className="text-xs">Cerca</span>
              </Button>
            </div>
          </div>

          {/* Controls */}
          <div className="p-6 border-t border-slate-700/50 bg-slate-800/30">
            <div className="flex items-center justify-center gap-4">
              {/* Mute button */}
              <Button
                variant="ghost"
                size="icon-lg"
                onClick={toggleMute}
                title={isMuted ? 'Riattiva microfono' : 'Silenzia microfono'}
                aria-label={isMuted ? 'Riattiva microfono' : 'Silenzia microfono'}
                className={cn(
                  'rounded-full transition-colors',
                  isMuted
                    ? 'bg-red-500/20 text-red-400 hover:bg-red-500/30'
                    : 'bg-slate-700 text-white hover:bg-slate-600'
                )}
              >
                {isMuted ? <MicOff className="h-6 w-6" /> : <Mic className="h-6 w-6" />}
              </Button>

              {/* Cancel response (during speaking) */}
              {isSpeaking && (
                <Button
                  variant="ghost"
                  size="icon-lg"
                  onClick={cancelResponse}
                  title="Interrompi risposta"
                  aria-label="Interrompi risposta"
                  className="rounded-full bg-amber-500/20 text-amber-400 hover:bg-amber-500/30"
                >
                  <VolumeX className="h-6 w-6" />
                </Button>
              )}

              {/* Toggle text input */}
              <Button
                variant="ghost"
                size="icon-lg"
                onClick={() => setShowTextInput(!showTextInput)}
                title="Scrivi un messaggio"
                aria-label="Scrivi un messaggio"
                className="rounded-full bg-slate-700 text-white hover:bg-slate-600"
              >
                <Send className="h-5 w-5" />
              </Button>

              {/* Switch to chat */}
              {onSwitchToChat && (
                <Button
                  variant="ghost"
                  size="icon-lg"
                  onClick={handleSwitchToChat}
                  title="Passa alla chat testuale"
                  aria-label="Passa alla chat testuale"
                  className="rounded-full bg-green-600/20 text-green-400 hover:bg-green-600/30"
                >
                  <MessageSquare className="h-5 w-5" />
                </Button>
              )}

              {/* End call */}
              <Button
                variant="destructive"
                size="icon-lg"
                onClick={handleClose}
                title="Termina sessione"
                aria-label="Termina sessione"
                className="rounded-full"
              >
                <PhoneOff className="h-6 w-6" />
              </Button>
            </div>

            {/* Text input (fallback) */}
            <AnimatePresence>
              {showTextInput && (
                <motion.div
                  initial={{ height: 0, opacity: 0 }}
                  animate={{ height: 'auto', opacity: 1 }}
                  exit={{ height: 0, opacity: 0 }}
                  className="mt-4 overflow-hidden"
                >
                  <div className="flex gap-2">
                    <input
                      type="text"
                      value={textInput}
                      onChange={(e) => setTextInput(e.target.value)}
                      onKeyDown={(e) => e.key === 'Enter' && handleTextSubmit()}
                      placeholder="Scrivi un messaggio..."
                      className="flex-1 px-4 py-2 rounded-xl bg-slate-700 border border-slate-600 text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                    <Button onClick={handleTextSubmit} disabled={!textInput.trim()}>
                      Invia
                    </Button>
                  </div>
                </motion.div>
              )}
            </AnimatePresence>
          </div>
        </Card>
      </motion.div>

      {/* Webcam capture overlay */}
      <AnimatePresence>
        {showWebcam && webcamRequest && (
          <WebcamCapture
            purpose={webcamRequest.purpose}
            instructions={webcamRequest.instructions}
            onCapture={handleWebcamCapture}
            onClose={handleWebcamClose}
          />
        )}
      </AnimatePresence>

      {/* Session grade display */}
      <AnimatePresence>
        {showGrade && (
          <SessionGradeDisplay
            maestro={maestro}
            sessionDuration={finalSessionDuration}
            questionsAsked={finalQuestionCount}
            xpEarned={xpEarned}
            onClose={handleGradeClose}
          />
        )}
      </AnimatePresence>
    </div>
  );
}
