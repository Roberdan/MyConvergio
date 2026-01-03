'use client';

import { useEffect, useRef, useState } from 'react';
import { motion } from 'framer-motion';
import katex from 'katex';
import 'katex/dist/katex.min.css';
import { cn } from '@/lib/utils';
import { logger } from '@/lib/logger';
import type { FormulaRequest } from '@/types';

interface FormulaRendererProps {
  request: FormulaRequest;
  className?: string;
  displayMode?: boolean;
}

export function FormulaRenderer({
  request,
  className,
  displayMode = true
}: FormulaRendererProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!containerRef.current) return;

    try {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- Clear error before retry render
      setError(null);
      katex.render(request.latex, containerRef.current, {
        displayMode,
        throwOnError: false,
        errorColor: '#ef4444',
        trust: true,
        strict: false,
      });
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      setError(errorMsg);
    }
  }, [request.latex, displayMode]);

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      className={cn(
        'rounded-xl border border-slate-200 dark:border-slate-700 overflow-hidden bg-slate-800',
        className
      )}
    >
      {/* Formula display */}
      <div className="p-6 flex flex-col items-center justify-center min-h-[80px]">
        {error ? (
          <div className="text-red-400 text-sm">{error}</div>
        ) : (
          <div
            ref={containerRef}
            className="text-slate-100 text-xl overflow-x-auto max-w-full"
          />
        )}
      </div>

      {/* Description */}
      {request.description && (
        <div className="px-4 py-3 border-t border-slate-700 bg-slate-800/50">
          <p className="text-sm text-slate-400">{request.description}</p>
        </div>
      )}
    </motion.div>
  );
}

// Inline formula component
interface InlineFormulaProps {
  latex: string;
  className?: string;
}

export function InlineFormula({ latex, className }: InlineFormulaProps) {
  const containerRef = useRef<HTMLSpanElement>(null);

  useEffect(() => {
    if (!containerRef.current) return;

    try {
      katex.render(latex, containerRef.current, {
        displayMode: false,
        throwOnError: false,
        errorColor: '#ef4444',
      });
    } catch (err) {
      logger.error('KaTeX error', { error: String(err) });
    }
  }, [latex]);

  return (
    <span
      ref={containerRef}
      className={cn('inline-block align-middle', className)}
    />
  );
}

// Common formula templates
export const formulaTemplates = {
  // Algebra
  quadratic: 'x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}',

  // Calculus
  derivative: '\\frac{d}{dx}[f(x)] = \\lim_{h \\to 0} \\frac{f(x+h) - f(x)}{h}',
  integral: '\\int_a^b f(x) \\, dx = F(b) - F(a)',

  // Trigonometry
  pythagorean: 'a^2 + b^2 = c^2',
  sinCos: '\\sin^2(\\theta) + \\cos^2(\\theta) = 1',

  // Physics
  newton2: 'F = ma',
  energy: 'E = mc^2',
  kinetic: 'KE = \\frac{1}{2}mv^2',
  gravity: 'F = G\\frac{m_1 m_2}{r^2}',

  // Statistics
  mean: '\\bar{x} = \\frac{1}{n}\\sum_{i=1}^{n} x_i',
  stdDev: '\\sigma = \\sqrt{\\frac{1}{n}\\sum_{i=1}^{n}(x_i - \\bar{x})^2}',

  // Geometry
  circleArea: 'A = \\pi r^2',
  sphereVolume: 'V = \\frac{4}{3}\\pi r^3',
};
