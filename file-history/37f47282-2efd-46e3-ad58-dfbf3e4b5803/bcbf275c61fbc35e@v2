'use client';

import { Suspense, useEffect, useState, useCallback, useRef } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import { RotateCcw, Wifi, WifiOff, Cloud, Volume2, ArrowRight, Sparkles } from 'lucide-react';
import { useOnboardingStore, getStepIndex, getTotalSteps } from '@/lib/stores/onboarding-store';
import { useVoiceSession } from '@/lib/hooks/use-voice-session';
import { WelcomeStep } from './components/welcome-step';
import { InfoStep } from './components/info-step';
import { PrinciplesStep } from './components/principles-step';
import { MaestriStep } from './components/maestri-step';
import { ReadyStep } from './components/ready-step';
import { HeroSection } from './components/hero-section';
import { FeaturesSection } from './components/features-section';
import { GuidesSection } from './components/guides-section';
import { QuickStart } from './components/quick-start';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { logger } from '@/lib/logger';
import type { VoiceSessionHandle } from '@/types';
import type { Maestro, Subject, MaestroVoice } from '@/types';
import {
  generateMelissaOnboardingPrompt,
  MELISSA_ONBOARDING_VOICE_INSTRUCTIONS,
  type ExistingUserDataForPrompt,
} from '@/lib/voice/onboarding-tools';

interface VoiceConnectionInfo {
  provider: 'azure';
  proxyPort: number;
  configured: boolean;
}

// Data returned from /api/onboarding
interface ExistingUserData {
  name: string;
  age?: number;
  schoolLevel?: 'elementare' | 'media' | 'superiore';
  learningDifferences?: string[];
  gender?: 'male' | 'female' | 'other';
}

/**
 * Create Melissa maestro for onboarding with specialized prompts.
 * If existingUserData is provided, Melissa will greet them by name and ask if they want to update.
 */
function createOnboardingMelissa(existingUserData?: ExistingUserDataForPrompt | null): Maestro {
  const isReturningUser = Boolean(existingUserData?.name);

  return {
    id: 'melissa-onboarding',
    name: 'Melissa',
    subject: 'methodology' as Subject,
    specialty: 'Learning Coach - Onboarding',
    voice: 'shimmer' as MaestroVoice,
    voiceInstructions: MELISSA_ONBOARDING_VOICE_INSTRUCTIONS,
    teachingStyle: 'scaffolding',
    avatar: '/avatars/melissa.jpg',
    color: '#EC4899',
    // Use dynamic prompt that adapts for returning users
    systemPrompt: generateMelissaOnboardingPrompt(existingUserData),
    greeting: isReturningUser
      ? `Ciao ${existingUserData?.name}! È bello rivederti! Ho già le tue informazioni. Vuoi cambiare qualcosa o andiamo avanti?`
      : 'Ciao! Sono Melissa, piacere di conoscerti! Come ti chiami?',
  };
}

function WelcomeContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const isReplay = searchParams.get('replay') === 'true';

  const {
    hasCompletedOnboarding,
    currentStep,
    isReplayMode,
    azureAvailable: _azureAvailable,
    startReplay,
    resetOnboarding,
    updateData,
    addVoiceTranscript,
  } = useOnboardingStore();

  // Track existing user data for returning users
  const [existingUserData, setExistingUserData] = useState<ExistingUserData | null>(null);
  const [hasCheckedExistingData, setHasCheckedExistingData] = useState(false);
  const [showLandingPage, setShowLandingPage] = useState(true);

  // Track if we should use Web Speech fallback (when Azure unavailable)
  const [useWebSpeechFallback, setUseWebSpeechFallback] = useState(false);
  const [connectionInfo, setConnectionInfo] = useState<VoiceConnectionInfo | null>(null);
  const [hasCheckedAzure, setHasCheckedAzure] = useState(false);
  const lastTranscriptRef = useRef<string | null>(null);

  // Voice reconnection logic (use state to trigger effect re-runs)
  const [voiceRetryAttempts, setVoiceRetryAttempts] = useState(0);
  const voiceRetryTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  const MAX_VOICE_RETRIES = 3;
  const VOICE_RETRY_DELAY_MS = 2000; // Start with 2 seconds

  // ========== SINGLE VOICE SESSION FOR ALL ONBOARDING STEPS ==========
  const voiceSession = useVoiceSession({
    noiseReductionType: 'far_field',
    onError: (error) => {
      const message = error instanceof Error ? error.message : String(error);

      // Retry logic with exponential backoff
      if (voiceRetryAttempts < MAX_VOICE_RETRIES) {
        // Temporary issue - will retry (warn level)
        logger.warn('[WelcomePage] Voice connection issue, will retry', {
          message,
          retryAttempt: voiceRetryAttempts + 1,
          maxRetries: MAX_VOICE_RETRIES,
        });
        setVoiceRetryAttempts((prev) => prev + 1);
        logger.info('[WelcomePage] Scheduling voice reconnection', {
          nextAttempt: voiceRetryAttempts + 1,
          maxRetries: MAX_VOICE_RETRIES,
        });
      } else {
        // Max retries exceeded - this is now an actual error
        logger.error('[WelcomePage] Voice connection failed after all retries', {
          message,
          totalAttempts: voiceRetryAttempts,
          maxRetries: MAX_VOICE_RETRIES,
        });
        logger.warn('[WelcomePage] Falling back to Web Speech', {
          totalAttempts: voiceRetryAttempts,
        });
        setUseWebSpeechFallback(true);
      }
    },
    onTranscript: (role, text) => {
      // Voice session working - reset retry counter
      if (voiceRetryAttempts > 0) {
        logger.info('[WelcomePage] Voice session recovered, resetting retry counter');
        setVoiceRetryAttempts(0);
      }

      // Deduplicate transcripts
      if (lastTranscriptRef.current === text.substring(0, 50)) return;
      lastTranscriptRef.current = text.substring(0, 50);
      addVoiceTranscript(role as 'user' | 'assistant', text);
    },
  });

  // Fetch voice connection info on mount
  useEffect(() => {
    async function fetchConnectionInfo() {
      try {
        const response = await fetch('/api/realtime/token');
        const data = await response.json();
        if (data.error) {
          // Voice API not available - graceful fallback (not an error in test/dev environments)
          logger.warn('[WelcomePage] Voice API not available, using Web Speech fallback', {
            error: data.error,
          });
          setHasCheckedAzure(true);
          setUseWebSpeechFallback(true);
          return;
        }
        setConnectionInfo(data as VoiceConnectionInfo);
        setHasCheckedAzure(true);
      } catch (error) {
        // Voice API unavailable - graceful fallback (expected in test environment)
        logger.warn('[WelcomePage] Voice API unavailable, using Web Speech fallback', {
          error: String(error),
        });
        setHasCheckedAzure(true);
        setUseWebSpeechFallback(true);
      }
    }
    fetchConnectionInfo();
  }, []);

  // Create voice session handle to pass to children
  const voiceSessionHandle: VoiceSessionHandle = {
    isConnected: voiceSession.isConnected,
    isListening: voiceSession.isListening,
    isSpeaking: voiceSession.isSpeaking,
    isMuted: voiceSession.isMuted,
    connectionState: voiceSession.connectionState,
    connect: voiceSession.connect,
    disconnect: voiceSession.disconnect,
    toggleMute: voiceSession.toggleMute,
  };

  // Fetch existing user data for returning users
  useEffect(() => {
    async function fetchExistingData() {
      try {
        const response = await fetch('/api/onboarding');
        const data = await response.json();

        if (data.hasExistingData && data.data) {
          setExistingUserData(data.data);
          // Pre-populate store with existing data
          if (data.data.name) {
            updateData({ name: data.data.name });
          }
        }

        setHasCheckedExistingData(true);
      } catch (error) {
        logger.error('[WelcomePage] Failed to fetch existing data', { error: String(error) });
        setHasCheckedExistingData(true);
      }
    }
    fetchExistingData();
  }, [updateData]);

  // Auto-reconnect voice session on error (with retry limit)
  useEffect(() => {
    // Only attempt reconnection if we're in retry mode
    if (
      connectionInfo &&
      !useWebSpeechFallback &&
      voiceRetryAttempts > 0 &&
      voiceRetryAttempts <= MAX_VOICE_RETRIES
    ) {
      const retryDelay = VOICE_RETRY_DELAY_MS * voiceRetryAttempts;

      logger.info('[WelcomePage] Scheduling voice reconnection', {
        attempt: voiceRetryAttempts,
        delayMs: retryDelay,
      });

      // Clear any existing timeout
      if (voiceRetryTimeoutRef.current) {
        clearTimeout(voiceRetryTimeoutRef.current);
      }

      // Schedule reconnection
      voiceRetryTimeoutRef.current = setTimeout(() => {
        logger.info('[WelcomePage] Executing voice reconnection attempt', {
          attempt: voiceRetryAttempts,
        });

        // Disconnect and reconnect to force fresh session
        voiceSession.disconnect();

        // Wait a bit before reconnecting
        setTimeout(() => {
          if (connectionInfo) {
            voiceSession.connect(
              createOnboardingMelissa(existingUserData),
              connectionInfo
            );
          }
        }, 500);
      }, retryDelay);
    }

    // Cleanup timeout on unmount
    return () => {
      if (voiceRetryTimeoutRef.current) {
        clearTimeout(voiceRetryTimeoutRef.current);
      }
    };
  }, [
    connectionInfo,
    useWebSpeechFallback,
    voiceRetryAttempts,
    voiceSession,
    existingUserData,
  ]);

  // Callback when Azure is unavailable - fallback to Web Speech TTS
  const handleAzureUnavailable = useCallback(() => {
    setUseWebSpeechFallback(true);
  }, []);

  // Handle replay mode
  useEffect(() => {
    if (isReplay && !isReplayMode) {
      startReplay();
    }
  }, [isReplay, isReplayMode, startReplay]);

  // DEV: Skip onboarding with ?skip=true
  const skipOnboarding = searchParams.get('skip') === 'true';
  useEffect(() => {
    if (skipOnboarding) {
      // Mark as completed and redirect
      useOnboardingStore.getState().completeOnboarding();
      router.push('/');
      return;
    }
  }, [skipOnboarding, router]);

  // Redirect if already completed and not in replay mode
  useEffect(() => {
    if (hasCompletedOnboarding && !isReplay && !isReplayMode) {
      router.push('/');
    }
  }, [hasCompletedOnboarding, isReplay, isReplayMode, router]);

  const stepIndex = getStepIndex(currentStep);
  const totalSteps = getTotalSteps();

  // Step components mapping
  const stepComponents = {
    welcome: WelcomeStep,
    info: InfoStep,
    principles: PrinciplesStep,
    maestri: MaestriStep,
    ready: ReadyStep,
  };

  const CurrentStepComponent = stepComponents[currentStep];

  // Handle reset - clears all data and restarts onboarding
  const handleReset = () => {
    if (confirm('Vuoi ricominciare da capo? Tutti i dati inseriti verranno cancellati.')) {
      voiceSession.disconnect(); // Disconnect voice before resetting
      resetOnboarding();
      setUseWebSpeechFallback(false);
      // Force page reload to reset all states
      window.location.href = '/welcome';
    }
  };

  // Start onboarding - transition from landing page to actual onboarding
  const handleStartOnboarding = useCallback(() => {
    setShowLandingPage(false);
  }, []);

  // Determine voice mode status
  const getVoiceModeInfo = () => {
    if (!hasCheckedAzure) {
      return { label: 'Verifica...', icon: Wifi, color: 'text-gray-400', bg: 'bg-gray-100 dark:bg-gray-800' };
    }
    if (useWebSpeechFallback || !connectionInfo) {
      return {
        label: 'Web Speech',
        icon: Volume2,
        color: 'text-amber-600 dark:text-amber-400',
        bg: 'bg-amber-50 dark:bg-amber-900/30',
        tooltip: 'Modalità Fallback: Azure non disponibile. Uso Web Speech API del browser per la voce.'
      };
    }
    return {
      label: 'Azure Realtime',
      icon: Cloud,
      color: 'text-green-600 dark:text-green-400',
      bg: 'bg-green-50 dark:bg-green-900/30',
      tooltip: 'Azure OpenAI Realtime API: Conversazione vocale bidirezionale in tempo reale con Melissa.'
    };
  };

  const voiceMode = getVoiceModeInfo();
  const VoiceModeIcon = voiceMode.icon;

  // Create onboarding Melissa with existing user data
  const onboardingMelissa = createOnboardingMelissa(existingUserData);

  // Show loading state while checking for existing data
  if (!hasCheckedExistingData) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-pink-50 via-purple-50 to-blue-50 dark:from-gray-900 dark:via-purple-950 dark:to-blue-950 flex items-center justify-center">
        <motion.div
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          className="text-center"
        >
          <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-gradient-to-br from-pink-400 to-purple-500 flex items-center justify-center animate-pulse">
            <Sparkles className="w-8 h-8 text-white" />
          </div>
          <p className="text-gray-600 dark:text-gray-400">Caricamento...</p>
        </motion.div>
      </div>
    );
  }

  // ========== LANDING PAGE (shown first) ==========
  // Wave 3: Refactored to use modular components
  if (showLandingPage) {
    const isReturningUser = Boolean(existingUserData?.name);

    // Handler for skip - marks onboarding as complete and goes to dashboard
    const handleSkipWithConfirmation = () => {
      useOnboardingStore.getState().completeOnboarding();
      router.push('/');
    };

    return (
      <div className="min-h-screen bg-gradient-to-br from-pink-50 via-purple-50 to-blue-50 dark:from-gray-900 dark:via-purple-950 dark:to-blue-950 relative overflow-hidden">
        {/* Main content container */}
        <div className="min-h-screen flex flex-col items-center justify-center px-4 py-12">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6 }}
            className="w-full"
          >
            {/* Hero Section - Logo, Avatar, Welcome Text */}
            <HeroSection
              userName={existingUserData?.name}
              isReturningUser={isReturningUser}
            />

            {/* Features Section - Key capabilities */}
            <FeaturesSection />

            {/* Guides Section - Meet the AI characters */}
            <GuidesSection />

            {/* Quick Start Section - CTAs */}
            <QuickStart
              isReturningUser={isReturningUser}
              onStartWithVoice={handleStartOnboarding}
              onStartWithoutVoice={handleStartOnboarding}
              onSkip={handleSkipWithConfirmation}
              onUpdateProfile={isReturningUser ? handleStartOnboarding : undefined}
            />
          </motion.div>

          {/* Decorative elements - pointer-events-none to not block clicks */}
          <div className="absolute top-0 left-0 w-64 h-64 bg-gradient-to-br from-pink-300/20 to-transparent rounded-full blur-3xl -translate-x-1/2 -translate-y-1/2 pointer-events-none" />
          <div className="absolute bottom-0 right-0 w-96 h-96 bg-gradient-to-tl from-purple-300/20 to-transparent rounded-full blur-3xl translate-x-1/3 translate-y-1/3 pointer-events-none" />
        </div>
      </div>
    );
  }

  // ========== ONBOARDING FLOW (after clicking "Start") ==========
  return (
    <div className="min-h-screen bg-gradient-to-br from-pink-50 via-purple-50 to-blue-50 dark:from-gray-900 dark:via-purple-950 dark:to-blue-950">
      {/* Progress indicator */}
      <div className="fixed top-0 left-0 right-0 z-50 px-4 py-3 bg-white/80 dark:bg-gray-900/80 backdrop-blur-sm border-b border-gray-200 dark:border-gray-800">
        <div className="max-w-2xl mx-auto">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm font-medium text-gray-600 dark:text-gray-400">
              {existingUserData?.name ? `Aggiornamento profilo di ${existingUserData.name}` : 'Benvenuto in MirrorBuddy'}
            </span>

            <div className="flex items-center gap-3">
              {/* Voice Mode Indicator */}
              <div
                className={cn(
                  'flex items-center gap-1.5 px-2 py-1 rounded-full text-xs font-medium cursor-help',
                  voiceMode.bg, voiceMode.color
                )}
                title={voiceMode.tooltip}
              >
                <VoiceModeIcon className="w-3.5 h-3.5" />
                <span className="hidden sm:inline">{voiceMode.label}</span>
              </div>

              {/* Step counter */}
              <span className="text-sm text-gray-500 dark:text-gray-500">
                {stepIndex + 1} / {totalSteps}
              </span>

              {/* Skip to app button (for all users) */}
              <Button
                variant="ghost"
                size="sm"
                onClick={() => {
                  useOnboardingStore.getState().completeOnboarding();
                  router.push('/');
                }}
                className="h-7 px-3 text-pink-600 hover:text-pink-700 hover:bg-pink-50"
              >
                Salta
                <ArrowRight className="w-3 h-3 ml-1" />
              </Button>

              {/* Reset button */}
              <Button
                variant="ghost"
                size="sm"
                onClick={handleReset}
                className="h-7 px-2 text-gray-500 hover:text-red-500"
                title="Ricomincia da capo (cancella tutti i dati)"
              >
                <RotateCcw className="w-4 h-4" />
              </Button>
            </div>
          </div>

          {/* Progress bar */}
          <div className="flex gap-1.5">
            {Array.from({ length: totalSteps }).map((_, i) => (
              <div
                key={i}
                className={cn(
                  'h-1.5 flex-1 rounded-full transition-all duration-300',
                  i < stepIndex
                    ? 'bg-pink-500'
                    : i === stepIndex
                      ? 'bg-pink-400'
                      : 'bg-gray-200 dark:bg-gray-700'
                )}
              />
            ))}
          </div>
        </div>
      </div>

      {/* Voice Mode Explanation Banner (shown when in fallback) */}
      {useWebSpeechFallback && (
        <motion.div
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          className="fixed top-16 left-0 right-0 z-40 px-4 py-2 bg-amber-50 dark:bg-amber-900/50 border-b border-amber-200 dark:border-amber-800"
        >
          <div className="max-w-2xl mx-auto flex items-center gap-2 text-sm text-amber-800 dark:text-amber-200">
            <WifiOff className="w-4 h-4 flex-shrink-0" />
            <p>
              <strong>Modalità Fallback:</strong> Azure Realtime API non disponibile.
              Melissa usa Web Speech API del browser (voce sintetica, no conversazione).
            </p>
          </div>
        </motion.div>
      )}

      {/* Main content - centered single column */}
      <div className={cn(
        "pb-8 px-4 min-h-screen flex items-center justify-center",
        useWebSpeechFallback ? "pt-28" : "pt-20"
      )}>
        <div className="w-full max-w-md">
          <AnimatePresence mode="wait">
            <motion.div
              key={currentStep}
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -20 }}
              transition={{ duration: 0.3, ease: 'easeInOut' }}
            >
              <CurrentStepComponent
                useWebSpeechFallback={useWebSpeechFallback}
                onAzureUnavailable={handleAzureUnavailable}
                existingUserData={existingUserData}
                voiceSession={voiceSessionHandle}
                connectionInfo={connectionInfo}
                onboardingMelissa={onboardingMelissa}
              />
            </motion.div>
          </AnimatePresence>
        </div>
      </div>
    </div>
  );
}

export default function WelcomePage() {
  return (
    <Suspense fallback={
      <div className="min-h-screen bg-gradient-to-br from-pink-50 via-purple-50 to-blue-50 dark:from-gray-900 dark:via-purple-950 dark:to-blue-950 flex items-center justify-center">
        <div className="animate-pulse text-gray-500">Caricamento...</div>
      </div>
    }>
      <WelcomeContent />
    </Suspense>
  );
}
