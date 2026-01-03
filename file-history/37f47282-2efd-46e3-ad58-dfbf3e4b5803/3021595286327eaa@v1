'use client';

import { useState, useEffect, useCallback } from 'react';
import { motion } from 'framer-motion';
import { Play, Square, Terminal, CheckCircle, XCircle, Loader2 } from 'lucide-react';
import { cn } from '@/lib/utils';
import type { CodeExecutionRequest } from '@/types';

interface CodeRunnerProps {
  request: CodeExecutionRequest;
  onResult?: (output: string, error?: string) => void;
  autoRun?: boolean;
  className?: string;
}

type RunState = 'idle' | 'loading' | 'running' | 'success' | 'error';

// Pyodide singleton
let pyodideInstance: unknown = null;
let pyodideLoading = false;
let pyodideLoadPromise: Promise<unknown> | null = null;

async function loadPyodide(): Promise<unknown> {
  if (pyodideInstance) return pyodideInstance;
  if (pyodideLoading && pyodideLoadPromise) return pyodideLoadPromise;

  pyodideLoading = true;
  pyodideLoadPromise = (async () => {
    // Dynamically load Pyodide from CDN
    const script = document.createElement('script');
    script.src = 'https://cdn.jsdelivr.net/pyodide/v0.25.0/full/pyodide.js';
    document.head.appendChild(script);

    await new Promise<void>((resolve) => {
      script.onload = () => resolve();
    });

    // @ts-expect-error - Pyodide is loaded via script
    pyodideInstance = await window.loadPyodide({
      indexURL: 'https://cdn.jsdelivr.net/pyodide/v0.25.0/full/',
    });

    return pyodideInstance;
  })();

  return pyodideLoadPromise;
}

async function runPython(code: string): Promise<{ output: string; error?: string }> {
  try {
    const pyodide = await loadPyodide() as {
      runPythonAsync: (code: string) => Promise<unknown>;
      setStdout: (options: { batched: (text: string) => void }) => void;
    };

    let stdout = '';
    pyodide.setStdout({ batched: (text: string) => { stdout += text; } });

    const result = await pyodide.runPythonAsync(code);
    const output = stdout || (result !== undefined ? String(result) : '');

    return { output };
  } catch (err) {
    return { output: '', error: err instanceof Error ? err.message : String(err) };
  }
}

function runJavaScript(code: string): { output: string; error?: string } {
  try {
    // Create sandboxed environment
    const logs: string[] = [];
    const sandbox = {
      console: {
        log: (...args: unknown[]) => logs.push(args.map(String).join(' ')),
        error: (...args: unknown[]) => logs.push('Error: ' + args.map(String).join(' ')),
        warn: (...args: unknown[]) => logs.push('Warning: ' + args.map(String).join(' ')),
      },
      Math,
      Date,
      JSON,
      Array,
      Object,
      String,
      Number,
      Boolean,
      RegExp,
      Map,
      Set,
      Promise,
    };

    // Create function with sandbox scope
    const fn = new Function(...Object.keys(sandbox), `
      'use strict';
      ${code}
    `);

    const result = fn(...Object.values(sandbox));
    const output = logs.length > 0 ? logs.join('\n') : (result !== undefined ? String(result) : '');

    return { output };
  } catch (err) {
    return { output: '', error: err instanceof Error ? err.message : String(err) };
  }
}

export function CodeRunner({ request, onResult, autoRun = false, className }: CodeRunnerProps) {
  const [state, setState] = useState<RunState>('idle');
  const [output, setOutput] = useState('');
  const [error, setError] = useState<string | undefined>();

  const runCode = useCallback(async () => {
    setState(request.language === 'python' ? 'loading' : 'running');
    setOutput('');
    setError(undefined);

    try {
      let result: { output: string; error?: string };

      if (request.language === 'python') {
        setState('running');
        result = await runPython(request.code);
      } else {
        result = runJavaScript(request.code);
      }

      setOutput(result.output);
      setError(result.error);
      setState(result.error ? 'error' : 'success');
      onResult?.(result.output, result.error);
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      setError(errorMsg);
      setState('error');
      onResult?.('', errorMsg);
    }
  }, [request, onResult]);

  useEffect(() => {
    if (autoRun) {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- Auto-execution on mount when autoRun enabled
      runCode();
    }
  }, [autoRun, runCode]);

  const languageLabel = request.language === 'python' ? 'Python' : 'JavaScript';
  const languageColor = request.language === 'python' ? 'text-yellow-500' : 'text-yellow-400';

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      className={cn(
        'rounded-xl border border-slate-200 dark:border-slate-700 overflow-hidden bg-slate-900',
        className
      )}
    >
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-2 bg-slate-800 border-b border-slate-700">
        <div className="flex items-center gap-2">
          <Terminal className="w-4 h-4 text-slate-400" />
          <span className={cn('text-sm font-medium', languageColor)}>{languageLabel}</span>
        </div>
        <div className="flex items-center gap-2">
          {state === 'loading' && (
            <span className="text-xs text-slate-400 flex items-center gap-1">
              <Loader2 className="w-3 h-3 animate-spin" />
              Loading Pyodide...
            </span>
          )}
          {state === 'running' && (
            <span className="text-xs text-blue-400 flex items-center gap-1">
              <Loader2 className="w-3 h-3 animate-spin" />
              Running...
            </span>
          )}
          {state === 'success' && (
            <CheckCircle className="w-4 h-4 text-green-500" />
          )}
          {state === 'error' && (
            <XCircle className="w-4 h-4 text-red-500" />
          )}
          <button
            onClick={runCode}
            disabled={state === 'loading' || state === 'running'}
            className="p-1.5 rounded-lg bg-green-600 hover:bg-green-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            {state === 'running' ? (
              <Square className="w-3 h-3 text-white" />
            ) : (
              <Play className="w-3 h-3 text-white" />
            )}
          </button>
        </div>
      </div>

      {/* Code */}
      <pre className="p-4 text-sm text-slate-300 overflow-x-auto">
        <code>{request.code}</code>
      </pre>

      {/* Output */}
      {(output || error) && (
        <div className="border-t border-slate-700">
          <div className="px-4 py-2 bg-slate-800/50 text-xs text-slate-400 uppercase tracking-wide">
            Output
          </div>
          <pre className={cn(
            'p-4 text-sm overflow-x-auto',
            error ? 'text-red-400' : 'text-green-400'
          )}>
            {error || output || '(no output)'}
          </pre>
        </div>
      )}
    </motion.div>
  );
}
