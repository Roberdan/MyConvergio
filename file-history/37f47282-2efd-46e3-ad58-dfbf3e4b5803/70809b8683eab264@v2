'use client';

import { useState, useRef, useMemo } from 'react';
import { motion } from 'framer-motion';
import DOMPurify from 'dompurify';
import {
  Maximize2,
  Minimize2,
  Code,
  Eye,
  Copy,
  Check,
  ExternalLink,
  Save,
  X,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { autoSaveMaterial } from '@/lib/hooks/use-saved-materials';
import { cn } from '@/lib/utils';

interface HTMLPreviewProps {
  code: string;
  title?: string;
  description?: string;
  subject?: string;
  maestroId?: string;
  onClose?: () => void;
  allowSave?: boolean;
}

export function HTMLPreview({
  code,
  title = 'Interactive Demo',
  description,
  subject,
  maestroId: _maestroId, // Reserved for future use with autoSaveMaterial
  onClose,
  allowSave = true,
}: HTMLPreviewProps) {
  const [view, setView] = useState<'preview' | 'code'>('preview');
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [copied, setCopied] = useState(false);
  const [saved, setSaved] = useState(false);
  const [saving, setSaving] = useState(false);
  const iframeRef = useRef<HTMLIFrameElement>(null);

  // Sanitize HTML to prevent XSS attacks
  // Allow safe interactive styling but block scripts and dangerous handlers
  const sanitizedCode = useMemo(() => {
    // Configure DOMPurify for safe educational content
    // NO scripts, NO dangerous event handlers - iframe sandbox provides isolation
    return DOMPurify.sanitize(code, {
      ADD_TAGS: ['style'],
      FORBID_TAGS: ['script', 'iframe', 'object', 'embed'],
      FORBID_ATTR: ['onerror', 'onload', 'onclick', 'onmouseover', 'onmouseout', 'onfocus', 'onblur'],
      WHOLE_DOCUMENT: true,
      FORCE_BODY: true,
    });
  }, [code]);

  // C-16 FIX: Use srcdoc instead of contentDocument injection
  // This avoids SecurityError when sandbox lacks allow-same-origin
  // srcdoc is safer and doesn't require cross-origin access
  const iframeSrcDoc = useMemo(() => {
    // Wrap in full HTML document structure
    return `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body { margin: 0; padding: 16px; font-family: system-ui, sans-serif; }
  </style>
</head>
<body>
${sanitizedCode}
</body>
</html>`;
  }, [sanitizedCode]);

  const handleCopy = async () => {
    await navigator.clipboard.writeText(code);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleSave = async () => {
    if (saving) return;
    setSaving(true);
    try {
      await autoSaveMaterial(
        'demo',
        title,
        { code, description, tags: subject ? [subject] : [] },
        { subject }
      );
      setSaved(true);
      setTimeout(() => setSaved(false), 2000);
    } finally {
      setSaving(false);
    }
  };

  const handleOpenInNewTab = () => {
    const blob = new Blob([code], { type: 'text/html' });
    const url = URL.createObjectURL(blob);
    window.open(url, '_blank');
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  };

  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      className={cn(
        'bg-white dark:bg-slate-800 rounded-2xl shadow-xl overflow-hidden flex flex-col',
        isFullscreen
          ? 'fixed inset-4 z-50'
          : 'w-full max-w-4xl max-h-[80vh]'
      )}
    >
      {/* Header */}
      <div className="flex items-center justify-between p-4 border-b border-slate-200 dark:border-slate-700">
        <div>
          <h3 className="font-bold text-slate-900 dark:text-white">{title}</h3>
          {description && (
            <p className="text-sm text-slate-500">{description}</p>
          )}
        </div>
        <div className="flex items-center gap-2">
          {/* View toggle */}
          <div className="flex bg-slate-100 dark:bg-slate-700 rounded-lg p-1">
            <button
              onClick={() => setView('preview')}
              aria-label="Visualizza anteprima"
              className={cn(
                'px-3 py-1.5 rounded-md text-sm font-medium transition-colors',
                view === 'preview'
                  ? 'bg-white dark:bg-slate-600 text-slate-900 dark:text-white shadow-sm'
                  : 'text-slate-600 dark:text-slate-400'
              )}
            >
              <Eye className="w-4 h-4" />
            </button>
            <button
              onClick={() => setView('code')}
              aria-label="Visualizza codice"
              className={cn(
                'px-3 py-1.5 rounded-md text-sm font-medium transition-colors',
                view === 'code'
                  ? 'bg-white dark:bg-slate-600 text-slate-900 dark:text-white shadow-sm'
                  : 'text-slate-600 dark:text-slate-400'
              )}
            >
              <Code className="w-4 h-4" />
            </button>
          </div>

          <Button variant="ghost" size="icon-sm" onClick={handleCopy} aria-label={copied ? 'Copiato' : 'Copia codice'}>
            {copied ? <Check className="w-4 h-4 text-green-500" /> : <Copy className="w-4 h-4" />}
          </Button>

          <Button variant="ghost" size="icon-sm" onClick={handleOpenInNewTab} aria-label="Apri in nuova scheda">
            <ExternalLink className="w-4 h-4" />
          </Button>

          {allowSave && (
            <Button variant="ghost" size="icon-sm" onClick={handleSave} aria-label={saved ? 'Salvato' : 'Salva snippet'}>
              {saved ? <Check className="w-4 h-4 text-green-500" /> : <Save className="w-4 h-4" />}
            </Button>
          )}

          <Button
            variant="ghost"
            size="icon-sm"
            onClick={() => setIsFullscreen(!isFullscreen)}
            aria-label={isFullscreen ? 'Esci da schermo intero' : 'Schermo intero'}
          >
            {isFullscreen ? <Minimize2 className="w-4 h-4" /> : <Maximize2 className="w-4 h-4" />}
          </Button>

          {onClose && (
            <Button variant="ghost" size="icon-sm" onClick={onClose} aria-label="Chiudi anteprima">
              <X className="w-4 h-4" />
            </Button>
          )}
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-hidden">
        {view === 'preview' ? (
          <iframe
            ref={iframeRef}
            title={title}
            className="w-full h-full min-h-[400px] bg-white"
            sandbox="allow-scripts"
            srcDoc={iframeSrcDoc}
          />
        ) : (
          <pre className="p-4 h-full overflow-auto bg-slate-900 text-slate-100 text-sm font-mono">
            <code>{code}</code>
          </pre>
        )}
      </div>
    </motion.div>
  );
}
