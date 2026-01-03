'use client';

import { useState, useRef, useEffect, useCallback } from 'react';
import { motion } from 'framer-motion';
import { Mic, MicOff, PhoneOff } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { logger } from '@/lib/logger';
import type { ActiveCharacter } from '@/lib/stores/conversation-flow-store';
import type { Maestro, MaestroVoice, Subject } from '@/types';
import { useVoiceSession } from '@/lib/hooks/use-voice-session';
import { CharacterAvatar } from './character-avatar';
import { CharacterRoleBadge } from './character-role-badge';
import { AudioDeviceSelector } from './audio-device-selector';
import { CHARACTER_AVATARS } from './constants';

// C-2 FIX: Helper to get userId from cookie or sessionStorage
function getUserId(): string | null {
  if (typeof window === 'undefined') return null;
  const cookieMatch = document.cookie.match(/mirrorbuddy-user-id=([^;]+)/);
  if (cookieMatch) return cookieMatch[1];
  return sessionStorage.getItem('mirrorbuddy-user-id');
}

/**
 * Voice connection info from /api/realtime/token
 */
interface VoiceConnectionInfo {
  provider: 'azure';
  proxyPort: number;
  configured: boolean;
}

/**
 * Convert ActiveCharacter to Maestro-compatible interface for voice session.
 * Coach and Buddy have all the required voice fields.
 */
function activeCharacterToMaestro(character: ActiveCharacter): Maestro {
  return {
    id: character.id,
    name: character.name,
    subject: 'methodology' as Subject, // Coaches/buddies aren't subject-specific
    specialty: character.type === 'coach' ? 'Metodo di studio' : 'Supporto emotivo',
    voice: (character.voice || 'alloy') as MaestroVoice,
    voiceInstructions: character.voiceInstructions || '',
    teachingStyle: character.type === 'coach' ? 'scaffolding' : 'peer-support',
    avatar: CHARACTER_AVATARS[character.id] || '/avatars/default.jpg',
    color: character.color,
    systemPrompt: character.systemPrompt,
    greeting: character.greeting,
  };
}

interface VoiceCallOverlayProps {
  character: ActiveCharacter;
  onEnd: () => void;
  /** Callback to expose session ID for real-time tool modifications */
  onSessionIdChange?: (sessionId: string | null) => void;
}

/**
 * Voice call overlay with actual Azure Realtime voice session.
 * Issue #34: Now integrates with useVoiceSession hook.
 */
export function VoiceCallOverlay({
  character,
  onEnd,
  onSessionIdChange,
}: VoiceCallOverlayProps) {
  const [connectionInfo, setConnectionInfo] = useState<VoiceConnectionInfo | null>(null);
  const [configError, setConfigError] = useState<string | null>(null);
  const hasAttemptedConnection = useRef(false);

  // C-2 FIX: Track conversation for memory persistence
  const conversationIdRef = useRef<string | null>(null);
  const savedMessagesRef = useRef<Set<string>>(new Set());

  const voiceSession = useVoiceSession({
    onError: (error) => {
      const message = error instanceof Error ? error.message : String(error);
      logger.error('Voice call error', { message });
      setConfigError(message || 'Errore di connessione vocale');
    },
    onTranscript: (role, text) => {
      logger.debug('Voice transcript', { role, text: text.substring(0, 100) });
    },
  });

  // Destructure voice session
  const {
    isConnected,
    isListening,
    isSpeaking,
    isMuted,
    transcript,
    inputLevel,
    connectionState,
    connect,
    disconnect,
    toggleMute,
    sessionId,
  } = voiceSession;

  // Notify parent when sessionId changes (for tool panel SSE subscription)
  useEffect(() => {
    onSessionIdChange?.(sessionId);
  }, [sessionId, onSessionIdChange]);

  // C-2 FIX: Create conversation in DB when voice session connects
  useEffect(() => {
    if (!isConnected || conversationIdRef.current) return;

    const createConversation = async () => {
      try {
        const response = await fetch('/api/conversations', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            maestroId: character.id,
            title: `Sessione vocale con ${character.name}`,
          }),
        });
        if (response.ok) {
          const data = await response.json();
          conversationIdRef.current = data.id;
          logger.debug('[VoiceCallOverlay] Conversation created for memory persistence', { conversationId: data.id });
        }
      } catch (error) {
        logger.error('[VoiceCallOverlay] Failed to create conversation', { error: String(error) });
      }
    };

    createConversation();
  }, [isConnected, character.id, character.name]);

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
          logger.error('[VoiceCallOverlay] Failed to save message', { error: String(error) });
        }
      }
    };

    saveNewMessages();
  }, [transcript]);

  // Fetch connection info on mount
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
        setConnectionInfo(data as VoiceConnectionInfo);
      } catch (error) {
        logger.error('Failed to get voice connection info', { error: String(error) });
        setConfigError('Impossibile connettersi al servizio vocale');
      }
    }
    fetchConnectionInfo();
  }, []);

  // Connect when connection info is available
  useEffect(() => {
    const startConnection = async () => {
      if (hasAttemptedConnection.current) return;
      if (!connectionInfo || isConnected || connectionState !== 'idle') return;

      hasAttemptedConnection.current = true;

      try {
        // Convert character to Maestro-compatible interface
        const maestroLike = activeCharacterToMaestro(character);
        await connect(maestroLike, { ...connectionInfo, characterType: character.type });
      } catch (error) {
        logger.error('Voice connection failed', { error: String(error) });
        if (error instanceof DOMException && error.name === 'NotAllowedError') {
          setConfigError('Microfono non autorizzato. Abilita il microfono nelle impostazioni del browser.');
        } else {
          setConfigError('Errore di connessione vocale');
        }
      }
    };

    startConnection();
  }, [connectionInfo, isConnected, connectionState, character, connect]);

  // Handle end call
  const handleEndCall = useCallback(async () => {
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
            logger.info('[VoiceCallOverlay] Conversation ended with summary', {
              conversationId: conversationIdRef.current,
            });
          }
        } catch (error) {
          logger.error('[VoiceCallOverlay] Failed to end conversation', { error: String(error) });
        }
      }
    }

    onEnd();
  }, [disconnect, onEnd, transcript.length]);

  // Status text
  const getStatusText = () => {
    if (configError) return configError;
    if (connectionState === 'connecting') return 'Connessione in corso...';
    if (isConnected && isSpeaking) return `${character.name} sta parlando...`;
    if (isConnected && isListening) return 'In ascolto...';
    if (isConnected) return 'Connesso';
    return 'Avvio chiamata...';
  };

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      className="absolute inset-0 z-50 flex flex-col items-center justify-center bg-gradient-to-b from-slate-900/95 to-slate-800/95 backdrop-blur-sm"
    >
      <motion.div
        animate={{ scale: isSpeaking ? [1, 1.05, 1] : 1 }}
        transition={{ repeat: Infinity, duration: 2 }}
      >
        <CharacterAvatar character={character} size="xl" showStatus isActive={isConnected} />
      </motion.div>

      <h3 className="mt-4 text-xl font-semibold text-white">{character.name}</h3>
      <CharacterRoleBadge type={character.type} />

      <p className={cn(
        "mt-2 text-sm",
        configError ? "text-red-400" : "text-slate-300"
      )}>
        {getStatusText()}
      </p>

      {/* Input level indicator */}
      {isConnected && isListening && (
        <div className="mt-4 flex items-center gap-2">
          <span
            className="w-2 h-2 rounded-full animate-pulse"
            style={{
              backgroundColor: inputLevel > 0.1 ? '#22c55e' : '#64748b',
              transform: `scale(${1 + inputLevel * 2})`
            }}
          />
          <span className="text-xs text-green-400">
            {isMuted ? 'Microfono disattivato' : 'In ascolto'}
          </span>
        </div>
      )}

      {/* Transcript preview - show only AI responses (more accurate than user transcripts) */}
      {transcript.length > 0 && (
        <div className="mt-4 max-w-md px-4 py-2 bg-slate-800/50 rounded-lg max-h-40 overflow-y-auto">
          <div className="space-y-2">
            {transcript.slice(-3).map((entry, i) => (
              <div key={i} className={cn(
                "text-xs px-2 py-1 rounded",
                entry.role === 'assistant'
                  ? "bg-slate-700/50 text-slate-200"
                  : "text-slate-500 italic"
              )}>
                {entry.role === 'assistant' && (
                  <span className="font-medium text-slate-400 mr-1">{character.name}:</span>
                )}
                {entry.content.substring(0, 120)}
                {entry.content.length > 120 && '...'}
              </div>
            ))}
          </div>
          <p className="text-[10px] text-slate-600 mt-2 text-center">
            Trascrizione approssimativa
          </p>
        </div>
      )}

      {/* Controls */}
      <div className="mt-8 flex items-center gap-4">
        {/* Audio device selector */}
        <AudioDeviceSelector compact />

        {isConnected && (
          <Button
            variant={isMuted ? 'destructive' : 'outline'}
            size="lg"
            onClick={toggleMute}
            aria-label={isMuted ? 'Attiva microfono' : 'Disattiva microfono'}
          >
            {isMuted ? <MicOff className="w-5 h-5" /> : <Mic className="w-5 h-5" />}
          </Button>
        )}

        <Button
          variant="destructive"
          size="lg"
          onClick={handleEndCall}
        >
          <PhoneOff className="w-5 h-5 mr-2" />
          Termina chiamata
        </Button>
      </div>
    </motion.div>
  );
}
