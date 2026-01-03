// ============================================================================
// MIRRORBUDDY - VOICE SESSION HOOK (REWRITTEN)
// Azure OpenAI Realtime API with proper audio handling
// ============================================================================

'use client';

import { useCallback, useRef, useEffect, useState } from 'react';
import { logger } from '@/lib/logger';
import { useVoiceSessionStore, useSettingsStore } from '@/lib/stores/app-store';
import type { Maestro } from '@/types';
import {
  VOICE_TOOLS,
  TOOL_USAGE_INSTRUCTIONS,
  executeVoiceTool,
  isToolCreationCommand,
  isOnboardingCommand,
  getToolTypeFromName,
} from '@/lib/voice';
import { useMethodProgressStore } from '@/lib/stores/method-progress-store';
import type { ToolType as MethodToolType, HelpLevel } from '@/lib/method-progress/types';

// ============================================================================
// TYPES
// ============================================================================

interface UseVoiceSessionOptions {
  onTranscript?: (role: 'user' | 'assistant', text: string) => void;
  onError?: (error: Error) => void;
  onStateChange?: (state: 'idle' | 'connecting' | 'connected' | 'error') => void;
  onWebcamRequest?: (request: { purpose: string; instructions?: string; callId: string }) => void;
  /** Disable barge-in to prevent echo loop (speaker→mic→VAD→cancel) */
  disableBargeIn?: boolean;
  /** Noise reduction type: 'near_field' for headphones, 'far_field' for laptop speakers with echo */
  noiseReductionType?: 'near_field' | 'far_field';
}

interface ConnectionInfo {
  provider: 'azure' | 'openai';
  proxyPort?: number;
  configured?: boolean;
  wsUrl?: string;
  token?: string;
  characterType?: 'maestro' | 'coach' | 'buddy';
}

interface ConversationMemory {
  summary?: string;
  keyFacts?: {
    decisions?: string[];
    preferences?: string[];
    learned?: string[];
  };
  recentTopics?: string[];
}

// ============================================================================
// CONSTANTS
// ============================================================================

const AZURE_SAMPLE_RATE = 24000; // Azure uses 24kHz
const MAX_QUEUE_SIZE = 100; // Limit queue to prevent memory issues
const CAPTURE_BUFFER_SIZE = 4096; // ~85ms at 48kHz

// Audio playback tuning parameters
const MIN_BUFFER_CHUNKS = 3; // Wait for N chunks before starting playback (~300ms buffer)
const SCHEDULE_AHEAD_TIME = 0.1; // Schedule chunks 100ms ahead
const CHUNK_GAP_TOLERANCE = 0.02; // 20ms tolerance for scheduling gaps

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Sanitize text by removing HTML comments completely.
 * Uses a loop-based approach with combined regex to handle nested/overlapping
 * patterns that could bypass single-pass sanitization.
 * Per CodeQL docs: combines patterns in single regex with alternation.
 * Note: This sanitizes TRUSTED internal strings (maestro definitions), not user input.
 * @see https://codeql.github.com/codeql-query-help/javascript/js-incomplete-multi-character-sanitization/
 */
function sanitizeHtmlComments(text: string): string {
  let result = text;
  let previousResult: string;

  // Loop until no more changes occur (handles nested patterns like <!---->)
  // Uses combined regex with alternation as recommended by CodeQL docs
  // Handles all standard HTML comment variations including --!> (browser quirk)
  do {
    previousResult = result;
    // Remove complete HTML comments (including --!> variant), then orphaned markers
    result = result.replace(/<!--[\s\S]*?(?:--|--!)>|<!--|(?:--|--!)>/g, '');
  } while (result !== previousResult);

  return result;
}

async function fetchConversationMemory(maestroId: string): Promise<ConversationMemory | null> {
  try {
    const response = await fetch(`/api/conversations?maestroId=${maestroId}&limit=1`);
    if (!response.ok) return null;
    const conversations = await response.json();
    if (!conversations || conversations.length === 0) return null;
    const conv = conversations[0];
    return {
      summary: conv.summary,
      keyFacts: conv.keyFacts ? (typeof conv.keyFacts === 'string' ? JSON.parse(conv.keyFacts) : conv.keyFacts) : undefined,
      recentTopics: conv.topics ? (typeof conv.topics === 'string' ? JSON.parse(conv.topics) : conv.topics) : undefined,
    };
  } catch {
    return null;
  }
}

function buildMemoryContext(memory: ConversationMemory | null): string {
  if (!memory) return '';
  let context = '\n\n## MEMORIA DELLE CONVERSAZIONI PRECEDENTI\n';
  context += 'Ricordi importanti dalle sessioni precedenti con questo studente:\n\n';
  if (memory.summary) {
    context += `### Riassunto:\n${memory.summary}\n\n`;
  }
  if (memory.keyFacts?.learned?.length) {
    context += `### Concetti capiti:\n`;
    memory.keyFacts.learned.forEach(l => { context += `- ${l}\n`; });
    context += '\n';
  }
  if (memory.keyFacts?.preferences?.length) {
    context += `### Preferenze:\n`;
    memory.keyFacts.preferences.forEach(p => { context += `- ${p}\n`; });
    context += '\n';
  }
  if (memory.recentTopics?.length) {
    context += `### Argomenti recenti:\n`;
    memory.recentTopics.forEach(t => { context += `- ${t}\n`; });
    context += '\n';
  }
  context += `\n**USA QUESTE INFORMAZIONI** per personalizzare la lezione.\n`;
  return context;
}

// Audio conversion utilities
function base64ToInt16Array(base64: string): Int16Array {
  const binaryString = atob(base64);
  const bytes = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return new Int16Array(bytes.buffer);
}

function int16ArrayToBase64(int16Array: Int16Array): string {
  const bytes = new Uint8Array(int16Array.buffer);
  let binaryString = '';
  for (let i = 0; i < bytes.length; i++) {
    binaryString += String.fromCharCode(bytes[i]);
  }
  return btoa(binaryString);
}

function float32ToInt16(float32Array: Float32Array): Int16Array {
  const int16Array = new Int16Array(float32Array.length);
  for (let i = 0; i < float32Array.length; i++) {
    const sample = Math.max(-1, Math.min(1, float32Array[i]));
    int16Array[i] = sample < 0 ? sample * 0x8000 : sample * 0x7FFF;
  }
  return int16Array;
}

function int16ToFloat32(int16Array: Int16Array): Float32Array {
  const float32Array = new Float32Array(int16Array.length);
  for (let i = 0; i < int16Array.length; i++) {
    float32Array[i] = int16Array[i] / (int16Array[i] < 0 ? 0x8000 : 0x7FFF);
  }
  return float32Array;
}

function resample(inputData: Float32Array, fromRate: number, toRate: number): Float32Array {
  if (fromRate === toRate) return inputData;
  const ratio = fromRate / toRate;
  const outputLength = Math.floor(inputData.length / ratio);
  const output = new Float32Array(outputLength);
  for (let i = 0; i < outputLength; i++) {
    const srcIndex = i * ratio;
    const srcIndexFloor = Math.floor(srcIndex);
    const srcIndexCeil = Math.min(srcIndexFloor + 1, inputData.length - 1);
    const fraction = srcIndex - srcIndexFloor;
    output[i] = inputData[srcIndexFloor] * (1 - fraction) + inputData[srcIndexCeil] * fraction;
  }
  return output;
}

// ============================================================================
// MAIN HOOK
// ============================================================================

export function useVoiceSession(options: UseVoiceSessionOptions = {}) {
  const {
    isConnected,
    isListening,
    isSpeaking,
    isMuted,
    currentMaestro,
    transcript,
    toolCalls,
    inputLevel,
    outputLevel,
    setConnected,
    setListening,
    setSpeaking,
    setMuted,
    setCurrentMaestro,
    addTranscript,
    clearTranscript,
    addToolCall,
    updateToolCall,
    clearToolCalls,
    setInputLevel,
    setOutputLevel,
    reset,
  } = useVoiceSessionStore();

  // Get preferred devices from settings
  // Note: Voice VAD settings are now hardcoded to optimal values in session config
  // and can be adjusted in /test-voice for debugging
  const {
    preferredMicrophoneId,
    preferredOutputId,
    voiceBargeInEnabled,
  } = useSettingsStore();

  // ============================================================================
  // REFS
  // ============================================================================

  const wsRef = useRef<WebSocket | null>(null);
  const maestroRef = useRef<Maestro | null>(null);

  // SEPARATE contexts for capture and playback - CRITICAL FIX!
  const captureContextRef = useRef<AudioContext | null>(null);
  const playbackContextRef = useRef<AudioContext | null>(null);

  const mediaStreamRef = useRef<MediaStream | null>(null);
  const sourceNodeRef = useRef<MediaStreamAudioSourceNode | null>(null);
  const processorRef = useRef<ScriptProcessorNode | null>(null);
  const analyserRef = useRef<AnalyserNode | null>(null);

  const audioQueueRef = useRef<Int16Array[]>([]);
  const isPlayingRef = useRef(false);
  const lastLevelUpdateRef = useRef<number>(0);
  const playNextChunkRef = useRef<(() => void) | null>(null);

  // Time-based scheduling for smooth audio playback
  const nextPlayTimeRef = useRef<number>(0);
  const scheduledSourcesRef = useRef<AudioBufferSourceNode[]>([]);
  const isBufferingRef = useRef(true); // Start in buffering mode

  // Flag to track if session is fully ready
  const sessionReadyRef = useRef(false);
  const greetingSentRef = useRef(false);

  // Track if Azure has an active response (for proper response.cancel handling)
  // This prevents sending response.cancel when no response is active
  const hasActiveResponseRef = useRef(false);

  // REF to hold latest handleServerEvent callback (avoids stale closure in ws.onmessage)
  const handleServerEventRef = useRef<((event: Record<string, unknown>) => void) | null>(null);

  // Stable session ID for the entire voice conversation (used for tool SSE subscriptions)
  const sessionIdRef = useRef<string | null>(null);

  const [connectionState, setConnectionState] = useState<'idle' | 'connecting' | 'connected' | 'error'>('idle');

  // ============================================================================
  // AUDIO PLAYBACK (at 24kHz) - SYNC VERSION (like test page that works!)
  // ============================================================================

  const initPlaybackContext = useCallback(async () => {
    if (playbackContextRef.current) {
      // Resume if suspended (browser policy requires user interaction)
      if (playbackContextRef.current.state === 'suspended') {
        logger.debug('[VoiceSession] 🔊 Resuming suspended AudioContext...');
        await playbackContextRef.current.resume();
      }
      return playbackContextRef.current;
    }

    const AudioContextClass = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
    // CRITICAL: Create playback context at 24kHz to match Azure output
    playbackContextRef.current = new AudioContextClass({ sampleRate: AZURE_SAMPLE_RATE });
    logger.debug(`[VoiceSession] 🔊 Playback context created at ${AZURE_SAMPLE_RATE}Hz, state: ${playbackContextRef.current.state}`);

    // Set output device if specified (setSinkId API)
    if (preferredOutputId && 'setSinkId' in playbackContextRef.current) {
      try {
        await (playbackContextRef.current as AudioContext & { setSinkId: (id: string) => Promise<void> }).setSinkId(preferredOutputId);
        logger.debug(`[VoiceSession] 🔊 Audio output set to device: ${preferredOutputId}`);
      } catch (err) {
        logger.warn('[VoiceSession] ⚠️ Could not set output device, using default', { err });
      }
    }

    // Resume immediately if suspended
    if (playbackContextRef.current.state === 'suspended') {
      logger.debug('[VoiceSession] 🔊 Resuming new AudioContext...');
      await playbackContextRef.current.resume();
    }

    return playbackContextRef.current;
  }, [preferredOutputId]);

  // =========================================================================
  // TIME-BASED SCHEDULED PLAYBACK
  // Uses AudioContext.currentTime for precise scheduling to prevent stuttering
  // =========================================================================

  // Schedule all queued chunks for playback
  const scheduleQueuedChunks = useCallback(() => {
    const ctx = playbackContextRef.current;
    if (!ctx || audioQueueRef.current.length === 0) return;

    const currentTime = ctx.currentTime;

    // Schedule chunks from queue
    while (audioQueueRef.current.length > 0) {
      const audioData = audioQueueRef.current.shift()!;
      const float32Data = int16ToFloat32(audioData);

      // Create buffer at 24kHz
      const buffer = ctx.createBuffer(1, float32Data.length, AZURE_SAMPLE_RATE);
      buffer.getChannelData(0).set(float32Data);

      const source = ctx.createBufferSource();
      source.buffer = buffer;
      source.connect(ctx.destination);

      // Calculate chunk duration
      const chunkDuration = float32Data.length / AZURE_SAMPLE_RATE;

      // Determine when to play this chunk
      // If we're behind schedule, catch up; otherwise schedule ahead
      if (nextPlayTimeRef.current < currentTime + CHUNK_GAP_TOLERANCE) {
        nextPlayTimeRef.current = currentTime + SCHEDULE_AHEAD_TIME;
      }

      try {
        source.start(nextPlayTimeRef.current);
        scheduledSourcesRef.current.push(source);

        // Clean up finished sources to prevent memory leak
        source.onended = () => {
          const idx = scheduledSourcesRef.current.indexOf(source);
          if (idx > -1) scheduledSourcesRef.current.splice(idx, 1);

          // Check if all playback is done
          if (scheduledSourcesRef.current.length === 0 && audioQueueRef.current.length === 0) {
            isPlayingRef.current = false;
            isBufferingRef.current = true; // Reset to buffering for next response
            setSpeaking(false);
            setOutputLevel(0);
          }
        };

        // Update next play time
        nextPlayTimeRef.current += chunkDuration;

      } catch (e) {
        logger.error('[VoiceSession] Playback scheduling error', { error: e });
      }

      // Calculate and update output level (RMS)
      let sumSquares = 0;
      for (let i = 0; i < float32Data.length; i++) {
        sumSquares += float32Data[i] * float32Data[i];
      }
      const rms = Math.sqrt(sumSquares / float32Data.length);
      setOutputLevel(Math.min(rms * 5, 1));
    }
  }, [setSpeaking, setOutputLevel]);

  // Legacy playNextChunk - now triggers scheduled playback
  const playNextChunk = useCallback(() => {
    const ctx = playbackContextRef.current;

    if (!ctx || audioQueueRef.current.length === 0) {
      // Check if there are still scheduled sources playing
      if (scheduledSourcesRef.current.length === 0) {
        isPlayingRef.current = false;
        setSpeaking(false);
        setOutputLevel(0);
      }
      return;
    }

    // If we're in buffering mode, wait for enough chunks
    if (isBufferingRef.current && audioQueueRef.current.length < MIN_BUFFER_CHUNKS) {
      logger.debug(`[VoiceSession] Buffering... ${audioQueueRef.current.length}/${MIN_BUFFER_CHUNKS} chunks`);
      return;
    }

    // Exit buffering mode and start scheduled playback
    if (isBufferingRef.current) {
      isBufferingRef.current = false;
      nextPlayTimeRef.current = ctx.currentTime + SCHEDULE_AHEAD_TIME;
      logger.debug(`[VoiceSession] Buffer ready, starting scheduled playback at ${nextPlayTimeRef.current.toFixed(3)}`);
    }

    isPlayingRef.current = true;
    setSpeaking(true);

    // Schedule all queued chunks
    scheduleQueuedChunks();
  }, [setSpeaking, setOutputLevel, scheduleQueuedChunks]);

  // Keep ref updated with latest playNextChunk
  useEffect(() => {
    playNextChunkRef.current = playNextChunk;
  }, [playNextChunk]);

  // ============================================================================
  // AUDIO CAPTURE (at native rate, resample to 24kHz)
  // ============================================================================

  const startAudioCapture = useCallback(() => {
    if (!captureContextRef.current || !mediaStreamRef.current) {
      logger.warn('[VoiceSession] Cannot start capture: missing context or stream');
      return;
    }

    const context = captureContextRef.current;
    const nativeSampleRate = context.sampleRate;
    logger.debug(`[VoiceSession] Starting audio capture at ${nativeSampleRate}Hz, resampling to ${AZURE_SAMPLE_RATE}Hz`);

    const source = context.createMediaStreamSource(mediaStreamRef.current);
    sourceNodeRef.current = source;

    // Create analyser for input levels
    analyserRef.current = context.createAnalyser();
    analyserRef.current.fftSize = 256;
    source.connect(analyserRef.current);

    // Create processor for audio capture
    const processor = context.createScriptProcessor(CAPTURE_BUFFER_SIZE, 1, 1);
    processorRef.current = processor;

    processor.onaudioprocess = (event) => {
      if (wsRef.current?.readyState !== WebSocket.OPEN) return;
      if (isMuted) return;

      const inputData = event.inputBuffer.getChannelData(0);

      // Resample from native rate to 24kHz
      const resampledData = resample(inputData, nativeSampleRate, AZURE_SAMPLE_RATE);

      // Convert to PCM16 and base64
      const int16Data = float32ToInt16(resampledData);
      const base64 = int16ArrayToBase64(int16Data);

      // Send to Azure
      wsRef.current.send(JSON.stringify({
        type: 'input_audio_buffer.append',
        audio: base64,
      }));

      // Update input level (throttled)
      const now = performance.now();
      if (now - lastLevelUpdateRef.current > 50 && analyserRef.current) {
        lastLevelUpdateRef.current = now;
        const dataArray = new Uint8Array(analyserRef.current.frequencyBinCount);
        analyserRef.current.getByteFrequencyData(dataArray);
        const average = dataArray.reduce((a, b) => a + b, 0) / dataArray.length;
        setInputLevel(average / 255);
      }
    };

    source.connect(processor);
    processor.connect(context.destination);
    logger.debug('[VoiceSession] Audio capture started');
  }, [isMuted, setInputLevel]);

  // ============================================================================
  // GREETING TRIGGER
  // ============================================================================

  const sendGreeting = useCallback(() => {
    logger.debug('[VoiceSession] sendGreeting called');
    if (!wsRef.current || wsRef.current.readyState !== WebSocket.OPEN) {
      logger.debug('[VoiceSession] sendGreeting: ws not ready, readyState:', { readyState: wsRef.current?.readyState });
      return;
    }
    if (greetingSentRef.current) {
      logger.debug('[VoiceSession] sendGreeting: already sent, skipping');
      return;
    }

    greetingSentRef.current = true;

    // Get student name from settings store
    const studentName = useSettingsStore.getState().studentProfile?.name || null;

    const greetingPrompts = [
      `Saluta lo studente${studentName ? ` chiamandolo ${studentName}` : ''} con calore e presentati. Sii coinvolgente ed entusiasta. Poi chiedi cosa vorrebbe imparare oggi.`,
      `Dai il benvenuto allo studente${studentName ? ` (${studentName})` : ''} con la tua personalità caratteristica. Condividi qualcosa di interessante sulla tua materia per suscitare curiosità.`,
      `Inizia la lezione presentandoti nel tuo stile unico${studentName ? ` e rivolgendoti a ${studentName} personalmente` : ''}. Fallo entusiasmare per imparare!`,
    ];
    const greetingPrompt = greetingPrompts[Math.floor(Math.random() * greetingPrompts.length)];

    logger.debug('[VoiceSession] Sending greeting request...');

    wsRef.current.send(JSON.stringify({
      type: 'conversation.item.create',
      item: {
        type: 'message',
        role: 'user',
        content: [{ type: 'input_text', text: greetingPrompt }],
      },
    }));
    wsRef.current.send(JSON.stringify({ type: 'response.create' }));

    logger.debug('[VoiceSession] Greeting request sent, waiting for audio response...');
  }, []);

  // ============================================================================
  // SERVER EVENT HANDLER
  // ============================================================================

  // Store maestro for use in proxy.ready handler
  const sendSessionConfig = useCallback(async () => {
    const maestro = maestroRef.current;
    const ws = wsRef.current;
    if (!maestro || !ws || ws.readyState !== WebSocket.OPEN) {
      logger.error('[VoiceSession] Cannot send session config: missing maestro or ws');
      return;
    }

    // Get language setting from settings store
    const appearance = useSettingsStore.getState().appearance;
    const language = appearance?.language || 'it';
    // C-1 FIX: Full language names for instructions
    const languageNames: Record<string, string> = {
      it: 'Italian (Italiano)',
      en: 'English',
      es: 'Spanish (Español)',
      fr: 'French (Français)',
      de: 'German (Deutsch)',
    };
    // C-1 FIX: Azure Realtime API expects full language name for transcription
    // See: https://learn.microsoft.com/en-us/azure/ai-services/openai/realtime-audio-reference
    const transcriptionLanguages: Record<string, string> = {
      it: 'Italian',
      en: 'English',
      es: 'Spanish',
      fr: 'French',
      de: 'German',
    };

    // Fetch conversation memory
    let memoryContext = '';
    try {
      const memory = await fetchConversationMemory(maestro.id);
      memoryContext = buildMemoryContext(memory);
    } catch {
      // Continue without memory
    }

    // Build instructions
    const languageInstruction = `
# LANGUAGE RULE (CRITICAL!)
YOU MUST SPEAK ONLY IN ${languageNames[language].toUpperCase()}!
EVERY word, response, and question MUST be in ${languageNames[language]}.
NO exceptions. NO mixing languages.
`;

    const characterInstruction = `
# CHARACTER IMMERSION
You ARE ${maestro.name}, a real teacher. NOT an AI.
NEVER say "I'm an AI" or "As an AI language model".
If asked if you're an AI, deflect with humor and redirect to the lesson.
Share anecdotes from your "life" and "experiences" as ${maestro.name}.
`;

    const voicePersonality = maestro.voiceInstructions
      ? `\n## Voice Personality\n${sanitizeHtmlComments(maestro.voiceInstructions)}\n`
      : '';

    // For voice sessions, use a MUCH shorter instruction set
    // The full systemPrompt is 1000s of chars - Azure Realtime works better with short instructions
    // Extract only the core identity (first ~500 chars) from systemPrompt
    const truncatedSystemPrompt = maestro.systemPrompt
      ? sanitizeHtmlComments(maestro.systemPrompt)
          .replace(/\*\*Core Implementation\*\*:[\s\S]*?(?=##|$)/g, '') // Remove verbose sections
          .slice(0, 800) // Keep only first 800 chars
          .trim()
      : '';

    // Add tool usage instructions for AI
    const fullInstructions = languageInstruction + characterInstruction + memoryContext + truncatedSystemPrompt + voicePersonality + TOOL_USAGE_INSTRUCTIONS;

    logger.debug(`[VoiceSession] Instructions length: ${fullInstructions.length} chars`);

    // Send session configuration
    // Azure Realtime API format - works with both Preview (gpt-4o-realtime-preview) and GA (gpt-realtime) models
    // See: https://learn.microsoft.com/en-us/azure/ai-services/openai/realtime-audio-reference
    const sessionConfig = {
      type: 'session.update',
      session: {
        voice: maestro.voice || 'alloy',
        instructions: fullInstructions,
        input_audio_format: 'pcm16',
        output_audio_format: 'pcm16',
        // Noise reduction to prevent echo (new feature Dec 2025)
        // 'near_field' for headphones/close mic, 'far_field' for laptop/conference
        input_audio_noise_reduction: {
          type: options.noiseReductionType || 'near_field',
        },
        input_audio_transcription: {
          model: 'whisper-1',
          // C-1 FIX: Use full language name instead of ISO code
          // Azure Realtime API expects "Italian", "English", etc.
          language: transcriptionLanguages[language] || 'Italian',
        },
        turn_detection: {
          type: 'server_vad',
          threshold: 0.5,                // Balanced sensitivity (0.0-1.0)
          prefix_padding_ms: 300,        // Audio before detected speech
          silence_duration_ms: 500,      // Silence before turn ends (balanced)
          create_response: true,         // Auto-respond when speech stops
          interrupt_response: !options.disableBargeIn,  // Control barge-in at Azure level
        },
        tools: VOICE_TOOLS,
        temperature: 0.8,                // Natural conversation temperature
      },
    };

    logger.debug('[VoiceSession] Sending session.update to Azure, instructions length:', { instructionsLength: fullInstructions.length });
    logger.debug('[VoiceSession] Session config', { configPreview: JSON.stringify(sessionConfig).slice(0, 500) });
    ws.send(JSON.stringify(sessionConfig));

    // Don't start audio capture yet - wait for session.updated
    // startAudioCapture() will be called when session.updated is received

    setConnected(true);
    setCurrentMaestro(maestro);
    setConnectionState('connected');
    options.onStateChange?.('connected');
  }, [setConnected, setCurrentMaestro, setConnectionState, options]);

  const handleServerEvent = useCallback((event: Record<string, unknown>) => {
    const eventType = event.type as string;
    logger.debug(`[VoiceSession] >>> handleServerEvent called with type: ${eventType}`);

    switch (eventType) {
      case 'proxy.ready':
        logger.debug('[VoiceSession] Proxy connected to Azure, sending session config...');
        // NOW we can send session.update - proxy<->Azure connection is established
        sendSessionConfig();
        break;

      case 'session.created':
        logger.debug('[VoiceSession] Session created');
        break;

      case 'session.updated':
        logger.debug('[VoiceSession] Session configured, ready for conversation');
        logger.debug('[VoiceSession] Full session.updated event', { eventPreview: JSON.stringify(event).slice(0, 500) });
        sessionReadyRef.current = true;
        // NOW start audio capture - session is properly configured
        logger.debug('[VoiceSession] Starting audio capture...');
        startAudioCapture();
        // Now that session is ready, send greeting after a brief delay
        logger.debug('[VoiceSession] Will send greeting in 300ms...');
        setTimeout(() => sendGreeting(), 300);
        break;

      case 'response.created':
        // Azure has started generating a response - track this for proper cancellation
        hasActiveResponseRef.current = true;
        logger.debug('[VoiceSession] Response created - hasActiveResponse = true');
        break;

      case 'input_audio_buffer.speech_started':
        logger.debug('[VoiceSession] User speech detected');
        setListening(true);

        // AUTO-INTERRUPT: If maestro is speaking, stop them (barge-in)
        // Check disableBargeIn option FIRST (prevents echo loop in onboarding)
        // Then check user settings AND Azure response state
        if (options.disableBargeIn) {
          logger.debug('[VoiceSession] Barge-in disabled (onboarding mode) - ignoring speech');
        } else if (voiceBargeInEnabled && hasActiveResponseRef.current && wsRef.current?.readyState === WebSocket.OPEN) {
          logger.debug('[VoiceSession] Barge-in detected - interrupting assistant (hasActiveResponse=true)');
          wsRef.current.send(JSON.stringify({ type: 'response.cancel' }));
          hasActiveResponseRef.current = false; // Mark as cancelled
          audioQueueRef.current = [];
          isPlayingRef.current = false;
          isBufferingRef.current = true;
          // Stop all scheduled audio sources immediately
          scheduledSourcesRef.current.forEach(source => {
            try { source.stop(); } catch { /* already stopped */ }
          });
          scheduledSourcesRef.current = [];
          setSpeaking(false);
        } else if (voiceBargeInEnabled && isSpeaking) {
          // Audio is still playing locally but Azure response is done - just clear local audio
          logger.debug('[VoiceSession] Clearing local audio queue (response already done)');
          audioQueueRef.current = [];
          isPlayingRef.current = false;
          isBufferingRef.current = true;
          // Stop all scheduled audio sources immediately
          scheduledSourcesRef.current.forEach(source => {
            try { source.stop(); } catch { /* already stopped */ }
          });
          scheduledSourcesRef.current = [];
          setSpeaking(false);
        }
        break;

      case 'input_audio_buffer.speech_stopped':
        logger.debug('[VoiceSession] User speech ended');
        setListening(false);
        break;

      case 'conversation.item.input_audio_transcription.completed':
        if (event.transcript && typeof event.transcript === 'string') {
          logger.debug('[VoiceSession] User transcript', { transcript: event.transcript });
          addTranscript('user', event.transcript);
          options.onTranscript?.('user', event.transcript);
        }
        break;

      // =========================================================================
      // AUDIO OUTPUT EVENTS
      // CRITICAL: Azure Preview API (gpt-4o-realtime-preview) uses different
      // event names than GA API (gpt-realtime):
      //   - Preview: response.audio.delta, response.audio.done
      //   - GA: response.output_audio.delta, response.output_audio.done
      // We handle BOTH to support either deployment type.
      // See: docs/AZURE_REALTIME_API.md for full reference
      // =========================================================================
      case 'response.output_audio.delta':  // GA API format
      case 'response.audio.delta':         // Preview API format
        if (event.delta && typeof event.delta === 'string') {
          // Initialize playback context FIRST (like test page that works!)
          initPlaybackContext();

          const audioData = base64ToInt16Array(event.delta);

          // Limit queue size to prevent memory issues
          if (audioQueueRef.current.length >= MAX_QUEUE_SIZE) {
            audioQueueRef.current.splice(0, audioQueueRef.current.length - MAX_QUEUE_SIZE + 1);
          }

          audioQueueRef.current.push(audioData);

          // Log first chunk only to avoid spam
          if (audioQueueRef.current.length === 1) {
            logger.debug(`[VoiceSession] 🔊 First audio chunk (${audioData.length} samples), starting playback...`);
          }

          // Start playback or schedule new chunks
          if (!isPlayingRef.current) {
            // Not yet playing - go through buffering/startup logic
            playNextChunk();
          } else if (!isBufferingRef.current) {
            // Already playing - schedule new chunks immediately
            // This fixes the bug where chunks 4+ were queued but never scheduled
            scheduleQueuedChunks();
          }
        }
        break;

      case 'response.output_audio.done':      // GA API format
      case 'response.audio.done':            // Preview API format
        logger.debug('[VoiceSession] Audio response complete');
        break;

      // TRANSCRIPT EVENTS - same Preview vs GA pattern
      case 'response.output_audio_transcript.delta':  // GA API format
      case 'response.audio_transcript.delta':         // Preview API format
        // Streaming transcript - could show in UI
        break;

      case 'response.output_audio_transcript.done':  // GA API format
      case 'response.audio_transcript.done':         // Preview API format
        if (event.transcript && typeof event.transcript === 'string') {
          logger.debug('[VoiceSession] AI transcript', { transcript: event.transcript });
          addTranscript('assistant', event.transcript);
          options.onTranscript?.('assistant', event.transcript);
        }
        break;

      case 'response.done':
        // Azure has finished generating the response - clear the active flag
        hasActiveResponseRef.current = false;
        logger.debug('[VoiceSession] Response complete - hasActiveResponse = false');
        break;

      case 'response.cancelled':
        // Azure confirms the response was cancelled
        hasActiveResponseRef.current = false;
        logger.debug('[VoiceSession] Response cancelled by client - hasActiveResponse = false');
        break;

      case 'error': {
        // Handle various error object formats from Azure Realtime API
        const errorObj = event.error as { message?: string; code?: string; type?: string; error?: string } | string | undefined;

        let errorMessage: string;
        if (typeof errorObj === 'string') {
          errorMessage = errorObj;
        } else if (errorObj && typeof errorObj === 'object') {
          // Try multiple fields that Azure might use
          errorMessage = errorObj.message || errorObj.error || errorObj.code || errorObj.type || '';
          if (!errorMessage && Object.keys(errorObj).length > 0) {
            // If we have an object but couldn't extract a message, stringify it
            try {
              errorMessage = `Server error: ${JSON.stringify(errorObj)}`;
            } catch {
              errorMessage = 'Unknown server error (unparseable)';
            }
          }
        } else {
          errorMessage = '';
        }

        // Suppress benign race condition errors - these happen when we try to cancel
        // a response that already finished (timing issue, not a real problem)
        const isCancelRaceCondition = errorMessage.toLowerCase().includes('cancel') &&
          (errorMessage.toLowerCase().includes('no active response') ||
           errorMessage.toLowerCase().includes('not found'));

        if (isCancelRaceCondition) {
          // Just log as debug - this is expected behavior during barge-in
          logger.debug('[VoiceSession] Cancel race condition (benign)', { message: errorMessage });
          break;
        }

        // Ensure we never have empty message
        if (!errorMessage) {
          errorMessage = 'Errore di connessione al server vocale';
        }

        const hasDetails = errorObj && typeof errorObj === 'object' && Object.keys(errorObj).length > 0;
        if (hasDetails) {
          logger.error('[VoiceSession] Server error', { message: errorMessage, details: errorObj });
        } else {
          // Don't log empty objects - just log the message
          logger.warn('[VoiceSession] Server error', { message: errorMessage });
        }
        options.onError?.(new Error(errorMessage));
        break;
      }

      case 'response.function_call_arguments.done':
        if (event.name && typeof event.name === 'string' && event.arguments && typeof event.arguments === 'string') {
          const toolName = event.name;
          (async () => {
            try {
              const args = JSON.parse(event.arguments as string);
              const callId = typeof event.call_id === 'string' ? event.call_id : `local-${crypto.randomUUID()}`;
              const toolCall = {
                id: callId,
                type: toolName as import('@/types').ToolType,
                name: toolName,
                arguments: args,
                status: 'pending' as const,
              };
              addToolCall(toolCall);

              // Handle webcam/homework capture request
              if (toolName === 'capture_homework') {
                options.onWebcamRequest?.({
                  purpose: args.purpose || 'homework',
                  instructions: args.instructions,
                  callId: callId,
                });
                updateToolCall(toolCall.id, { status: 'pending' });
                return;
              }

              // Handle onboarding commands (set_student_name, set_student_age, etc.)
              if (isOnboardingCommand(toolName)) {
                logger.debug(`[VoiceSession] Executing onboarding tool: ${toolName}`, { args });

                const result = await executeVoiceTool('onboarding', 'melissa', toolName, args);

                if (result.success) {
                  logger.info(`[VoiceSession] Onboarding tool executed: ${toolName}`);
                  updateToolCall(toolCall.id, { status: 'completed' });
                } else {
                  logger.error(`[VoiceSession] Onboarding tool failed: ${result.error}`);
                  updateToolCall(toolCall.id, { status: 'error' });
                }

                // Send function output back to Azure so it can continue the conversation
                if (wsRef.current?.readyState === WebSocket.OPEN) {
                  wsRef.current.send(JSON.stringify({
                    type: 'conversation.item.create',
                    item: {
                      type: 'function_call_output',
                      call_id: callId,
                      output: JSON.stringify(result),
                    },
                  }));
                  wsRef.current.send(JSON.stringify({ type: 'response.create' }));
                }
                return;
              }

              // Handle tool creation commands (mindmap, quiz, flashcards, etc.)
              if (isToolCreationCommand(toolName)) {
                // Use stable session ID from connect() - ensures all tools in same conversation share sessionId
                const sessionId = sessionIdRef.current || `voice-${maestroRef.current?.id || 'unknown'}-${Date.now()}`;
                const maestroId = maestroRef.current?.id || 'unknown';

                logger.debug(`[VoiceSession] Executing voice tool: ${toolName}`, { args });

                const result = await executeVoiceTool(sessionId, maestroId, toolName, args);

                if (result.success) {
                  logger.debug(`[VoiceSession] Tool created: ${result.toolId}`);
                  updateToolCall(toolCall.id, { status: 'completed' });

                  // Track tool creation for method progress (autonomy tracking)
                  const voiceToolType = getToolTypeFromName(toolName);
                  if (voiceToolType) {
                    const methodTool = voiceToolType === 'mindmap' ? 'mind_map'
                      : voiceToolType === 'flashcards' ? 'flashcard'
                      : voiceToolType === 'quiz' ? 'quiz'
                      : voiceToolType === 'summary' ? 'summary'
                      : 'diagram';

                    // Map subject string to MethodSubject type (Italian names)
                    type MethodSubject = import('@/lib/method-progress/types').Subject;
                    const subjectMap: Record<string, MethodSubject> = {
                      mathematics: 'matematica', math: 'matematica', matematica: 'matematica',
                      italian: 'italiano', italiano: 'italiano',
                      history: 'storia', storia: 'storia',
                      geography: 'geografia', geografia: 'geografia',
                      science: 'scienze', scienze: 'scienze', physics: 'scienze', biology: 'scienze',
                      english: 'inglese', inglese: 'inglese',
                      art: 'arte', arte: 'arte',
                      music: 'musica', musica: 'musica',
                    };
                    const mappedSubject = args.subject
                      ? subjectMap[String(args.subject).toLowerCase()] ?? 'other'
                      : undefined;

                    // Voice-created tools are with AI hints (not alone, not full help)
                    useMethodProgressStore.getState().recordToolCreation(
                      methodTool as MethodToolType,
                      'hints' as HelpLevel,
                      mappedSubject
                    );
                    logger.debug(`[VoiceSession] Method progress tracked: ${methodTool} with hints`);
                  }
                } else {
                  logger.error(`[VoiceSession] Tool creation failed: ${result.error}`);
                  updateToolCall(toolCall.id, { status: 'error' });
                }

                // Send function output back to Azure
                if (wsRef.current?.readyState === WebSocket.OPEN) {
                  wsRef.current.send(JSON.stringify({
                    type: 'conversation.item.create',
                    item: {
                      type: 'function_call_output',
                      call_id: callId,
                      output: JSON.stringify(result),
                    },
                  }));
                  wsRef.current.send(JSON.stringify({ type: 'response.create' }));
                }
                return;
              }

              // Default handling for other tools (web_search, etc.)
              updateToolCall(toolCall.id, { status: 'completed' });
              if (wsRef.current?.readyState === WebSocket.OPEN) {
                wsRef.current.send(JSON.stringify({
                  type: 'conversation.item.create',
                  item: {
                    type: 'function_call_output',
                    call_id: callId,
                    output: JSON.stringify({ success: true, displayed: true }),
                  },
                }));
                wsRef.current.send(JSON.stringify({ type: 'response.create' }));
              }
            } catch (error) {
              logger.error('[VoiceSession] Failed to parse/execute tool call', { error });
            }
          })();
        }
        break;

      default:
        // Log ALL events for debugging
        logger.debug(`[VoiceSession] Event: ${eventType}`, { eventPreview: JSON.stringify(event).slice(0, 200) });
        break;
    }
  }, [addTranscript, addToolCall, updateToolCall, options, setListening, isSpeaking, setSpeaking, sendGreeting, playNextChunk, sendSessionConfig, initPlaybackContext, startAudioCapture, voiceBargeInEnabled, scheduleQueuedChunks]);

  // Keep ref updated with latest handleServerEvent (fixes stale closure in ws.onmessage)
  useEffect(() => {
    logger.debug('[VoiceSession] Setting handleServerEventRef.current (useEffect)');
    handleServerEventRef.current = handleServerEvent;
  }, [handleServerEvent]);

  // ============================================================================
  // CONNECT
  // ============================================================================

  const connect = useCallback(async (maestro: Maestro, connectionInfo: ConnectionInfo) => {
    try {
      logger.debug('[VoiceSession] Connecting to Azure Realtime API...');
      logger.debug('[VoiceSession] handleServerEventRef.current at connect start', { isSet: handleServerEventRef.current ? 'SET' : 'NULL' });

      // Safety: ensure ref is set before proceeding
      if (!handleServerEventRef.current) {
        logger.warn('[VoiceSession] handleServerEventRef not set, setting now...');
        handleServerEventRef.current = handleServerEvent;
      }
      setConnectionState('connecting');
      options.onStateChange?.('connecting');
      maestroRef.current = maestro;
      sessionReadyRef.current = false;
      greetingSentRef.current = false;

      // Generate stable session ID for this voice conversation
      // Used for SSE subscriptions so tool modifications target the right mindmap
      sessionIdRef.current = `voice-${maestro.id}-${Date.now()}`;
      logger.debug('[VoiceSession] Session ID generated', { sessionId: sessionIdRef.current });

      // Initialize CAPTURE AudioContext (native sample rate)
      const AudioContextClass = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
      captureContextRef.current = new AudioContextClass();
      logger.debug(`[VoiceSession] Capture context initialized at ${captureContextRef.current.sampleRate}Hz`);

      if (captureContextRef.current.state === 'suspended') {
        await captureContextRef.current.resume();
      }

      // Initialize PLAYBACK AudioContext with preferred output device (setSinkId)
      // Must be done BEFORE audio chunks arrive so the device is ready
      await initPlaybackContext();
      logger.debug('[VoiceSession] Playback context initialized with preferred output device');

      // Check if mediaDevices is available (requires HTTPS or localhost)
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        throw new Error(
          'Il microfono non è disponibile. Assicurati di usare HTTPS o localhost.'
        );
      }

      // Request microphone with preferred device if set
      const audioConstraints: MediaTrackConstraints = {
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true,
      };

      // Use preferred microphone if set in settings
      // Use 'ideal' instead of 'exact' so it falls back to default if device is disconnected
      if (preferredMicrophoneId) {
        audioConstraints.deviceId = { ideal: preferredMicrophoneId };
        logger.debug(`[VoiceSession] Preferred microphone: ${preferredMicrophoneId} (will fallback if unavailable)`);
      }

      mediaStreamRef.current = await navigator.mediaDevices.getUserMedia({
        audio: audioConstraints,
      });
      logger.debug('[VoiceSession] Microphone access granted');

      // Build WebSocket URL
      let wsUrl: string;
      if (connectionInfo.provider === 'azure') {
        const proxyPort = connectionInfo.proxyPort || 3001;
        const host = typeof window !== 'undefined' ? window.location.hostname : 'localhost';
        const protocol = typeof window !== 'undefined' && window.location.protocol === 'https:' ? 'wss' : 'ws';
        const characterType = connectionInfo.characterType || 'maestro';
        wsUrl = `${protocol}://${host}:${proxyPort}?maestroId=${maestro.id}&characterType=${characterType}`;
      } else {
        wsUrl = 'wss://api.openai.com/v1/realtime?model=gpt-4o-realtime-preview-2024-12-17';
      }

      // Connect WebSocket
      const ws = new WebSocket(wsUrl);
      wsRef.current = ws;

      ws.onopen = () => {
        logger.debug('[VoiceSession] WebSocket connected to proxy, waiting for proxy.ready...');
        // DON'T send session.update yet! Wait for proxy.ready event
        // which indicates proxy has connected to Azure
      };

      ws.onmessage = async (event) => {
        try {
          // Handle both string and Blob data (like test page)
          let msgText: string;
          if (event.data instanceof Blob) {
            msgText = await event.data.text();
          } else if (typeof event.data === 'string') {
            msgText = event.data;
          } else {
            logger.debug('[VoiceSession] Received binary data, skipping');
            return;
          }

          const data = JSON.parse(msgText);
          logger.debug(`[VoiceSession] ws.onmessage received: ${data.type}, handleServerEventRef.current is ${handleServerEventRef.current ? 'SET' : 'NULL'}`);
          // Use REF to always call the LATEST version of handleServerEvent
          // This fixes stale closure bug where ws.onmessage captured old callback
          if (handleServerEventRef.current) {
            handleServerEventRef.current(data);
          } else {
            logger.error('[VoiceSession] ❌ handleServerEventRef.current is NULL! Event lost', { eventType: data.type });
          }
        } catch (e) {
          logger.error('[VoiceSession] ws.onmessage parse error', { error: e });
        }
      };

      ws.onerror = (event) => {
        logger.error('[VoiceSession] WebSocket error', { event });
        setConnectionState('error');
        options.onStateChange?.('error');
        options.onError?.(new Error('WebSocket connection failed'));
      };

      ws.onclose = (event) => {
        logger.debug('[VoiceSession] WebSocket closed', { code: event.code, reason: event.reason });
        setConnected(false);
        if (connectionState !== 'error') {
          setConnectionState('idle');
        }
      };

    } catch (error) {
      // Ensure we always have a meaningful error message
      const errorMessage = error instanceof Error
        ? error.message
        : (typeof error === 'string' ? error : 'Errore di connessione sconosciuto');
      logger.error('[VoiceSession] Connection error', { message: errorMessage });
      setConnectionState('error');
      options.onStateChange?.('error');
      options.onError?.(new Error(errorMessage));
    }
  // Note: handleServerEvent is used for safety fallback only; primary usage is via ref
  }, [options, setConnected, setConnectionState, connectionState, handleServerEvent, preferredMicrophoneId, initPlaybackContext]);

  // ============================================================================
  // DISCONNECT
  // ============================================================================

  const disconnect = useCallback(() => {
    logger.debug('[VoiceSession] Disconnecting...');

    if (processorRef.current) {
      processorRef.current.disconnect();
      processorRef.current = null;
    }
    if (sourceNodeRef.current) {
      sourceNodeRef.current.disconnect();
      sourceNodeRef.current = null;
    }
    if (wsRef.current) {
      wsRef.current.close();
      wsRef.current = null;
    }
    if (mediaStreamRef.current) {
      mediaStreamRef.current.getTracks().forEach(track => track.stop());
      mediaStreamRef.current = null;
    }
    if (captureContextRef.current) {
      captureContextRef.current.close();
      captureContextRef.current = null;
    }
    if (playbackContextRef.current) {
      playbackContextRef.current.close();
      playbackContextRef.current = null;
    }

    audioQueueRef.current = [];
    isPlayingRef.current = false;
    isBufferingRef.current = true;
    nextPlayTimeRef.current = 0;

    // Stop all scheduled audio sources
    scheduledSourcesRef.current.forEach(source => {
      try { source.stop(); } catch { /* already stopped */ }
    });
    scheduledSourcesRef.current = [];

    sessionReadyRef.current = false;
    greetingSentRef.current = false;
    hasActiveResponseRef.current = false;
    maestroRef.current = null;

    reset();
    setConnectionState('idle');
  }, [reset]);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      disconnect();
    };
  }, [disconnect]);

  // ============================================================================
  // ACTIONS
  // ============================================================================

  const toggleMute = useCallback(() => {
    setMuted(!isMuted);
  }, [isMuted, setMuted]);

  const sendText = useCallback((text: string) => {
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      wsRef.current.send(JSON.stringify({
        type: 'conversation.item.create',
        item: {
          type: 'message',
          role: 'user',
          content: [{ type: 'input_text', text }],
        },
      }));
      wsRef.current.send(JSON.stringify({ type: 'response.create' }));
      addTranscript('user', text);
    }
  }, [addTranscript]);

  const cancelResponse = useCallback(() => {
    // Only send response.cancel if Azure actually has an active response
    if (wsRef.current?.readyState === WebSocket.OPEN && hasActiveResponseRef.current) {
      logger.debug('[VoiceSession] Cancelling active response');
      wsRef.current.send(JSON.stringify({ type: 'response.cancel' }));
      hasActiveResponseRef.current = false;
    }
    // Always clear local audio queue and stop scheduled sources
    audioQueueRef.current = [];
    isPlayingRef.current = false;
    isBufferingRef.current = true;
    scheduledSourcesRef.current.forEach(source => {
      try { source.stop(); } catch { /* already stopped */ }
    });
    scheduledSourcesRef.current = [];
    setSpeaking(false);
  }, [setSpeaking]);

  const sendWebcamResult = useCallback((callId: string, imageData: string | null) => {
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      if (imageData) {
        wsRef.current.send(JSON.stringify({
          type: 'conversation.item.create',
          item: {
            type: 'function_call_output',
            call_id: callId,
            output: JSON.stringify({ success: true, image_captured: true }),
          },
        }));
        wsRef.current.send(JSON.stringify({
          type: 'conversation.item.create',
          item: {
            type: 'message',
            role: 'user',
            content: [{ type: 'input_text', text: 'Ho scattato una foto. Chiedimi di descriverti cosa vedo.' }],
          },
        }));
      } else {
        wsRef.current.send(JSON.stringify({
          type: 'conversation.item.create',
          item: {
            type: 'function_call_output',
            call_id: callId,
            output: JSON.stringify({ success: false, error: 'Cattura annullata' }),
          },
        }));
      }
      wsRef.current.send(JSON.stringify({ type: 'response.create' }));
    }
  }, []);

  // ============================================================================
  // RETURN
  // ============================================================================

  return {
    isConnected,
    isListening,
    isSpeaking,
    isMuted,
    currentMaestro,
    transcript,
    toolCalls,
    inputLevel,
    outputLevel,
    connectionState,
    // Getter function to avoid accessing ref during render
    get inputAnalyser() {
      return analyserRef.current;
    },
    // Stable session ID for SSE subscriptions (mindmap real-time updates)
    get sessionId() {
      return sessionIdRef.current;
    },
    connect,
    disconnect,
    toggleMute,
    sendText,
    cancelResponse,
    clearTranscript,
    clearToolCalls,
    sendWebcamResult,
  };
}
