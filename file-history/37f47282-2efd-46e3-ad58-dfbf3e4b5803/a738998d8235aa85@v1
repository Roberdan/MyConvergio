'use client';

import { useState, useRef, useEffect, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import Image from 'next/image';
import {
  Send,
  X,
  Loader2,
  MessageCircle,
  AlertTriangle,
  Shield,
  CheckCircle,
} from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { cn } from '@/lib/utils';
import { getMaestroById } from '@/data/maestri';

interface Message {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  createdAt: Date;
}

interface ParentProfessorChatProps {
  maestroId: string;
  maestroName: string;
  studentId: string;
  studentName: string;
  onClose: () => void;
}

/**
 * ParentProfessorChat - Chat interface for parents to talk with Maestri
 *
 * Features:
 * - Consent modal before first message
 * - All messages saved to database
 * - Parent mode prompts for Maestri
 * - Formal communication style
 */
export function ParentProfessorChat({
  maestroId,
  maestroName,
  studentId,
  studentName,
  onClose,
}: ParentProfessorChatProps) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [inputValue, setInputValue] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [isLoadingHistory, setIsLoadingHistory] = useState(false);
  const [conversationId, setConversationId] = useState<string | null>(null);
  const [showConsentModal, setShowConsentModal] = useState(true);
  const [hasConsented, setHasConsented] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLTextAreaElement>(null);

  const maestro = getMaestroById(maestroId);

  // Check for existing consent and load conversation history
  useEffect(() => {
    const initializeChat = async () => {
      setIsLoadingHistory(true);
      try {
        // Check consent from database
        const consentResponse = await fetch('/api/parent-professor/consent');
        if (consentResponse.ok) {
          const consentData = await consentResponse.json();
          if (consentData.hasConsented) {
            setShowConsentModal(false);
            setHasConsented(true);
          }
        }

        // Load existing conversation for this maestro/student
        const response = await fetch(`/api/parent-professor?studentId=${studentId}&limit=20`);
        if (response.ok) {
          const conversations = await response.json();
          // Find conversation with this maestro
          const existing = conversations.find(
            (c: { maestroId: string }) => c.maestroId === maestroId
          );
          if (existing) {
            // Load full conversation with messages
            const convResponse = await fetch(`/api/parent-professor/${existing.id}`);
            if (convResponse.ok) {
              const convData = await convResponse.json();
              setConversationId(convData.id);
              setMessages(
                convData.messages.map((m: { id: string; role: string; content: string; createdAt: string }) => ({
                  id: m.id,
                  role: m.role as 'user' | 'assistant',
                  content: m.content,
                  createdAt: new Date(m.createdAt),
                }))
              );
            }
          }
        }
      } catch (err) {
        console.error('Failed to initialize chat:', err);
      } finally {
        setIsLoadingHistory(false);
      }
    };

    initializeChat();
  }, [maestroId, studentId]);

  // Scroll to bottom when new messages arrive
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  // Focus input when consent is given
  useEffect(() => {
    if (hasConsented && inputRef.current) {
      inputRef.current.focus();
    }
  }, [hasConsented]);

  // C-19 FIX: Handle Escape key to close modal
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose();
      }
    };
    window.addEventListener('keydown', handleEscape);
    return () => window.removeEventListener('keydown', handleEscape);
  }, [onClose]);

  const handleConsent = useCallback(async () => {
    setShowConsentModal(false);
    setHasConsented(true);
    // Store consent in database
    try {
      await fetch('/api/parent-professor/consent', { method: 'POST' });
    } catch (err) {
      console.error('Failed to save consent:', err);
    }
  }, []);

  const handleSendMessage = async () => {
    if (!inputValue.trim() || isLoading || !hasConsented) return;

    const userMessage: Message = {
      id: `msg-${Date.now()}`,
      role: 'user',
      content: inputValue.trim(),
      createdAt: new Date(),
    };

    setMessages((prev) => [...prev, userMessage]);
    setInputValue('');
    setIsLoading(true);
    setError(null);

    try {
      const response = await fetch('/api/parent-professor', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          maestroId,
          studentId,
          studentName,
          message: userMessage.content,
          conversationId,
          maestroSystemPrompt: maestro?.systemPrompt || '',
          maestroDisplayName: maestroName,
        }),
      });

      if (!response.ok) {
        throw new Error('Errore nella comunicazione con il server');
      }

      const data = await response.json();

      if (data.blocked) {
        setError(data.content);
        return;
      }

      // Save conversation ID for subsequent messages
      if (data.conversationId && !conversationId) {
        setConversationId(data.conversationId);
      }

      const assistantMessage: Message = {
        id: `msg-${Date.now()}-assistant`,
        role: 'assistant',
        content: data.content,
        createdAt: new Date(),
      };

      setMessages((prev) => [...prev, assistantMessage]);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Si e verificato un errore');
    } finally {
      setIsLoading(false);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSendMessage();
    }
  };

  return (
    <>
      {/* Consent Modal */}
      <Dialog open={showConsentModal} onOpenChange={(open) => !open && onClose()}>
        <DialogContent className="sm:max-w-lg">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <Shield className="h-5 w-5 text-indigo-500" />
              Conversazione con {maestroName}
            </DialogTitle>
            <DialogDescription className="text-left space-y-3 pt-4">
              <p>
                Sta per iniziare una conversazione con il Professore {maestroName}
                riguardo al percorso di apprendimento di {studentName}.
              </p>

              <div className="p-3 bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-lg">
                <div className="flex items-start gap-2">
                  <AlertTriangle className="h-5 w-5 text-amber-500 flex-shrink-0 mt-0.5" />
                  <div className="text-sm">
                    <p className="font-medium text-amber-800 dark:text-amber-200">
                      Disclaimer importante
                    </p>
                    <p className="text-amber-700 dark:text-amber-300 mt-1">
                      I Professori sono assistenti AI che forniscono osservazioni pedagogiche.
                      Le loro valutazioni non sostituiscono pareri medici, psicologici o
                      diagnosi professionali. Per questioni cliniche, consultare specialisti qualificati.
                    </p>
                  </div>
                </div>
              </div>

              <div className="space-y-2 text-sm">
                <p className="font-medium">In questa conversazione:</p>
                <ul className="space-y-1.5">
                  <li className="flex items-center gap-2">
                    <CheckCircle className="h-4 w-4 text-green-500" />
                    I messaggi vengono salvati in modo sicuro
                  </li>
                  <li className="flex items-center gap-2">
                    <CheckCircle className="h-4 w-4 text-green-500" />
                    Il Professore utilizza un linguaggio formale
                  </li>
                  <li className="flex items-center gap-2">
                    <CheckCircle className="h-4 w-4 text-green-500" />
                    Le osservazioni si basano sulle sessioni di studio
                  </li>
                </ul>
              </div>
            </DialogDescription>
          </DialogHeader>
          <DialogFooter className="flex-col sm:flex-row gap-2">
            <Button variant="outline" onClick={onClose}>
              Annulla
            </Button>
            <Button onClick={handleConsent} className="bg-indigo-600 hover:bg-indigo-700">
              Ho capito, continua
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Chat Interface */}
      {hasConsented && (
        <motion.div
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          exit={{ opacity: 0, scale: 0.95 }}
          className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm"
        >
          <Card className="w-full max-w-2xl h-[80vh] flex flex-col overflow-hidden">
            {/* Header */}
            <CardHeader className="flex-shrink-0 border-b bg-gradient-to-r from-indigo-50 to-purple-50 dark:from-indigo-900/20 dark:to-purple-900/20">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 rounded-full overflow-hidden border-2 border-white shadow-md">
                    <Image
                      src={maestro?.avatar || `/maestri/${maestroId}.png`}
                      alt={maestroName}
                      width={48}
                      height={48}
                      className="object-cover w-full h-full"
                    />
                  </div>
                  <div>
                    <CardTitle className="text-lg">{maestroName}</CardTitle>
                    <p className="text-sm text-slate-500">
                      Conversazione su {studentName}
                    </p>
                  </div>
                </div>
                <Button variant="ghost" size="icon" onClick={onClose}>
                  <X className="h-5 w-5" />
                </Button>
              </div>
            </CardHeader>

            {/* Messages */}
            <CardContent className="flex-1 overflow-y-auto p-4 space-y-4">
              {isLoadingHistory && (
                <div className="text-center py-8 text-slate-500">
                  <Loader2 className="h-8 w-8 mx-auto mb-3 animate-spin" />
                  <p>Caricamento conversazione...</p>
                </div>
              )}

              {!isLoadingHistory && messages.length === 0 && (
                <div className="text-center py-8 text-slate-500">
                  <MessageCircle className="h-12 w-12 mx-auto mb-3 opacity-50" />
                  <p>Inizia la conversazione con {maestroName}</p>
                  <p className="text-sm mt-1">
                    Chieda informazioni sui progressi di {studentName}
                  </p>
                </div>
              )}

              <AnimatePresence>
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
                      <div className="w-8 h-8 rounded-full overflow-hidden flex-shrink-0">
                        <Image
                          src={maestro?.avatar || `/maestri/${maestroId}.png`}
                          alt={maestroName}
                          width={32}
                          height={32}
                          className="object-cover w-full h-full"
                        />
                      </div>
                    )}
                    <div
                      className={cn(
                        'max-w-[80%] rounded-2xl px-4 py-2',
                        message.role === 'user'
                          ? 'bg-indigo-600 text-white'
                          : 'bg-slate-100 dark:bg-slate-800 text-slate-900 dark:text-white'
                      )}
                    >
                      <p className="whitespace-pre-wrap">{message.content}</p>
                      <p
                        className={cn(
                          'text-xs mt-1',
                          message.role === 'user'
                            ? 'text-indigo-200'
                            : 'text-slate-500'
                        )}
                      >
                        {message.createdAt.toLocaleTimeString('it-IT', {
                          hour: '2-digit',
                          minute: '2-digit',
                        })}
                      </p>
                    </div>
                  </motion.div>
                ))}
              </AnimatePresence>

              {isLoading && (
                <div className="flex gap-3 justify-start">
                  <div className="w-8 h-8 rounded-full overflow-hidden flex-shrink-0">
                    <Image
                      src={maestro?.avatar || `/maestri/${maestroId}.png`}
                      alt={maestroName}
                      width={32}
                      height={32}
                      className="object-cover w-full h-full"
                    />
                  </div>
                  <div className="bg-slate-100 dark:bg-slate-800 rounded-2xl px-4 py-3">
                    <Loader2 className="h-5 w-5 animate-spin text-slate-500" />
                  </div>
                </div>
              )}

              {error && (
                <div className="p-3 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg">
                  <p className="text-sm text-red-700 dark:text-red-300">{error}</p>
                </div>
              )}

              <div ref={messagesEndRef} />
            </CardContent>

            {/* Input */}
            <div className="flex-shrink-0 p-4 border-t bg-white dark:bg-slate-900">
              <div className="flex gap-2">
                <textarea
                  ref={inputRef}
                  value={inputValue}
                  onChange={(e) => setInputValue(e.target.value)}
                  onKeyDown={handleKeyDown}
                  placeholder="Scrivi un messaggio..."
                  className="flex-1 resize-none rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 px-4 py-2 text-slate-900 dark:text-white placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-indigo-500"
                  rows={2}
                  disabled={isLoading}
                />
                <Button
                  onClick={handleSendMessage}
                  disabled={!inputValue.trim() || isLoading}
                  className="bg-indigo-600 hover:bg-indigo-700"
                >
                  <Send className="h-5 w-5" />
                </Button>
              </div>
              <p className="text-xs text-slate-500 mt-2 text-center">
                Le risposte sono generate da AI e potrebbero contenere imprecisioni.
              </p>
            </div>
          </Card>
        </motion.div>
      )}
    </>
  );
}

export default ParentProfessorChat;
