'use client';
// ============================================================================
// MATERIALI CONVERSATION UI (I-03)
// Conversation-first approach for homework help and study materials
// Primary interaction is chat, tools emerge from conversation
// ============================================================================

import { useState, useRef, useEffect, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import Image from 'next/image';
import {
  Send,
  Mic,
  MicOff,
  Paperclip,
  Camera,
  FileText,
  X,
  Loader2,
  ChevronDown,
  Sparkles,
  BookOpen,
  HelpCircle,
  Lightbulb,
  RotateCcw,
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { useAccessibilityStore } from '@/lib/accessibility/accessibility-store';
import { useTTS } from '@/components/accessibility';
import { logger } from '@/lib/logger';
import { Button } from '@/components/ui/button';
import { ToolResultDisplay } from '@/components/tools';
import type { ChatMessage, ToolCall, Maestro } from '@/types';

// Character type - for Melissa/Mario/Maestri (I-04 integration)
interface Character {
  id: string;
  name: string;
  avatar: string;
  color: string;
  role: 'learning_coach' | 'buddy' | 'maestro';
  greeting: string;
  systemPrompt: string;
}

// Default Melissa character (placeholder until AI-01 is done)
const DEFAULT_MELISSA: Character = {
  id: 'melissa',
  name: 'Melissa',
  avatar: '/images/characters/melissa.png',
  color: '#EC4899',
  role: 'learning_coach',
  greeting: 'Ciao! Sono Melissa, la tua coach di studio. Come posso aiutarti oggi?',
  systemPrompt: `Sei Melissa, una giovane learning coach di 27 anni. Sei intelligente, allegra e paziente.
Il tuo compito è guidare lo studente con il metodo maieutico, facendo domande che stimolano il ragionamento.
Non dare mai risposte dirette, ma guida lo studente a trovarle da solo.
Celebra i progressi e incoraggia sempre.
Rispondi SEMPRE in italiano.`,
};

// Attachment type for materials
interface Attachment {
  id: string;
  type: 'image' | 'document';
  name: string;
  url: string;
  mimeType: string;
}

// Extended message with attachments
interface ConversationMessage extends ChatMessage {
  attachments?: Attachment[];
  toolCalls?: ToolCall[];
}

// Quick action buttons
const QUICK_ACTIONS = [
  { id: 'explain', icon: Lightbulb, label: 'Spiegami', prompt: 'Puoi spiegarmi questo concetto in modo semplice?' },
  { id: 'help', icon: HelpCircle, label: 'Ho dubbi', prompt: 'Ho dei dubbi su questo argomento, puoi aiutarmi?' },
  { id: 'practice', icon: BookOpen, label: 'Esercizio', prompt: 'Vorrei fare un esercizio per praticare' },
  { id: 'summary', icon: Sparkles, label: 'Riassunto', prompt: 'Puoi farmi un riassunto di questo?' },
];

interface MaterialiConversationProps {
  character?: Character;
  maestro?: Maestro;
  onSwitchCharacter?: () => void;
  onSwitchToVoice?: () => void;
  className?: string;
}

export function MaterialiConversation({
  character = DEFAULT_MELISSA,
  maestro,
  onSwitchCharacter,
  onSwitchToVoice,
  className,
}: MaterialiConversationProps) {
  // Use maestro if provided, otherwise use character
  const activeCharacter = maestro
    ? {
        id: maestro.id,
        name: maestro.name,
        avatar: maestro.avatar,
        color: maestro.color,
        role: 'maestro' as const,
        greeting: maestro.greeting,
        systemPrompt: maestro.systemPrompt,
      }
    : character;

  // State
  const [messages, setMessages] = useState<ConversationMessage[]>([]);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [attachments, setAttachments] = useState<Attachment[]>([]);
  const [showAttachPanel, setShowAttachPanel] = useState(false);
  const [isVoiceMode, setIsVoiceMode] = useState(false);
  const [showQuickActions, setShowQuickActions] = useState(true);

  // Refs
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLTextAreaElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const cameraInputRef = useRef<HTMLInputElement>(null);

  // Accessibility
  const { settings } = useAccessibilityStore();
  const { speak, enabled: _ttsEnabled } = useTTS();

  // Auto-scroll to bottom
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({
      behavior: settings.reducedMotion ? 'auto' : 'smooth',
    });
  }, [messages, settings.reducedMotion]);

  // Add greeting on mount or character change
  useEffect(() => {
    const greetingMessage: ConversationMessage = {
      id: 'greeting',
      role: 'assistant',
      content: activeCharacter.greeting,
      timestamp: new Date(),
    };
    setMessages([greetingMessage]);
    setShowQuickActions(true);

    if (settings.ttsAutoRead) {
      speak(activeCharacter.greeting);
    }
  }, [activeCharacter.id, activeCharacter.greeting, settings.ttsAutoRead, speak]);

  // Handle file selection
  const handleFileSelect = useCallback(
    async (event: React.ChangeEvent<HTMLInputElement>) => {
      const files = event.target.files;
      if (!files) return;

      for (const file of Array.from(files)) {
        const url = await fileToBase64(file);
        const attachment: Attachment = {
          id: crypto.randomUUID(),
          type: file.type.startsWith('image/') ? 'image' : 'document',
          name: file.name,
          url,
          mimeType: file.type,
        };
        setAttachments((prev) => [...prev, attachment]);
      }

      event.target.value = '';
      setShowAttachPanel(false);
    },
    []
  );

  // Remove attachment
  const removeAttachment = useCallback((id: string) => {
    setAttachments((prev) => prev.filter((a) => a.id !== id));
  }, []);

  // Send message
  const handleSubmit = useCallback(
    async (e?: React.FormEvent) => {
      e?.preventDefault();
      if ((!input.trim() && attachments.length === 0) || isLoading) return;

      const userMessage: ConversationMessage = {
        id: `user-${Date.now()}`,
        role: 'user',
        content: input.trim(),
        timestamp: new Date(),
        attachments: attachments.length > 0 ? [...attachments] : undefined,
      };

      setMessages((prev) => [...prev, userMessage]);
      setInput('');
      setAttachments([]);
      setIsLoading(true);
      setShowQuickActions(false);

      try {
        // Build request with attachments
        const requestBody: Record<string, unknown> = {
          messages: [...messages, userMessage].map((m) => ({
            role: m.role,
            content: m.content,
          })),
          systemPrompt: activeCharacter.systemPrompt,
        };

        // Include image attachments for vision analysis
        if (userMessage.attachments?.some((a) => a.type === 'image')) {
          requestBody.images = userMessage.attachments
            .filter((a) => a.type === 'image')
            .map((a) => a.url);
        }

        const response = await fetch('/api/chat', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(requestBody),
        });

        if (!response.ok) {
          throw new Error('Chat request failed');
        }

        const data = await response.json();

        const assistantMessage: ConversationMessage = {
          id: `assistant-${Date.now()}`,
          role: 'assistant',
          content: data.content,
          timestamp: new Date(),
          tokens: data.usage?.total_tokens,
          toolCalls: data.toolCalls,
        };

        setMessages((prev) => [...prev, assistantMessage]);

        if (settings.ttsAutoRead) {
          speak(data.content);
        }
      } catch (error) {
        logger.error('Materiali conversation error', { error: String(error) });
        const errorMessage: ConversationMessage = {
          id: `error-${Date.now()}`,
          role: 'assistant',
          content: 'Mi scuso, si è verificato un errore. Riprova.',
          timestamp: new Date(),
        };
        setMessages((prev) => [...prev, errorMessage]);
      } finally {
        setIsLoading(false);
        inputRef.current?.focus();
      }
    },
    [
      input,
      attachments,
      isLoading,
      messages,
      activeCharacter.systemPrompt,
      settings.ttsAutoRead,
      speak,
    ]
  );

  // Handle quick action
  const handleQuickAction = useCallback(
    (prompt: string) => {
      setInput(prompt);
      setShowQuickActions(false);
      // Auto-submit after a brief delay
      setTimeout(() => {
        handleSubmit();
      }, 100);
    },
    [handleSubmit]
  );

  // Handle key press
  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        handleSubmit();
      }
    },
    [handleSubmit]
  );

  // Clear conversation
  const clearConversation = useCallback(() => {
    setMessages([
      {
        id: 'greeting',
        role: 'assistant',
        content: activeCharacter.greeting,
        timestamp: new Date(),
      },
    ]);
    setAttachments([]);
    setShowQuickActions(true);
  }, [activeCharacter.greeting]);

  // Toggle voice mode (placeholder for RT-* integration)
  const toggleVoiceMode = useCallback(() => {
    if (onSwitchToVoice) {
      onSwitchToVoice();
    } else {
      setIsVoiceMode((prev) => !prev);
    }
  }, [onSwitchToVoice]);

  return (
    <div
      className={cn(
        'flex flex-col h-full',
        settings.highContrast ? 'bg-black' : 'bg-white dark:bg-slate-900',
        className
      )}
    >
      {/* Header */}
      <header
        className={cn(
          'flex items-center justify-between px-4 py-3 border-b shrink-0',
          settings.highContrast
            ? 'border-yellow-400 bg-black'
            : 'border-slate-200 dark:border-slate-700'
        )}
      >
        <div className="flex items-center gap-3">
          {/* Character avatar - clickable for switching */}
          <button
            onClick={onSwitchCharacter}
            className={cn(
              'relative group',
              onSwitchCharacter && 'cursor-pointer'
            )}
            disabled={!onSwitchCharacter}
            aria-label={onSwitchCharacter ? 'Cambia personaggio' : undefined}
          >
            <div
              className="w-12 h-12 rounded-full overflow-hidden transition-transform group-hover:scale-105"
              style={{ boxShadow: `0 0 0 3px ${activeCharacter.color}` }}
            >
              <Image
                src={activeCharacter.avatar}
                alt={activeCharacter.name}
                width={48}
                height={48}
                className="w-full h-full object-cover"
              />
            </div>
            {onSwitchCharacter && (
              <div className="absolute -bottom-1 -right-1 w-5 h-5 bg-white dark:bg-slate-800 rounded-full flex items-center justify-center shadow-sm">
                <ChevronDown className="w-3 h-3" />
              </div>
            )}
          </button>

          <div>
            <h1
              className={cn(
                'font-semibold text-lg',
                settings.highContrast
                  ? 'text-yellow-400'
                  : 'text-slate-900 dark:text-white'
              )}
            >
              {activeCharacter.name}
            </h1>
            <p
              className={cn(
                'text-xs',
                settings.highContrast ? 'text-gray-400' : 'text-slate-500'
              )}
            >
              {activeCharacter.role === 'learning_coach'
                ? 'Coach di studio'
                : activeCharacter.role === 'buddy'
                  ? 'Compagno di studio'
                  : 'Maestro'}
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          {/* Voice mode toggle */}
          <Button
            variant="ghost"
            size="sm"
            onClick={toggleVoiceMode}
            className={cn(
              isVoiceMode && 'bg-accent-themed text-white hover:opacity-90'
            )}
            aria-label={isVoiceMode ? 'Disattiva voce' : 'Attiva voce'}
          >
            {isVoiceMode ? (
              <Mic className="w-4 h-4" />
            ) : (
              <MicOff className="w-4 h-4" />
            )}
          </Button>

          {/* Clear conversation */}
          <Button
            variant="ghost"
            size="sm"
            onClick={clearConversation}
            aria-label="Nuova conversazione"
          >
            <RotateCcw className="w-4 h-4" />
          </Button>
        </div>
      </header>

      {/* Messages area */}
      <main
        className={cn(
          'flex-1 overflow-y-auto p-4 space-y-4',
          settings.highContrast ? 'bg-black' : ''
        )}
      >
        <AnimatePresence mode="popLayout">
          {messages.map((message) => (
            <motion.div
              key={message.id}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -10 }}
              className={cn(
                'flex gap-3',
                message.role === 'user' ? 'justify-end' : 'justify-start'
              )}
            >
              {/* Avatar for assistant */}
              {message.role === 'assistant' && (
                <div
                  className="w-8 h-8 rounded-full overflow-hidden flex-shrink-0"
                  style={{ boxShadow: `0 0 0 2px ${activeCharacter.color}` }}
                >
                  <Image
                    src={activeCharacter.avatar}
                    alt={activeCharacter.name}
                    width={32}
                    height={32}
                    className="w-full h-full object-cover"
                  />
                </div>
              )}

              {/* Message content */}
              <div className="flex flex-col gap-2 max-w-[80%]">
                {/* Attachments preview */}
                {message.attachments && message.attachments.length > 0 && (
                  <div className="flex flex-wrap gap-2">
                    {message.attachments.map((att) => (
                      <div
                        key={att.id}
                        className="relative w-20 h-20 rounded-lg overflow-hidden border border-slate-200 dark:border-slate-700"
                      >
                        {att.type === 'image' ? (
                          <Image
                            src={att.url}
                            alt={att.name}
                            fill
                            className="object-cover"
                          />
                        ) : (
                          <div className="w-full h-full flex items-center justify-center bg-slate-100 dark:bg-slate-800">
                            <FileText className="w-6 h-6 text-slate-400" />
                          </div>
                        )}
                      </div>
                    ))}
                  </div>
                )}

                {/* Message bubble */}
                {message.content && (
                  <div
                    className={cn(
                      'rounded-2xl px-4 py-3',
                      message.role === 'user'
                        ? settings.highContrast
                          ? 'bg-yellow-400 text-black'
                          : 'bg-accent-themed text-white'
                        : settings.highContrast
                          ? 'bg-gray-900 text-white border border-gray-700'
                          : 'bg-slate-100 dark:bg-slate-800 text-slate-900 dark:text-white',
                      settings.dyslexiaFont && 'tracking-wide'
                    )}
                    style={{ lineHeight: settings.lineSpacing }}
                  >
                    <p className="whitespace-pre-wrap">{message.content}</p>
                  </div>
                )}

                {/* Tool calls */}
                {message.toolCalls && message.toolCalls.length > 0 && (
                  <div className="space-y-2">
                    {message.toolCalls.map((toolCall) => (
                      <ToolResultDisplay key={toolCall.id} toolCall={toolCall} />
                    ))}
                  </div>
                )}
              </div>
            </motion.div>
          ))}
        </AnimatePresence>

        {/* Quick actions (shown after greeting) */}
        {showQuickActions && messages.length === 1 && (
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            className="flex flex-wrap justify-center gap-2 pt-4"
          >
            {QUICK_ACTIONS.map((action) => (
              <Button
                key={action.id}
                variant="outline"
                size="sm"
                onClick={() => handleQuickAction(action.prompt)}
                className="gap-2"
              >
                <action.icon className="w-4 h-4" />
                {action.label}
              </Button>
            ))}
          </motion.div>
        )}

        {/* Loading indicator */}
        {isLoading && (
          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            className="flex gap-3"
          >
            <div
              className="w-8 h-8 rounded-full overflow-hidden flex-shrink-0"
              style={{ boxShadow: `0 0 0 2px ${activeCharacter.color}` }}
            >
              <Image
                src={activeCharacter.avatar}
                alt={activeCharacter.name}
                width={32}
                height={32}
                className="w-full h-full object-cover"
              />
            </div>
            <div
              className={cn(
                'rounded-2xl px-4 py-3 flex items-center gap-2',
                settings.highContrast
                  ? 'bg-gray-900 border border-gray-700'
                  : 'bg-slate-100 dark:bg-slate-800'
              )}
            >
              <Loader2
                className={cn(
                  'w-4 h-4 animate-spin',
                  settings.highContrast ? 'text-yellow-400' : 'text-blue-500'
                )}
              />
              <span
                className={cn(
                  'text-sm',
                  settings.highContrast ? 'text-gray-400' : 'text-slate-500'
                )}
              >
                {activeCharacter.name} sta pensando...
              </span>
            </div>
          </motion.div>
        )}

        <div ref={messagesEndRef} />
      </main>

      {/* Attachment preview bar */}
      <AnimatePresence>
        {attachments.length > 0 && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            className={cn(
              'border-t px-4 py-2',
              settings.highContrast
                ? 'border-yellow-400 bg-black'
                : 'border-slate-200 dark:border-slate-700'
            )}
          >
            <div className="flex gap-2 overflow-x-auto">
              {attachments.map((att) => (
                <div
                  key={att.id}
                  className="relative w-16 h-16 rounded-lg overflow-hidden border border-slate-200 dark:border-slate-700 flex-shrink-0"
                >
                  {att.type === 'image' ? (
                    <Image
                      src={att.url}
                      alt={att.name}
                      fill
                      className="object-cover"
                    />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center bg-slate-100 dark:bg-slate-800">
                      <FileText className="w-4 h-4 text-slate-400" />
                    </div>
                  )}
                  <button
                    onClick={() => removeAttachment(att.id)}
                    className="absolute -top-1 -right-1 w-5 h-5 bg-red-500 text-white rounded-full flex items-center justify-center"
                    aria-label={`Rimuovi ${att.name}`}
                  >
                    <X className="w-3 h-3" />
                  </button>
                </div>
              ))}
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Attachment panel */}
      <AnimatePresence>
        {showAttachPanel && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            className={cn(
              'border-t px-4 py-3',
              settings.highContrast
                ? 'border-yellow-400 bg-gray-900'
                : 'border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800'
            )}
          >
            <div className="flex gap-4 justify-center">
              <button
                onClick={() => cameraInputRef.current?.click()}
                className={cn(
                  'flex flex-col items-center gap-1 p-3 rounded-lg transition-colors',
                  settings.highContrast
                    ? 'hover:bg-yellow-400/20'
                    : 'hover:bg-slate-200 dark:hover:bg-slate-700'
                )}
              >
                <Camera className="w-6 h-6" />
                <span className="text-xs">Fotocamera</span>
              </button>
              <button
                onClick={() => fileInputRef.current?.click()}
                className={cn(
                  'flex flex-col items-center gap-1 p-3 rounded-lg transition-colors',
                  settings.highContrast
                    ? 'hover:bg-yellow-400/20'
                    : 'hover:bg-slate-200 dark:hover:bg-slate-700'
                )}
              >
                <FileText className="w-6 h-6" />
                <span className="text-xs">File</span>
              </button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* C-3 FIX: Input area - sticky at bottom to prevent scrolling away */}
      <footer
        className={cn(
          'border-t p-4 shrink-0 sticky bottom-0 z-10',
          settings.highContrast
            ? 'border-yellow-400 bg-black'
            : 'border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900'
        )}
      >
        <form onSubmit={handleSubmit} className="flex gap-2 items-end">
          {/* Attachment button */}
          <Button
            type="button"
            variant="ghost"
            size="sm"
            onClick={() => setShowAttachPanel(!showAttachPanel)}
            className={cn(showAttachPanel && 'bg-slate-100 dark:bg-slate-800')}
            aria-label="Allega file"
          >
            <Paperclip className="w-5 h-5" />
          </Button>

          {/* Text input */}
          <div className="flex-1 relative">
            <textarea
              ref={inputRef}
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder="Scrivi un messaggio o allega un compito..."
              rows={1}
              className={cn(
                'w-full resize-none rounded-xl px-4 py-3 pr-12 focus:outline-none focus:ring-2',
                settings.highContrast
                  ? 'bg-gray-900 text-white border-2 border-yellow-400 focus:ring-yellow-400'
                  : 'bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 focus:ring-blue-500',
                settings.dyslexiaFont && 'tracking-wide'
              )}
              style={{ lineHeight: settings.lineSpacing }}
              disabled={isLoading}
              aria-label="Messaggio"
            />
          </div>

          {/* Send button */}
          <Button
            type="submit"
            disabled={(!input.trim() && attachments.length === 0) || isLoading}
            style={{
              backgroundColor:
                input.trim() || attachments.length > 0
                  ? activeCharacter.color
                  : undefined,
            }}
            aria-label="Invia messaggio"
          >
            <Send className="w-5 h-5" />
          </Button>
        </form>

        {/* Hidden file inputs */}
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*,.pdf,.doc,.docx"
          multiple
          onChange={handleFileSelect}
          className="hidden"
        />
        <input
          ref={cameraInputRef}
          type="file"
          accept="image/*"
          capture="environment"
          onChange={handleFileSelect}
          className="hidden"
        />
      </footer>
    </div>
  );
}

// Utility: Convert file to base64
function fileToBase64(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result as string);
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
}

export default MaterialiConversation;
