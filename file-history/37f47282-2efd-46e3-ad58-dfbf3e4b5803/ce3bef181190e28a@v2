'use client';

import { useState, useRef, useEffect, useCallback } from 'react';
import Image from 'next/image';
import { motion, AnimatePresence } from 'framer-motion';
import { Send, Loader2, Phone, PhoneOff, Volume2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { logger } from '@/lib/logger';
import { getSupportTeacherById } from '@/data/support-teachers';
import { getBuddyById } from '@/data/buddy-profiles';
import { useVoiceSession } from '@/lib/hooks/use-voice-session';
import { VoicePanel } from '@/components/voice';
import { ToolPanel } from '@/components/tools/tool-panel';
import { ToolButtons } from './tool-buttons';
import { useConversationStore } from '@/lib/stores/app-store';
import type { ExtendedStudentProfile, Subject, Maestro, MaestroVoice } from '@/types';
import type { ToolType, ToolState } from '@/types/tools';

// Map OpenAI function names to ToolType
const FUNCTION_NAME_TO_TOOL_TYPE: Record<string, ToolType> = {
  create_mindmap: 'mindmap',
  create_quiz: 'quiz',
  create_demo: 'demo',
  web_search: 'search',
  create_flashcards: 'flashcard',
  create_diagram: 'diagram',
  create_timeline: 'timeline',
  create_summary: 'summary',
  open_student_summary: 'summary',
};

interface Message {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: Date;
  isVoice?: boolean; // Flag to show voice icon
}

interface CharacterChatViewProps {
  characterId: 'melissa' | 'roberto' | 'chiara' | 'andrea' | 'favij' | 'mario' | 'noemi' | 'enea' | 'bruno' | 'sofia';
  characterType: 'coach' | 'buddy';
}

const CHARACTER_AVATARS: Record<string, string> = {
  mario: '/avatars/mario.jpg',
  noemi: '/avatars/noemi.png',
  enea: '/avatars/enea.png',
  bruno: '/avatars/bruno.png',
  sofia: '/avatars/sofia.png',
  melissa: '/avatars/melissa.jpg',
  roberto: '/avatars/roberto.png',
  chiara: '/avatars/chiara.png',
  andrea: '/avatars/andrea.png',
  favij: '/avatars/favij.jpg',
};

// Default student profile for buddy personalization
const DEFAULT_STUDENT_PROFILE: ExtendedStudentProfile = {
  name: 'Studente',
  age: 14,
  schoolYear: 2,
  schoolLevel: 'media',
  fontSize: 'medium',
  highContrast: false,
  dyslexiaFont: false,
  voiceEnabled: true,
  simplifiedLanguage: false,
  adhdMode: false,
  learningDifferences: [],
};

function getCharacterInfo(characterId: string, characterType: 'coach' | 'buddy') {
  if (characterType === 'coach') {
    const teacher = getSupportTeacherById(characterId as 'melissa' | 'roberto');
    return {
      name: teacher?.name || characterId,
      role: 'Coach di Apprendimento',
      description: teacher?.personality || '',
      greeting: teacher?.greeting || `Ciao! Sono il tuo coach.`,
      avatar: CHARACTER_AVATARS[characterId],
      color: 'from-purple-500 to-indigo-600',
      systemPrompt: teacher?.systemPrompt || '',
      voice: teacher?.voice || 'shimmer',
      voiceInstructions: teacher?.voiceInstructions || '',
      themeColor: teacher?.color || '#EC4899',
    };
  } else {
    const buddy = getBuddyById(characterId as 'mario' | 'noemi');
    const greeting = buddy?.getGreeting?.(DEFAULT_STUDENT_PROFILE) || `Ehi! Piacere di conoscerti!`;
    const systemPrompt = buddy?.getSystemPrompt?.(DEFAULT_STUDENT_PROFILE) || '';
    return {
      name: buddy?.name || characterId,
      role: 'Amico di Studio',
      description: buddy?.personality || '',
      greeting,
      avatar: CHARACTER_AVATARS[characterId],
      color: 'from-pink-500 to-rose-600',
      systemPrompt,
      voice: buddy?.voice || 'ash',
      voiceInstructions: buddy?.voiceInstructions || '',
      themeColor: buddy?.color || '#10B981',
    };
  }
}

interface VoiceConnectionInfo {
  provider: 'azure';
  proxyPort: number;
  configured: boolean;
}

function characterToMaestro(character: ReturnType<typeof getCharacterInfo>, characterId: string): Maestro {
  return {
    id: characterId,
    name: character.name,
    subject: 'methodology' as Subject,
    specialty: character.role,
    voice: character.voice as MaestroVoice,
    voiceInstructions: character.voiceInstructions,
    teachingStyle: 'scaffolding',
    avatar: character.avatar || '/avatars/default.jpg',
    color: character.themeColor,
    systemPrompt: character.systemPrompt,
    greeting: character.greeting,
  };
}


export function CharacterChatView({ characterId, characterType }: CharacterChatViewProps) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [isVoiceActive, setIsVoiceActive] = useState(false);
  const [connectionInfo, setConnectionInfo] = useState<VoiceConnectionInfo | null>(null);
  const [configError, setConfigError] = useState<string | null>(null);
  const [activeTool, setActiveTool] = useState<ToolState | null>(null);
  const [isToolMinimized, setIsToolMinimized] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLTextAreaElement>(null);
  const hasAttemptedConnection = useRef(false);
  const lastTranscriptIdRef = useRef<string | null>(null);
  const conversationIdRef = useRef<string | null>(null);
  const hasLoadedMessages = useRef(false);
  const lastCharacterIdRef = useRef<string | null>(null);

  // Conversation persistence
  const { conversations, createConversation, addMessage: addMessageToStore } = useConversationStore();

  // C-5 FIX: Reset conversation state when character changes
  useEffect(() => {
    if (lastCharacterIdRef.current !== null && lastCharacterIdRef.current !== characterId) {
      // Character changed - reset state to load new character's conversation
      hasLoadedMessages.current = false;
      setMessages([]);
      conversationIdRef.current = null;
    }
    lastCharacterIdRef.current = characterId;
  }, [characterId]);

  const character = getCharacterInfo(characterId, characterType);

  // Voice session with transcript callback that syncs to messages
  const voiceSession = useVoiceSession({
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

      setMessages(prev => [...prev, {
        id: transcriptId,
        role: role as 'user' | 'assistant',
        content: text,
        timestamp: new Date(),
        isVoice: true,
      }]);
    },
  });

  // Destructure voice session
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
  } = voiceSession;

  // Fetch voice connection info
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

  // Connect when voice is activated
  useEffect(() => {
    const startConnection = async () => {
      if (!isVoiceActive || hasAttemptedConnection.current) return;
      if (!connectionInfo || isConnected || connectionState !== 'idle') return;

      hasAttemptedConnection.current = true;
      setConfigError(null);

      try {
        const maestroLike = characterToMaestro(character, characterId);
        await connect(maestroLike, connectionInfo);
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
  }, [isVoiceActive, connectionInfo, isConnected, connectionState, character, characterId, connect]);

  // Reset connection attempt flag when voice is deactivated
  useEffect(() => {
    if (!isVoiceActive) {
      hasAttemptedConnection.current = false;
    }
  }, [isVoiceActive]);

  // Handle voice call toggle
  const handleVoiceCall = useCallback(() => {
    if (isVoiceActive) {
      disconnect();
    }
    setIsVoiceActive(prev => !prev);
  }, [isVoiceActive, disconnect]);

  // Scroll to bottom when messages change
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  // C-13 FIX: Load or create conversation on mount - fetch messages from server
  useEffect(() => {
    if (hasLoadedMessages.current) return;
    hasLoadedMessages.current = true;

    async function initConversation() {
      // Find existing conversation for this character
      const existingConv = conversations.find(c => c.maestroId === characterId);

      if (existingConv) {
        conversationIdRef.current = existingConv.id;

        // C-13 FIX: Fetch messages from server (store only has empty array)
        try {
          const response = await fetch(`/api/conversations/${existingConv.id}`);
          if (response.ok) {
            const convData = await response.json();
            if (convData.messages && convData.messages.length > 0) {
              setMessages(convData.messages.map((m: { id: string; role: string; content: string; createdAt: string }) => ({
                id: m.id,
                role: m.role as 'user' | 'assistant',
                content: m.content,
                timestamp: new Date(m.createdAt),
              })));
              logger.debug('Loaded messages from server', { characterId, messageCount: convData.messages.length });
              return;
            }
          }
        } catch (error) {
          logger.warn('Failed to load messages from server', { error: String(error) });
        }

        // Fallback: use store messages if available
        if (existingConv.messages.length > 0) {
          setMessages(existingConv.messages.map(m => ({
            id: m.id,
            role: m.role as 'user' | 'assistant',
            content: m.content,
            timestamp: new Date(m.timestamp),
          })));
          logger.debug('Loaded existing conversation from store', { characterId, messageCount: existingConv.messages.length });
          return;
        }
      }

      // Create new conversation
      const newConvId = await createConversation(characterId);
      conversationIdRef.current = newConvId;

      // Add greeting
      const greetingMessage = {
        id: 'greeting',
        role: 'assistant' as const,
        content: character.greeting,
        timestamp: new Date(),
      };
      setMessages([greetingMessage]);

      // Persist greeting
      await addMessageToStore(newConvId, {
        role: 'assistant',
        content: character.greeting,
      });
      logger.debug('Created new conversation', { characterId, convId: newConvId });
    }

    initConversation();
  }, [characterId, character.greeting, conversations, createConversation, addMessageToStore]);

  const handleSend = useCallback(async () => {
    if (!input.trim() || isLoading) return;

    const userMessage: Message = {
      id: `user-${Date.now()}`,
      role: 'user',
      content: input.trim(),
      timestamp: new Date(),
    };

    setMessages(prev => [...prev, userMessage]);
    setInput('');
    setIsLoading(true);

    // Persist user message
    if (conversationIdRef.current) {
      addMessageToStore(conversationIdRef.current, {
        role: 'user',
        content: userMessage.content,
      });
    }

    try {
      const response = await fetch('/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          messages: [
            ...messages.map(m => ({ role: m.role, content: m.content })),
            { role: 'user', content: userMessage.content },
          ],
          systemPrompt: character.systemPrompt,
          maestroId: characterId,
          enableTools: true,
        }),
      });

      if (!response.ok) throw new Error('Failed to send message');

      const data = await response.json();

      // ADR 0020: Generate contextual fallback if AI made tool calls but no content
      let responseContent = data.content || data.message;
      if (!responseContent || responseContent.trim() === '') {
        if (data.toolCalls && data.toolCalls.length > 0) {
          const toolNames = data.toolCalls.map((tc: { type?: string }) => tc.type);
          if (toolNames.includes('create_mindmap')) {
            responseContent = 'Ti sto creando la mappa mentale...';
          } else if (toolNames.includes('create_quiz')) {
            responseContent = 'Ti sto preparando il quiz...';
          } else if (toolNames.includes('create_flashcards')) {
            responseContent = 'Ti sto creando le flashcard...';
          } else if (toolNames.includes('create_summary')) {
            responseContent = 'Ti sto preparando il riassunto...';
          } else {
            responseContent = 'Sto elaborando la tua richiesta...';
          }
        } else {
          responseContent = 'Mi dispiace, non ho capito. Puoi ripetere?';
        }
      }

      const assistantMessage: Message = {
        id: `assistant-${Date.now()}`,
        role: 'assistant',
        content: responseContent,
        timestamp: new Date(),
      };

      setMessages(prev => [...prev, assistantMessage]);

      // Persist assistant message
      if (conversationIdRef.current) {
        addMessageToStore(conversationIdRef.current, {
          role: 'assistant',
          content: assistantMessage.content,
        });
      }

      // Handle tool calls if any - update activeTool state
      if (data.toolCalls && data.toolCalls.length > 0) {
        const toolCall = data.toolCalls[0];
        // Map function name (create_quiz) to tool type (quiz)
        const toolType = FUNCTION_NAME_TO_TOOL_TYPE[toolCall.type] || toolCall.type as ToolType;
        // Extract actual data from result object
        const toolContent = toolCall.result?.data || toolCall.result || toolCall.arguments;
        setActiveTool({
          id: toolCall.id,
          type: toolType,
          status: 'completed',
          progress: 1,
          content: toolContent,
          createdAt: new Date(),
        });
      }
    } catch (error) {
      logger.error('Chat error', { error });
      setMessages(prev => [...prev, {
        id: `error-${Date.now()}`,
        role: 'assistant',
        content: 'Mi dispiace, c\'è stato un errore. Riprova tra poco!',
        timestamp: new Date(),
      }]);
    } finally {
      setIsLoading(false);
    }
  }, [input, isLoading, messages, character.systemPrompt, characterId, addMessageToStore]);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  // Handle tool button requests (like maestro chat)
  const handleToolRequest = useCallback(async (toolType: ToolType) => {
    if (isLoading) return;

    setIsLoading(true);

    // Create initial tool state
    const newTool: ToolState = {
      id: `tool-${Date.now()}`,
      type: toolType,
      status: 'initializing',
      progress: 0,
      content: null,
      createdAt: new Date(),
    };
    setActiveTool(newTool);

    // Build the request message based on tool type
    const toolPrompts: Partial<Record<ToolType, string>> = {
      mindmap: 'Crea una mappa mentale sull\'argomento che stiamo studiando',
      quiz: 'Fammi un quiz per verificare cosa ho capito',
      flashcard: 'Crea delle flashcard per aiutarmi a memorizzare',
      demo: 'Mostrami una demo interattiva',
      summary: 'Fammi un riassunto strutturato',
      diagram: 'Crea un diagramma',
      timeline: 'Crea una linea del tempo',
    };

    const userMessage: Message = {
      id: `user-${Date.now()}`,
      role: 'user',
      content: toolPrompts[toolType] || `Usa lo strumento ${toolType}`,
      timestamp: new Date(),
    };

    setMessages(prev => [...prev, userMessage]);

    try {
      const response = await fetch('/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          messages: [
            ...messages.map(m => ({ role: m.role, content: m.content })),
            { role: 'user', content: userMessage.content },
          ],
          systemPrompt: character.systemPrompt,
          maestroId: characterId,
          enableTools: true,
          requestedTool: toolType === 'flashcard' ? 'flashcard' : toolType,
        }),
      });

      if (!response.ok) throw new Error('Failed to request tool');

      const data = await response.json();

      const assistantMessage: Message = {
        id: `assistant-${Date.now()}`,
        role: 'assistant',
        content: data.content || '',
        timestamp: new Date(),
      };

      if (data.content) {
        setMessages(prev => [...prev, assistantMessage]);
      }

      // Update tool state based on response
      if (data.toolCalls?.length > 0) {
        const toolCall = data.toolCalls[0];
        // Map function name (create_quiz) to tool type (quiz)
        const mappedToolType = FUNCTION_NAME_TO_TOOL_TYPE[toolCall.type] || toolType;
        // Extract actual data from result object
        const toolContent = toolCall.result?.data || toolCall.result || toolCall.arguments;
        setActiveTool({
          ...newTool,
          type: mappedToolType,
          status: 'completed',
          progress: 1,
          content: toolContent,
        });
      } else {
        // No tool was created, clear the state
        setActiveTool(null);
      }
    } catch (error) {
      logger.error('Tool request error', { error });
      setMessages(prev => [...prev, {
        id: `error-${Date.now()}`,
        role: 'assistant',
        content: 'Mi dispiace, non sono riuscito a creare lo strumento. Riprova?',
        timestamp: new Date(),
      }]);
      setActiveTool({
        ...newTool,
        status: 'error',
        error: 'Errore nella creazione dello strumento',
      });
    } finally {
      setIsLoading(false);
    }
  }, [isLoading, messages, character.systemPrompt, characterId]);

  // Check if tool is active for layout
  const hasActiveTool = activeTool && activeTool.status !== 'error';

  return (
    <div className="flex gap-4 h-[calc(100vh-8rem)]">
      {/* Main Chat Area */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Chat Header */}
        <div className={cn(
          'flex items-center gap-4 p-4 rounded-t-2xl bg-gradient-to-r text-white',
          character.color
        )}>
          <div className="relative">
            {character.avatar ? (
              <Image
                src={character.avatar}
                alt={character.name}
                width={56}
                height={56}
                className="rounded-full border-2 border-white/30 object-cover"
              />
            ) : (
              <div className="w-14 h-14 rounded-full bg-white/20 flex items-center justify-center text-2xl font-bold">
                {character.name.charAt(0)}
              </div>
            )}
            <span className={cn(
              "absolute bottom-0 right-0 w-4 h-4 border-2 border-white rounded-full",
              isVoiceActive && isConnected ? "bg-green-400 animate-pulse" : "bg-green-400"
            )} />
          </div>
          <div className="flex-1 min-w-0">
            <h2 className="text-xl font-bold truncate">{character.name}</h2>
            <p className="text-sm text-white/80 truncate">
              {isVoiceActive && isConnected ? 'In chiamata vocale' : character.role}
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
        </div>

        {/* Messages Area */}
        <div className="flex-1 overflow-y-auto p-4 space-y-4 bg-slate-50 dark:bg-slate-900/50">
          {messages.map((message) => (
            <motion.div
              key={message.id}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              className={cn(
                'flex gap-3',
                message.role === 'user' ? 'justify-end' : 'justify-start'
              )}
            >
              {message.role === 'assistant' && (
                <div className="flex-shrink-0">
                  {character.avatar ? (
                    <Image
                      src={character.avatar}
                      alt={character.name}
                      width={36}
                      height={36}
                      className="rounded-full object-cover"
                    />
                  ) : (
                    <div className="w-9 h-9 rounded-full bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center text-white text-sm font-bold">
                      {character.name.charAt(0)}
                    </div>
                  )}
                </div>
              )}
              <div
                className={cn(
                  'max-w-[75%] rounded-2xl px-4 py-3',
                  message.role === 'user'
                    ? 'bg-accent-themed text-white rounded-br-md'
                    : 'bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 rounded-bl-md shadow-sm'
                )}
              >
                <p className="text-sm whitespace-pre-wrap">{message.content}</p>
                <div className="flex items-center gap-2 mt-1">
                  {message.isVoice && (
                    <Volume2 className="w-3 h-3 opacity-60" />
                  )}
                  <p className="text-xs opacity-60">
                    {message.timestamp.toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' })}
                  </p>
                </div>
              </div>
            </motion.div>
          ))}
          {isLoading && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              className="flex gap-3"
            >
              <div className="flex-shrink-0">
                {character.avatar ? (
                  <Image
                    src={character.avatar}
                    alt={character.name}
                    width={36}
                    height={36}
                    className="rounded-full object-cover"
                  />
                ) : (
                  <div className="w-9 h-9 rounded-full bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center text-white text-sm font-bold">
                    {character.name.charAt(0)}
                  </div>
                )}
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
          {/* Tool Buttons - only for coaches */}
          {characterType === 'coach' && (
            <ToolButtons
              onToolRequest={handleToolRequest}
              disabled={isLoading}
              activeToolId={activeTool?.id}
            />
          )}
          <div className="flex gap-3">
            <textarea
              ref={inputRef}
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder={isVoiceActive ? 'Parla o scrivi...' : `Scrivi un messaggio a ${character.name}...`}
              className="flex-1 resize-none rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800 px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-accent-themed"
              rows={1}
              disabled={isLoading}
            />
            <Button
              onClick={handleSend}
              disabled={!input.trim() || isLoading}
              className="bg-accent-themed hover:bg-accent-themed/90"
            >
              {isLoading ? (
                <Loader2 className="h-5 w-5 animate-spin" />
              ) : (
                <Send className="h-5 w-5" />
              )}
            </Button>
          </div>
        </div>
      </div>

      {/* Tool Panel - shown when tool is active */}
      {hasActiveTool && (
        <div className="w-[400px] h-full flex-shrink-0 overflow-hidden rounded-xl border border-slate-200 dark:border-slate-700">
          <ToolPanel
            tool={activeTool}
            maestro={{
              name: character.name,
              avatar: character.avatar || '/avatars/default.jpg',
              color: character.themeColor,
            }}
            onClose={() => setActiveTool(null)}
            isMinimized={isToolMinimized}
            onToggleMinimize={() => setIsToolMinimized(!isToolMinimized)}
            embedded={true}
            sessionId={voiceSessionId}
          />
        </div>
      )}

      {/* Voice Panel (Side by Side) */}
      <AnimatePresence>
        {isVoiceActive && (
          <VoicePanel
            character={{
              name: character.name,
              avatar: character.avatar,
              specialty: character.role,
              color: character.color,
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
