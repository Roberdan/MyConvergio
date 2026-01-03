'use client';

/**
 * Summaries View Component
 * Displays saved summaries from the archive
 * Issue #70: Real-time summary tool
 */

import { useState, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  FileText,
  X,
  Download,
  Brain,
  Layers,
  Loader2,
  MessageSquare,
  Trash2,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { SummaryRenderer } from '@/components/tools/summary-renderer';
import { ToolMaestroSelectionDialog } from './tool-maestro-selection-dialog';
import { cn } from '@/lib/utils';
import { useSavedTools, autoSaveMaterial } from '@/lib/hooks/use-saved-materials';
import {
  exportSummaryToPdf,
  convertSummaryToMindmap,
  generateFlashcardsFromSummary,
} from '@/lib/tools/summary-export';
import { toast } from '@/components/ui/toast';
import type { SummaryData } from '@/types/tools';
import type { Maestro } from '@/types';
import { useUIStore } from '@/lib/stores/app-store';

interface SummariesViewProps {
  className?: string;
}

export function SummariesView({ className }: SummariesViewProps) {
  const { tools, loading, deleteTool } = useSavedTools('summary');
  const { enterFocusMode } = useUIStore();
  const [selectedSummary, setSelectedSummary] = useState<{
    id: string;
    title: string;
    data: SummaryData;
    createdAt: Date;
  } | null>(null);
  const [showMaestroDialog, setShowMaestroDialog] = useState(false);

  // Handle maestro selection and enter focus mode
  const handleMaestroConfirm = useCallback((maestro: Maestro, mode: 'voice' | 'chat') => {
    setShowMaestroDialog(false);
    enterFocusMode('summary', maestro.id, mode);
  }, [enterFocusMode]);

  // Handle delete
  const handleDelete = useCallback(async (id: string) => {
    await deleteTool(id);
    if (selectedSummary?.id === id) {
      setSelectedSummary(null);
    }
  }, [deleteTool, selectedSummary]);

  // Handle PDF export
  const handleExportPdf = useCallback((data: SummaryData) => {
    exportSummaryToPdf(data);
  }, []);

  // Handle convert to mindmap
  // BUG 29 FIX: Replace alert with toast notification
  const handleConvertToMindmap = useCallback(async (data: SummaryData) => {
    const result = convertSummaryToMindmap(data);
    const saved = await autoSaveMaterial('mindmap', result.topic, { nodes: result.nodes });
    if (saved) {
      toast.success('Mappa mentale salvata!', `Creati ${result.nodes.length} nodi da "${result.topic}".`);
    } else {
      toast.error('Errore', 'Impossibile salvare la mappa mentale.');
    }
  }, []);

  // Handle generate flashcards
  // BUG 29 FIX: Replace alert with toast notification
  const handleGenerateFlashcards = useCallback(async (data: SummaryData) => {
    const result = generateFlashcardsFromSummary(data);
    const saved = await autoSaveMaterial('flashcard', result.topic, { cards: result.cards });
    if (saved) {
      toast.success('Flashcard salvate!', `Create ${result.cards.length} flashcard da "${result.topic}".`);
    } else {
      toast.error('Errore', 'Impossibile salvare le flashcard.');
    }
  }, []);

  return (
    <div className={cn('space-y-6', className)}>
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-slate-900 dark:text-white">
            Riassunti
          </h2>
          <p className="text-slate-600 dark:text-slate-400">
            I tuoi riassunti creati durante le sessioni con Coach e Maestri
          </p>
        </div>
        <Button onClick={() => setShowMaestroDialog(true)}>
          <MessageSquare className="w-4 h-4 mr-2" />
          Crea con un Professore
        </Button>
      </div>

      {/* Info card */}
      <Card className="bg-gradient-to-r from-emerald-50 to-teal-50 dark:from-emerald-900/20 dark:to-teal-900/20 border-emerald-200 dark:border-emerald-800">
        <CardContent className="p-4">
          <div className="flex items-start gap-4">
            <div className="p-3 rounded-xl bg-emerald-500/10">
              <FileText className="w-6 h-6 text-emerald-600 dark:text-emerald-400" />
            </div>
            <div>
              <h3 className="font-semibold text-emerald-900 dark:text-emerald-100 mb-1">
                Come creare un riassunto?
              </h3>
              <p className="text-sm text-emerald-800 dark:text-emerald-200">
                Parla con un Coach o un Maestro e chiedi: &quot;Devo fare un riassunto su...&quot;
                Ti guideranno passo passo nella creazione di un riassunto strutturato.
              </p>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Summaries grid */}
      {loading ? (
        <Card className="p-12">
          <div className="text-center">
            <Loader2 className="w-16 h-16 mx-auto text-slate-400 mb-4 animate-spin" />
            <h3 className="text-xl font-semibold text-slate-900 dark:text-white mb-2">
              Caricamento...
            </h3>
          </div>
        </Card>
      ) : tools.length === 0 ? (
        <Card className="p-12">
          <div className="text-center">
            <FileText className="w-16 h-16 mx-auto text-slate-400 mb-4" />
            <h3 className="text-xl font-semibold text-slate-900 dark:text-white mb-2">
              Nessun riassunto salvato
            </h3>
            <p className="text-slate-600 dark:text-slate-400 mb-6 max-w-md mx-auto">
              I riassunti creati durante le sessioni con Coach e Maestri appariranno qui.
              Prova a chiedere: &quot;Devo fare un riassunto sulla fotosintesi&quot;
            </p>
          </div>
        </Card>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {tools.map((tool) => {
            const summaryData = tool.content as unknown as SummaryData;
            return (
              <Card
                key={tool.toolId}
                className="cursor-pointer hover:shadow-lg transition-shadow group"
                onClick={() => setSelectedSummary({
                  id: tool.toolId,
                  title: tool.title || summaryData.topic || 'Riassunto',
                  data: summaryData,
                  createdAt: new Date(tool.createdAt),
                })}
              >
                <CardHeader className="pb-3">
                  <div className="flex items-start justify-between">
                    <div className="flex items-center gap-3">
                      <div className="w-10 h-10 rounded-xl bg-emerald-100 dark:bg-emerald-900/30 flex items-center justify-center">
                        <FileText className="w-5 h-5 text-emerald-600 dark:text-emerald-400" />
                      </div>
                      <div>
                        <CardTitle className="text-base">
                          {tool.title || summaryData.topic || 'Riassunto'}
                        </CardTitle>
                        <p className="text-xs text-slate-500">
                          {new Date(tool.createdAt).toLocaleDateString('it-IT')}
                        </p>
                      </div>
                    </div>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        handleDelete(tool.toolId);
                      }}
                      className="p-2 rounded-lg hover:bg-red-100 dark:hover:bg-red-900/20 opacity-0 group-hover:opacity-100 transition-opacity"
                    >
                      <Trash2 className="w-4 h-4 text-red-500" />
                    </button>
                  </div>
                </CardHeader>
                <CardContent>
                  <div className="flex flex-wrap gap-1.5">
                    {summaryData.sections?.slice(0, 3).map((section, i) => (
                      <span
                        key={i}
                        className="px-2 py-1 text-xs rounded-full bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400"
                      >
                        {section.title}
                      </span>
                    ))}
                    {(summaryData.sections?.length || 0) > 3 && (
                      <span className="px-2 py-1 text-xs rounded-full bg-slate-100 dark:bg-slate-800 text-slate-500">
                        +{(summaryData.sections?.length || 0) - 3}
                      </span>
                    )}
                  </div>
                </CardContent>
              </Card>
            );
          })}
        </div>
      )}

      {/* View summary modal */}
      <AnimatePresence>
        {selectedSummary && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
            onClick={() => setSelectedSummary(null)}
          >
            <motion.div
              initial={{ scale: 0.95 }}
              animate={{ scale: 1 }}
              exit={{ scale: 0.95 }}
              onClick={(e) => e.stopPropagation()}
              className="bg-white dark:bg-slate-900 rounded-2xl max-w-4xl w-full max-h-[90vh] overflow-hidden flex flex-col"
            >
              <div className="flex items-center justify-between p-4 border-b border-slate-200 dark:border-slate-700">
                <div className="flex items-center gap-3">
                  <FileText className="w-6 h-6 text-emerald-600" />
                  <h3 className="text-xl font-bold">{selectedSummary.title}</h3>
                </div>
                <div className="flex items-center gap-2">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => handleExportPdf(selectedSummary.data)}
                  >
                    <Download className="w-4 h-4 mr-2" />
                    PDF
                  </Button>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => handleConvertToMindmap(selectedSummary.data)}
                  >
                    <Brain className="w-4 h-4 mr-2" />
                    Mappa
                  </Button>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => handleGenerateFlashcards(selectedSummary.data)}
                  >
                    <Layers className="w-4 h-4 mr-2" />
                    Flashcard
                  </Button>
                  <button
                    onClick={() => setSelectedSummary(null)}
                    className="p-2 rounded-full hover:bg-slate-100 dark:hover:bg-slate-800"
                  >
                    <X className="w-5 h-5" />
                  </button>
                </div>
              </div>
              <div className="flex-1 overflow-auto">
                <SummaryRenderer
                  title={selectedSummary.data.topic}
                  sections={selectedSummary.data.sections}
                  length={selectedSummary.data.length}
                />
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Maestro selection dialog */}
      <ToolMaestroSelectionDialog
        isOpen={showMaestroDialog}
        toolType="summary"
        onConfirm={handleMaestroConfirm}
        onClose={() => setShowMaestroDialog(false)}
      />
    </div>
  );
}
