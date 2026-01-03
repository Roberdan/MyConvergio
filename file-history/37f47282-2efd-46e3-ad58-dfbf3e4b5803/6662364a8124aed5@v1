'use client';

import { useEffect, useState, useMemo, useRef, useCallback } from 'react';
import Image from 'next/image';
import { motion } from 'framer-motion';
import { cn } from '@/lib/utils';

// Canvas-based real-time waveform visualization
interface CanvasWaveformProps {
  analyser: AnalyserNode | null;
  isActive: boolean;
  color?: string;
  backgroundColor?: string;
  height?: number;
  className?: string;
}

export function CanvasWaveform({
  analyser,
  isActive,
  color = '#3B82F6',
  backgroundColor = 'rgb(15, 23, 42)',
  height = 64,
  className,
}: CanvasWaveformProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const animationRef = useRef<number | null>(null);
  const [canvasWidth, setCanvasWidth] = useState(300);

  // Resize observer for responsive canvas
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const resizeObserver = new ResizeObserver((entries) => {
      for (const entry of entries) {
        if (entry.target === canvas) {
          const rect = entry.contentRect;
          setCanvasWidth(rect.width || 300);
        }
      }
    });

    resizeObserver.observe(canvas);
    return () => resizeObserver.disconnect();
  }, []);

  // Ref to hold the draw function for self-referencing animation loop
  const drawRef = useRef<(() => void) | null>(null);

  // Draw waveform
  const draw = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas || !analyser) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const bufferLength = analyser.fftSize;
    const dataArray = new Uint8Array(bufferLength);
    analyser.getByteTimeDomainData(dataArray);

    const width = canvas.width;
    const canvasHeight = canvas.height;

    // Clear canvas
    ctx.fillStyle = backgroundColor;
    ctx.fillRect(0, 0, width, canvasHeight);

    // Draw waveform line
    ctx.lineWidth = 2;
    ctx.strokeStyle = isActive ? color : 'rgb(100, 116, 139)';
    ctx.beginPath();

    const sliceWidth = width / bufferLength;
    let x = 0;

    for (let i = 0; i < bufferLength; i++) {
      const v = dataArray[i] / 128.0;
      const y = (v * canvasHeight) / 2;

      if (i === 0) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }

      x += sliceWidth;
    }

    ctx.lineTo(width, canvasHeight / 2);
    ctx.stroke();

    // Continue animation loop using ref to avoid self-reference lint error
    if (drawRef.current) {
      animationRef.current = requestAnimationFrame(drawRef.current);
    }
  }, [analyser, isActive, color, backgroundColor]);

  // Keep drawRef updated with latest draw function
  useEffect(() => {
    drawRef.current = draw;
  }, [draw]);

  // Start/stop animation based on activity
  useEffect(() => {
    if (isActive && analyser) {
      animationRef.current = requestAnimationFrame(draw);
    } else {
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current);
        animationRef.current = null;
      }
      // Draw static line when inactive
      const canvas = canvasRef.current;
      if (canvas) {
        const ctx = canvas.getContext('2d');
        if (ctx) {
          const width = canvas.width;
          const canvasHeight = canvas.height;
          ctx.fillStyle = backgroundColor;
          ctx.fillRect(0, 0, width, canvasHeight);
          ctx.strokeStyle = 'rgb(100, 116, 139)';
          ctx.lineWidth = 2;
          ctx.beginPath();
          ctx.moveTo(0, canvasHeight / 2);
          ctx.lineTo(width, canvasHeight / 2);
          ctx.stroke();
        }
      }
    }

    return () => {
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current);
        animationRef.current = null;
      }
    };
  }, [isActive, analyser, draw, backgroundColor]);

  return (
    <canvas
      ref={canvasRef}
      width={canvasWidth}
      height={height}
      className={cn('w-full rounded-lg', className)}
      style={{ height }}
    />
  );
}

// Simple canvas waveform that takes audio level instead of analyser
// For use when we only have level data (0-1)
interface SimpleLevelWaveformProps {
  level: number; // 0-1
  isActive: boolean;
  color?: string;
  backgroundColor?: string;
  height?: number;
  className?: string;
}

export function SimpleLevelWaveform({
  level,
  isActive,
  color = '#3B82F6',
  backgroundColor = 'rgb(15, 23, 42)',
  height = 64,
  className,
}: SimpleLevelWaveformProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const animationRef = useRef<number | null>(null);
  const [canvasWidth, setCanvasWidth] = useState(300);

  // Initialize noise array for waveform animation effect
  // eslint-disable-next-line react-hooks/purity -- Visual effect, randomness doesn't affect state
  const initialNoise = useMemo(() => Array.from({ length: 100 }, () => Math.random()), []);
  const noiseRef = useRef<number[]>(initialNoise);

  // Resize observer for responsive canvas
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const resizeObserver = new ResizeObserver((entries) => {
      for (const entry of entries) {
        if (entry.target === canvas) {
          const rect = entry.contentRect;
          setCanvasWidth(rect.width || 300);
        }
      }
    });

    resizeObserver.observe(canvas);
    return () => resizeObserver.disconnect();
  }, []);

  // Ref to hold the draw function for self-referencing animation loop
  const drawRef = useRef<(() => void) | null>(null);

  // Draw simulated waveform based on level
  const draw = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const width = canvas.width;
    const canvasHeight = canvas.height;
    const centerY = canvasHeight / 2;

    // Clear canvas
    ctx.fillStyle = backgroundColor;
    ctx.fillRect(0, 0, width, canvasHeight);

    // Draw waveform line
    ctx.lineWidth = 2;
    ctx.strokeStyle = isActive && level > 0.01 ? color : 'rgb(100, 116, 139)';
    ctx.beginPath();

    const points = 100;
    const sliceWidth = width / points;
    const time = Date.now() / 100;

    // Shift noise for animation effect
    if (isActive) {
      noiseRef.current = noiseRef.current.map((_, i) => {
        const phase = (i / points) * Math.PI * 4 + time;
        return (Math.sin(phase) + Math.sin(phase * 2.3) * 0.5 + Math.sin(phase * 0.7) * 0.3) * 0.5;
      });
    }

    for (let i = 0; i < points; i++) {
      const x = i * sliceWidth;
      const amplitude = isActive ? level * (canvasHeight / 3) : 0;
      const y = centerY + noiseRef.current[i] * amplitude;

      if (i === 0) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    }

    ctx.lineTo(width, centerY);
    ctx.stroke();

    // Continue animation loop if active using ref to avoid self-reference lint error
    if (isActive && drawRef.current) {
      animationRef.current = requestAnimationFrame(drawRef.current);
    }
  }, [isActive, level, color, backgroundColor]);

  // Keep drawRef updated with latest draw function
  useEffect(() => {
    drawRef.current = draw;
  }, [draw]);

  // Start/stop animation based on activity
  useEffect(() => {
    if (isActive) {
      animationRef.current = requestAnimationFrame(draw);
    } else {
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current);
        animationRef.current = null;
      }
      // Draw static line when inactive
      const canvas = canvasRef.current;
      if (canvas) {
        const ctx = canvas.getContext('2d');
        if (ctx) {
          const width = canvas.width;
          const canvasHeight = canvas.height;
          ctx.fillStyle = backgroundColor;
          ctx.fillRect(0, 0, width, canvasHeight);
          ctx.strokeStyle = 'rgb(100, 116, 139)';
          ctx.lineWidth = 2;
          ctx.beginPath();
          ctx.moveTo(0, canvasHeight / 2);
          ctx.lineTo(width, canvasHeight / 2);
          ctx.stroke();
        }
      }
    }

    return () => {
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current);
        animationRef.current = null;
      }
    };
  }, [isActive, draw, backgroundColor]);

  return (
    <canvas
      ref={canvasRef}
      width={canvasWidth}
      height={height}
      className={cn('w-full rounded-lg', className)}
      style={{ height }}
    />
  );
}

interface WaveformProps {
  level: number; // 0-1
  isActive: boolean;
  color?: string;
  barCount?: number;
  className?: string;
}

export function Waveform({
  level,
  isActive,
  color = '#3B82F6',
  barCount = 20,
  className,
}: WaveformProps) {
  const bars = useMemo(() => Array.from({ length: barCount }, (_, i) => i), [barCount]);
  // Pre-compute random factors for each bar (stable between renders)
  const randomFactors = useMemo(
    () => bars.map(() => 0.5 + Math.random() * 0.5),
    // eslint-disable-next-line react-hooks/exhaustive-deps -- bars derived from barCount, only regenerate on count change
    [barCount]
  );
  const [time, setTime] = useState(0);

  // Animation loop for wave effect
  useEffect(() => {
    if (!isActive) return;
    let animationId: number;
    const animate = () => {
      setTime(Date.now());
      animationId = requestAnimationFrame(animate);
    };
    animationId = requestAnimationFrame(animate);
    return () => cancelAnimationFrame(animationId);
  }, [isActive]);

  return (
    <div className={cn('flex items-center justify-center gap-1 h-16', className)}>
      {bars.map((i) => {
        // Create natural-looking wave pattern using state-based time
        const phase = (i / barCount) * Math.PI * 2;
        const baseHeight = 0.3 + Math.sin(phase + time / 500) * 0.2;
        const activeHeight = isActive
          ? level * randomFactors[i]
          : baseHeight * 0.3;

        return (
          <motion.div
            key={i}
            className="rounded-full"
            style={{ backgroundColor: color }}
            animate={{
              height: `${Math.max(8, activeHeight * 64)}px`,
              opacity: isActive ? 0.8 + level * 0.2 : 0.4,
            }}
            transition={{
              type: 'spring',
              stiffness: 300,
              damping: 20,
              mass: 0.5,
            }}
            initial={{ height: 8, width: 4 }}
          />
        );
      })}
    </div>
  );
}

// Circular waveform for avatar
interface CircularWaveformProps {
  level: number;
  isActive: boolean;
  color?: string;
  size?: number;
  image?: string;
  className?: string;
}

export function CircularWaveform({
  level,
  isActive,
  color = '#3B82F6',
  size = 120,
  image,
  className,
}: CircularWaveformProps) {
  const innerSize = Math.round(size * 0.7);

  return (
    <div
      className={cn('relative flex items-center justify-center', className)}
      style={{ width: size, height: size }}
    >
      {/* Outer pulse ring */}
      <motion.div
        className="absolute inset-0 rounded-full"
        style={{ borderColor: color, borderWidth: 2 }}
        animate={{
          scale: isActive ? [1, 1.1 + level * 0.3, 1] : 1,
          opacity: isActive ? [0.5, 0.2, 0.5] : 0.3,
        }}
        transition={{
          duration: 1,
          repeat: Infinity,
          ease: 'easeInOut',
        }}
      />

      {/* Middle ring */}
      <motion.div
        className="absolute rounded-full"
        style={{
          width: size * 0.85,
          height: size * 0.85,
          borderColor: color,
          borderWidth: 3,
        }}
        animate={{
          scale: isActive ? [1, 1.05 + level * 0.2, 1] : 1,
          opacity: isActive ? [0.6, 0.3, 0.6] : 0.4,
        }}
        transition={{
          duration: 0.8,
          repeat: Infinity,
          ease: 'easeInOut',
          delay: 0.2,
        }}
      />

      {/* Inner circle with avatar */}
      <motion.div
        className="absolute rounded-full overflow-hidden flex items-center justify-center"
        style={{
          width: innerSize,
          height: innerSize,
          backgroundColor: color,
        }}
        animate={{
          scale: isActive ? 1 + level * 0.05 : 1,
        }}
        transition={{
          type: 'spring',
          stiffness: 400,
          damping: 25,
        }}
      >
        {image ? (
          <Image
            src={image}
            alt="Avatar"
            width={innerSize}
            height={innerSize}
            className="w-full h-full object-cover"
          />
        ) : null}
      </motion.div>
    </div>
  );
}
