'use client';

import { useState, useRef, useCallback, useEffect, useMemo } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Camera,
  X,
  Check,
  RotateCcw,
  Loader2,
  ChevronDown,
  SwitchCamera,
  Smartphone,
  Monitor,
  AlertCircle,
  RefreshCw,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { logger } from '@/lib/logger';
import { Card } from '@/components/ui/card';
import { useSettingsStore } from '@/lib/stores/app-store';

interface WebcamCaptureProps {
  purpose: string;
  instructions?: string;
  onCapture: (imageData: string) => void;
  onClose: () => void;
  showTimer?: boolean;
}

type TimerOption = 0 | 3 | 5 | 10;

interface CameraDevice {
  deviceId: string;
  label: string;
  isContinuity: boolean;
  isFrontFacing: boolean;
}

// Detect if device is mobile
const isMobile = () => {
  if (typeof window === 'undefined') return false;
  return /Android|iPhone|iPad|iPod/i.test(navigator.userAgent);
};

// Check if label indicates a Continuity Camera (iPhone/iPad as webcam)
const isContinuityCamera = (label: string): boolean => {
  const lowerLabel = label.toLowerCase();
  return lowerLabel.includes('iphone') || lowerLabel.includes('ipad');
};

// Detect front-facing camera from label
const isFrontFacing = (label: string): boolean => {
  const lowerLabel = label.toLowerCase();
  return (
    lowerLabel.includes('front') ||
    lowerLabel.includes('facetime') ||
    lowerLabel.includes('selfie') ||
    lowerLabel.includes('anteriore')
  );
};

export function WebcamCapture({
  purpose,
  instructions,
  onCapture,
  onClose,
  showTimer = false,
}: WebcamCaptureProps) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [stream, setStream] = useState<MediaStream | null>(null);
  const [capturedImage, setCapturedImage] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [errorType, setErrorType] = useState<'permission' | 'unavailable' | 'timeout' | null>(null);

  // Timer state
  const [selectedTimer, setSelectedTimer] = useState<TimerOption>(showTimer ? 3 : 0);
  const [countdown, setCountdown] = useState<number | null>(null);
  const [showFlash, setShowFlash] = useState(false);

  // Camera selection state
  const [availableCameras, setAvailableCameras] = useState<CameraDevice[]>([]);
  const [selectedCameraId, setSelectedCameraId] = useState<string | null>(null);
  const [showCameraMenu, setShowCameraMenu] = useState(false);
  const [activeCameraLabel, setActiveCameraLabel] = useState<string>('');
  const [isSwitchingCamera, setIsSwitchingCamera] = useState(false);

  // Mobile detection
  const [isMobileDevice] = useState(() => isMobile());

  // Get preferred camera from settings
  const preferredCameraId = useSettingsStore((s) => s.preferredCameraId);

  // Enumerate available cameras
  const enumerateCameras = useCallback(async () => {
    try {
      const devices = await navigator.mediaDevices.enumerateDevices();
      const cameras = devices
        .filter((d) => d.kind === 'videoinput')
        .map((d) => ({
          deviceId: d.deviceId,
          label: d.label || `Camera ${d.deviceId.slice(0, 4)}`,
          isContinuity: isContinuityCamera(d.label),
          isFrontFacing: isFrontFacing(d.label),
        }));
      setAvailableCameras(cameras);
      return cameras;
    } catch (err) {
      logger.error('Failed to enumerate cameras', { error: String(err) });
      return [];
    }
  }, []);

  // Start camera with specific device ID
  const startCamera = useCallback(
    async (deviceId?: string) => {
      setIsLoading(true);
      setError(null);
      setErrorType(null);

      // Timeout for camera initialization
      const timeoutId = setTimeout(() => {
        setError('Timeout fotocamera. La fotocamera non risponde.');
        setErrorType('timeout');
        setIsLoading(false);
      }, 10000);

      try {
        // Stop existing stream
        if (stream) {
          stream.getTracks().forEach((track) => track.stop());
        }

        const constraints: MediaStreamConstraints = {
          // Use 'ideal' instead of 'exact' for graceful fallback if device unavailable
          video: deviceId ? { deviceId: { ideal: deviceId } } : true,
        };

        logger.info('Requesting camera access', { deviceId, constraints });

        const mediaStream = await navigator.mediaDevices.getUserMedia(constraints);
        clearTimeout(timeoutId);

        if (videoRef.current) {
          videoRef.current.srcObject = mediaStream;
          try {
            await videoRef.current.play();
          } catch (playErr) {
            logger.warn('Video autoplay blocked', { error: String(playErr) });
          }

          // Get active track label
          const videoTrack = mediaStream.getVideoTracks()[0];
          if (videoTrack) {
            setActiveCameraLabel(videoTrack.label);
            setSelectedCameraId(videoTrack.getSettings().deviceId || deviceId || null);
          }

          setStream(mediaStream);
          setIsLoading(false);

          // Enumerate cameras after getting permission (labels become available)
          await enumerateCameras();
        }
      } catch (err) {
        clearTimeout(timeoutId);
        const errorMsg = String(err);
        logger.error('Camera error', { error: errorMsg, deviceId });

        if (errorMsg.includes('Permission') || errorMsg.includes('NotAllowedError')) {
          setError('Permesso fotocamera negato. Abilita l\'accesso alla fotocamera nelle impostazioni del browser.');
          setErrorType('permission');
        } else if (errorMsg.includes('NotFoundError') || errorMsg.includes('DevicesNotFoundError')) {
          setError('Nessuna fotocamera trovata. Collega una webcam o usa un dispositivo con fotocamera.');
          setErrorType('unavailable');
        } else {
          // Try fallback to any camera
          if (deviceId) {
            logger.info('Retrying with any available camera');
            try {
              const fallbackStream = await navigator.mediaDevices.getUserMedia({ video: true });
              if (videoRef.current) {
                videoRef.current.srcObject = fallbackStream;
                await videoRef.current.play();
                const videoTrack = fallbackStream.getVideoTracks()[0];
                if (videoTrack) {
                  setActiveCameraLabel(videoTrack.label);
                  setSelectedCameraId(videoTrack.getSettings().deviceId || null);
                }
                setStream(fallbackStream);
                setIsLoading(false);
                await enumerateCameras();
                return;
              }
            } catch (fallbackErr) {
              logger.error('Camera fallback failed', { error: String(fallbackErr) });
            }
          }
          setError('Impossibile accedere alla fotocamera. Riprova.');
          setErrorType('unavailable');
        }
        setIsLoading(false);
      }
    },
    [stream, enumerateCameras]
  );

  // Switch to a different camera
  const switchCamera = useCallback(
    async (deviceId: string) => {
      setIsSwitchingCamera(true);
      setShowCameraMenu(false);
      await startCamera(deviceId);
      setIsSwitchingCamera(false);
    },
    [startCamera]
  );

  // Toggle between front and back cameras (mobile)
  const toggleFrontBack = useCallback(async () => {
    if (availableCameras.length < 2) return;

    const currentCamera = availableCameras.find((c) => c.deviceId === selectedCameraId);
    const targetCamera = availableCameras.find(
      (c) => c.isFrontFacing !== currentCamera?.isFrontFacing
    );

    if (targetCamera) {
      await switchCamera(targetCamera.deviceId);
    } else {
      // Fallback: cycle through cameras
      const currentIndex = availableCameras.findIndex((c) => c.deviceId === selectedCameraId);
      const nextIndex = (currentIndex + 1) % availableCameras.length;
      await switchCamera(availableCameras[nextIndex].deviceId);
    }
  }, [availableCameras, selectedCameraId, switchCamera]);

  // Initial camera start
  useEffect(() => {
    startCamera(preferredCameraId || undefined);

    return () => {
      if (stream) {
        stream.getTracks().forEach((track) => track.stop());
      }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps -- One-time mount initialization, stream cleanup handled separately
  }, []);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (stream) {
        stream.getTracks().forEach((track) => track.stop());
      }
    };
  }, [stream]);

  // Handle Escape key
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose();
      }
    };
    window.addEventListener('keydown', handleEscape);
    return () => window.removeEventListener('keydown', handleEscape);
  }, [onClose]);

  // Countdown timer effect
  useEffect(() => {
    if (countdown === null) return;

    if (countdown === 0) {
      setShowFlash(true);
      setTimeout(() => {
        setShowFlash(false);
        doCapture();
      }, 150);
      setCountdown(null);
      return;
    }

    const timer = setTimeout(() => {
      setCountdown(countdown - 1);
    }, 1000);

    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps -- doCapture excluded to prevent re-triggering countdown
  }, [countdown]);

  // Capture function
  const doCapture = useCallback(() => {
    if (!videoRef.current || !canvasRef.current) return;

    const video = videoRef.current;
    const canvas = canvasRef.current;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    ctx.drawImage(video, 0, 0);

    const imageData = canvas.toDataURL('image/jpeg', 0.9);
    setCapturedImage(imageData);

    if (stream) {
      stream.getTracks().forEach((track) => track.stop());
    }
  }, [stream]);

  // Handle capture button
  const handleCapture = useCallback(() => {
    if (selectedTimer > 0) {
      setCountdown(selectedTimer);
    } else {
      setShowFlash(true);
      setTimeout(() => {
        setShowFlash(false);
        doCapture();
      }, 150);
    }
  }, [selectedTimer, doCapture]);

  // Cancel countdown
  const handleCancelCountdown = useCallback(() => {
    setCountdown(null);
  }, []);

  // Retake photo
  const handleRetake = useCallback(async () => {
    setCapturedImage(null);
    await startCamera(selectedCameraId || preferredCameraId || undefined);
  }, [startCamera, selectedCameraId, preferredCameraId]);

  // Confirm and send
  const handleConfirm = useCallback(() => {
    if (capturedImage) {
      onCapture(capturedImage);
    }
  }, [capturedImage, onCapture]);

  // Retry after error
  const handleRetry = useCallback(() => {
    startCamera(selectedCameraId || preferredCameraId || undefined);
  }, [startCamera, selectedCameraId, preferredCameraId]);

  // Timer options with labels
  const timerOptions: { value: TimerOption; label: string; icon: string }[] = [
    { value: 0, label: 'Subito', icon: '⚡' },
    { value: 3, label: '3s', icon: '3️⃣' },
    { value: 5, label: '5s', icon: '5️⃣' },
    { value: 10, label: '10s', icon: '🔟' },
  ];

  // Get camera icon based on type
  const getCameraIcon = (camera: CameraDevice) => {
    if (camera.isContinuity) {
      return <Smartphone className="w-4 h-4 text-blue-400" />;
    }
    return <Monitor className="w-4 h-4 text-slate-400" />;
  };

  // Current camera display name
  const currentCameraName = useMemo(() => {
    if (!activeCameraLabel) return 'Fotocamera';
    if (isContinuityCamera(activeCameraLabel)) {
      // Extract iPhone/iPad name
      const match = activeCameraLabel.match(/(iPhone|iPad)(\s+di\s+\w+|\s+\w+'s)?/i);
      return match ? match[0] : 'iPhone Camera';
    }
    // Shorten long labels
    if (activeCameraLabel.length > 25) {
      return activeCameraLabel.substring(0, 22) + '...';
    }
    return activeCameraLabel;
  }, [activeCameraLabel]);

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      className="fixed inset-0 z-[60] flex items-center justify-center bg-black/80 backdrop-blur-sm p-4"
    >
      <Card className="w-full max-w-2xl bg-slate-900 border-slate-700 text-white overflow-hidden">
        {/* Header with camera selector */}
        <div className="p-4 border-b border-slate-700 flex items-center justify-between gap-2">
          <div className="flex items-center gap-3 flex-1 min-w-0">
            <div className="w-10 h-10 rounded-full bg-blue-500/20 flex items-center justify-center flex-shrink-0">
              <Camera className="w-5 h-5 text-blue-400" />
            </div>
            <div className="min-w-0 flex-1">
              <h3 className="font-semibold truncate">{purpose}</h3>
              {instructions && <p className="text-sm text-slate-400 truncate">{instructions}</p>}
            </div>
          </div>

          {/* Camera selector dropdown */}
          {availableCameras.length > 1 && !capturedImage && !error && (
            <div className="relative flex-shrink-0">
              <Button
                variant="outline"
                size="sm"
                onClick={() => setShowCameraMenu(!showCameraMenu)}
                className="border-slate-600 text-sm"
                disabled={isSwitchingCamera}
              >
                {isSwitchingCamera ? (
                  <Loader2 className="w-4 h-4 animate-spin mr-2" />
                ) : activeCameraLabel && isContinuityCamera(activeCameraLabel) ? (
                  <Smartphone className="w-4 h-4 mr-2 text-blue-400" />
                ) : (
                  <Camera className="w-4 h-4 mr-2" />
                )}
                <span className="hidden sm:inline max-w-[120px] truncate">{currentCameraName}</span>
                <ChevronDown className="w-4 h-4 ml-1" />
              </Button>

              <AnimatePresence>
                {showCameraMenu && (
                  <motion.div
                    initial={{ opacity: 0, y: -10 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, y: -10 }}
                    className="absolute right-0 top-full mt-2 w-64 bg-slate-800 border border-slate-700 rounded-lg shadow-lg overflow-hidden z-50"
                  >
                    <div className="p-2 text-xs text-slate-400 border-b border-slate-700">
                      Seleziona fotocamera
                    </div>
                    {availableCameras.map((camera) => (
                      <button
                        key={camera.deviceId}
                        onClick={() => switchCamera(camera.deviceId)}
                        className={`w-full px-3 py-2 text-left hover:bg-slate-700 transition-colors flex items-center gap-2 ${
                          selectedCameraId === camera.deviceId
                            ? 'bg-blue-600/20 text-blue-400'
                            : 'text-slate-300'
                        }`}
                      >
                        {getCameraIcon(camera)}
                        <span className="truncate flex-1">{camera.label}</span>
                        {camera.isContinuity && (
                          <span className="text-xs bg-blue-500/20 text-blue-400 px-1.5 py-0.5 rounded">
                            Continuity
                          </span>
                        )}
                      </button>
                    ))}
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          )}

          <Button
            variant="ghost"
            size="icon"
            onClick={onClose}
            className="text-slate-400 hover:text-white flex-shrink-0"
            aria-label="Chiudi fotocamera"
          >
            <X className="w-5 h-5" />
          </Button>
        </div>

        {/* Camera/Preview area */}
        <div className="relative aspect-video bg-black">
          {error ? (
            <div className="absolute inset-0 flex items-center justify-center">
              <div className="text-center p-6 max-w-md">
                <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-red-500/20 flex items-center justify-center">
                  <AlertCircle className="w-8 h-8 text-red-400" />
                </div>
                <p className="text-slate-300 mb-2">{error}</p>

                {errorType === 'permission' && (
                  <div className="text-sm text-slate-400 mb-4 space-y-1">
                    <p>Per abilitare la fotocamera:</p>
                    <ol className="list-decimal list-inside text-left">
                      <li>Clicca l&apos;icona 🔒 nella barra degli indirizzi</li>
                      <li>Trova &quot;Fotocamera&quot; o &quot;Camera&quot;</li>
                      <li>Seleziona &quot;Consenti&quot;</li>
                      <li>Ricarica la pagina</li>
                    </ol>
                  </div>
                )}

                <div className="flex gap-2 justify-center">
                  <Button
                    variant="outline"
                    onClick={handleRetry}
                    className="border-slate-600"
                  >
                    <RefreshCw className="w-4 h-4 mr-2" />
                    Riprova
                  </Button>
                  <Button variant="outline" onClick={onClose} className="border-slate-600">
                    Chiudi
                  </Button>
                </div>
              </div>
            </div>
          ) : (
            <>
              {/* Loading overlay - shown over video while initializing */}
              {isLoading && (
                <div className="absolute inset-0 flex items-center justify-center flex-col gap-3 z-10 bg-black">
                  <Loader2 className="w-8 h-8 animate-spin text-blue-500" />
                  <p className="text-slate-400 text-sm">Avvio fotocamera...</p>
                </div>
              )}

              {/* Live video feed - ALWAYS in DOM to ensure videoRef is available */}
              <video
                ref={videoRef}
                autoPlay
                playsInline
                muted
                className={capturedImage || isLoading ? 'invisible' : 'w-full h-full object-cover'}
              />

              {/* Captured image preview */}
              <AnimatePresence>
                {capturedImage && (
                  <motion.img
                    initial={{ opacity: 0, scale: 0.95 }}
                    animate={{ opacity: 1, scale: 1 }}
                    src={capturedImage}
                    alt="Foto catturata"
                    className="w-full h-full object-contain"
                  />
                )}
              </AnimatePresence>

              {/* Flash effect */}
              <AnimatePresence>
                {showFlash && (
                  <motion.div
                    initial={{ opacity: 1 }}
                    animate={{ opacity: 0 }}
                    exit={{ opacity: 0 }}
                    transition={{ duration: 0.15 }}
                    className="absolute inset-0 bg-white z-20"
                  />
                )}
              </AnimatePresence>

              {/* Camera switching overlay */}
              <AnimatePresence>
                {isSwitchingCamera && (
                  <motion.div
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    className="absolute inset-0 bg-black/70 flex items-center justify-center z-10"
                  >
                    <div className="text-center">
                      <Loader2 className="w-8 h-8 animate-spin text-blue-500 mx-auto mb-2" />
                      <p className="text-slate-300 text-sm">Cambio fotocamera...</p>
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>

              {/* Countdown overlay */}
              <AnimatePresence>
                {countdown !== null && countdown > 0 && (
                  <motion.div
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    className="absolute inset-0 bg-black/50 flex items-center justify-center z-10"
                  >
                    <motion.div
                      key={countdown}
                      initial={{ scale: 1.5, opacity: 0 }}
                      animate={{ scale: 1, opacity: 1 }}
                      exit={{ scale: 0.5, opacity: 0 }}
                      transition={{ type: 'spring', damping: 15, stiffness: 300 }}
                      className="text-center"
                    >
                      <div className="text-8xl font-bold text-white drop-shadow-lg">{countdown}</div>
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={handleCancelCountdown}
                        className="mt-6 border-white/50 text-white hover:bg-white/20"
                      >
                        Annulla
                      </Button>
                    </motion.div>
                  </motion.div>
                )}
              </AnimatePresence>

              {/* Mobile front/back toggle */}
              {isMobileDevice && availableCameras.length > 1 && !capturedImage && countdown === null && (
                <Button
                  variant="outline"
                  size="icon"
                  onClick={toggleFrontBack}
                  className="absolute top-4 right-4 bg-black/50 border-white/30 text-white hover:bg-black/70 z-10"
                  aria-label="Cambia fotocamera"
                >
                  <SwitchCamera className="w-5 h-5" />
                </Button>
              )}
            </>
          )}

          {/* Hidden canvas for capture */}
          <canvas ref={canvasRef} className="hidden" />

          {/* Capture guide overlay */}
          {!capturedImage && !isLoading && !error && countdown === null && (
            <div className="absolute inset-4 border-2 border-dashed border-white/30 rounded-lg pointer-events-none">
              <div className="absolute bottom-4 left-1/2 -translate-x-1/2 bg-black/50 px-4 py-2 rounded-full">
                <p className="text-sm text-white/80">
                  Posiziona il contenuto nell&apos;inquadratura
                </p>
              </div>
            </div>
          )}
        </div>

        {/* Controls */}
        <div className="p-4 flex flex-col gap-4">
          {!capturedImage ? (
            <>
              {/* Timer buttons (kid-friendly visual buttons) */}
              {showTimer && (
                <div className="flex justify-center gap-2">
                  {timerOptions.map((opt) => (
                    <button
                      key={opt.value}
                      onClick={() => setSelectedTimer(opt.value)}
                      disabled={countdown !== null}
                      className={`
                        flex flex-col items-center justify-center w-16 h-16 rounded-xl transition-all
                        ${
                          selectedTimer === opt.value
                            ? 'bg-blue-600 text-white scale-105 shadow-lg shadow-blue-500/30'
                            : 'bg-slate-800 text-slate-300 hover:bg-slate-700'
                        }
                        ${countdown !== null ? 'opacity-50 cursor-not-allowed' : ''}
                      `}
                      aria-label={`Timer ${opt.label}`}
                    >
                      <span className="text-xl">{opt.icon}</span>
                      <span className="text-xs font-medium mt-1">{opt.label}</span>
                    </button>
                  ))}
                </div>
              )}

              {/* Capture button */}
              <div className="flex justify-center">
                <Button
                  onClick={handleCapture}
                  disabled={isLoading || !!error || countdown !== null}
                  size="lg"
                  className="bg-blue-600 hover:bg-blue-700 px-8 h-14 text-lg"
                >
                  <Camera className="w-6 h-6 mr-2" />
                  {countdown !== null ? 'In corso...' : 'Scatta foto'}
                </Button>
              </div>
            </>
          ) : (
            <div className="flex justify-center gap-4">
              <Button
                onClick={handleRetake}
                variant="outline"
                size="lg"
                className="border-slate-600 h-14 px-6"
              >
                <RotateCcw className="w-5 h-5 mr-2" />
                Riprova
              </Button>
              <Button
                onClick={handleConfirm}
                size="lg"
                className="bg-green-600 hover:bg-green-700 px-8 h-14"
              >
                <Check className="w-5 h-5 mr-2" />
                Conferma
              </Button>
            </div>
          )}
        </div>
      </Card>
    </motion.div>
  );
}
