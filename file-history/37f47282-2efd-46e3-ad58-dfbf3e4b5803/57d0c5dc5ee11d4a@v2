'use client';

/**
 * Knowledge Hub Demo/Interactive Renderer
 *
 * Displays interactive demonstrations or simulations.
 * For Knowledge Hub, shows a preview with link to open full demo.
 *
 * Expected data format:
 * {
 *   title?: string;
 *   description?: string;
 *   type: 'simulation' | 'animation' | 'interactive';
 *   content: unknown;
 *   code?: string; // HTML/CSS/JS code for the demo
 * }
 */

import { useState, useMemo } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { PlayCircle, X } from 'lucide-react';
import { cn } from '@/lib/utils';
import { HTMLPreview } from '@/components/education/html-preview';
import { useAccessibilityStore } from '@/lib/accessibility/accessibility-store';
import type { BaseRendererProps } from './index';

interface DemoData {
  title?: string;
  description?: string;
  type?: 'simulation' | 'animation' | 'interactive';
  content?: unknown;
  previewImage?: string;
  code?: string; // HTML/CSS/JS code for the demo
  html?: string;
  css?: string;
  js?: string;
}

/**
 * C-7 FIX: Generate accessibility CSS based on user settings
 */
function generateAccessibilityCSS(settings: {
  dyslexiaFont: boolean;
  extraLetterSpacing: boolean;
  increasedLineHeight: boolean;
  highContrast: boolean;
  largeText: boolean;
  fontSize: number;
  lineSpacing: number;
  customBackgroundColor: string;
  customTextColor: string;
}): string {
  const rules: string[] = [];

  // Base styles to ensure accessibility overrides work
  rules.push(`
    * {
      font-size: ${settings.fontSize * 100}% !important;
      line-height: ${settings.lineSpacing * 1.4}em !important;
    }
  `);

  // Dyslexia-friendly font
  if (settings.dyslexiaFont) {
    rules.push(`
      @import url('https://fonts.cdnfonts.com/css/opendyslexic');
      * {
        font-family: 'OpenDyslexic', sans-serif !important;
      }
    `);
  }

  // Extra letter spacing
  if (settings.extraLetterSpacing) {
    rules.push(`
      * {
        letter-spacing: 0.05em !important;
        word-spacing: 0.1em !important;
      }
    `);
  }

  // Increased line height
  if (settings.increasedLineHeight) {
    rules.push(`
      * {
        line-height: ${Math.max(settings.lineSpacing, 1.8)}em !important;
      }
    `);
  }

  // High contrast mode
  if (settings.highContrast) {
    rules.push(`
      body, html {
        background-color: #000 !important;
        color: #fff !important;
      }
      * {
        border-color: #fff !important;
      }
      a, a:visited {
        color: #ffff00 !important;
      }
      button, input, select, textarea {
        background-color: #333 !important;
        color: #fff !important;
        border: 2px solid #fff !important;
      }
    `);
  }

  // Large text
  if (settings.largeText) {
    rules.push(`
      * {
        font-size: ${settings.fontSize * 120}% !important;
      }
    `);
  }

  return rules.join('\n');
}

/**
 * Build HTML code from separate html/css/js parts or use existing code
 */
function buildDemoCode(demoData: DemoData, accessibilityCSS: string = ''): string | null {
  // If we have a direct code property, use it
  if (demoData.code) {
    // C-7 FIX: Inject accessibility CSS into existing code
    if (accessibilityCSS && demoData.code.includes('<head>')) {
      return demoData.code.replace(
        '<head>',
        `<head><style id="accessibility-styles">${accessibilityCSS}</style>`
      );
    }
    if (accessibilityCSS && demoData.code.includes('<html>')) {
      return demoData.code.replace(
        '<html>',
        `<html><head><style id="accessibility-styles">${accessibilityCSS}</style></head>`
      );
    }
    // Fallback: wrap with style tag at the beginning
    if (accessibilityCSS) {
      return `<style id="accessibility-styles">${accessibilityCSS}</style>${demoData.code}`;
    }
    return demoData.code;
  }

  // If we have html/css/js parts, combine them
  if (demoData.html || demoData.css || demoData.js) {
    return `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style id="accessibility-styles">${accessibilityCSS}</style>
  <style>${demoData.css || ''}</style>
</head>
<body>
  ${demoData.html || ''}
  <script>${demoData.js || ''}</script>
</body>
</html>`;
  }

  return null;
}

/**
 * Render a demo preview for Knowledge Hub.
 */
export function DemoRenderer({ data, className }: BaseRendererProps) {
  const demoData = data as DemoData;
  const [showDemo, setShowDemo] = useState(false);

  // C-7 FIX: Get accessibility settings from store
  const settings = useAccessibilityStore((state) => state.settings);

  const title = demoData.title || 'Demo Interattiva';
  const description = demoData.description || 'Clicca per avviare la demo';
  const type = demoData.type || 'interactive';

  const typeLabels = {
    simulation: 'Simulazione',
    animation: 'Animazione',
    interactive: 'Interattivo',
  };

  // C-7 FIX: Generate accessibility CSS and inject into demo code
  const accessibilityCSS = useMemo(() => generateAccessibilityCSS(settings), [settings]);
  const demoCode = useMemo(() => buildDemoCode(demoData, accessibilityCSS), [demoData, accessibilityCSS]);
  const hasCode = !!demoCode;

  return (
    <>
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        className={cn(
          'rounded-xl border border-slate-200 dark:border-slate-700 overflow-hidden',
          className
        )}
      >
        <div className="p-4 bg-gradient-to-r from-accent-themed/10 to-purple-500/10">
          <div className="flex items-center gap-3">
            <div className="p-3 rounded-full bg-accent-themed/20">
              <PlayCircle className="w-8 h-8 text-accent-themed" />
            </div>
            <div>
              <h3 className="text-lg font-semibold text-slate-900 dark:text-slate-100">
                {title}
              </h3>
              <span className="text-sm text-slate-500">{typeLabels[type]}</span>
            </div>
          </div>
        </div>

        <div className="p-4 bg-white dark:bg-slate-800">
          <p className="text-sm text-slate-600 dark:text-slate-400 mb-4">
            {description}
          </p>

          {demoData.previewImage && (
            <div className="mb-4 rounded-lg overflow-hidden">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={demoData.previewImage}
                alt={`Anteprima di ${title}`}
                className="w-full h-48 object-cover"
              />
            </div>
          )}

          <button
            className={cn(
              'w-full flex items-center justify-center gap-2 p-3 rounded-lg transition-all',
              hasCode
                ? 'bg-accent-themed text-white hover:brightness-110'
                : 'bg-slate-200 dark:bg-slate-700 text-slate-500 cursor-not-allowed'
            )}
            onClick={() => hasCode && setShowDemo(true)}
            disabled={!hasCode}
          >
            <PlayCircle className="w-5 h-5" />
            {hasCode ? 'Avvia Demo' : 'Demo non disponibile'}
          </button>
        </div>
      </motion.div>

      {/* Demo Modal */}
      <AnimatePresence>
        {showDemo && demoCode && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
            onClick={() => setShowDemo(false)}
          >
            <motion.div
              initial={{ scale: 0.9, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.9, opacity: 0 }}
              className="relative w-full max-w-4xl max-h-[90vh] bg-white dark:bg-slate-900 rounded-xl shadow-2xl overflow-hidden"
              onClick={(e) => e.stopPropagation()}
            >
              {/* Close button */}
              <button
                onClick={() => setShowDemo(false)}
                className="absolute top-4 right-4 z-10 p-2 rounded-full bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 transition-colors"
                aria-label="Chiudi demo"
              >
                <X className="w-5 h-5" />
              </button>

              {/* Demo content */}
              <HTMLPreview
                code={demoCode}
                title={title}
                description={description}
                onClose={() => setShowDemo(false)}
                allowSave={false}
              />
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  );
}
