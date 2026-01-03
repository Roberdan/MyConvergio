'use client';

/**
 * Supporti Sidebar (Wave 4)
 * Navigation for filtering materials by type, subject, maestro
 */

import { useRouter, useSearchParams } from 'next/navigation';
import {
  Brain,
  HelpCircle,
  Layers,
  Play,
  FileText,
  Camera,
  Bookmark,
  BookOpen,
  Users,
  ChevronDown,
  ChevronRight,
} from 'lucide-react';
import { useState } from 'react';
import { cn } from '@/lib/utils';
import { TOOL_LABELS, SUBJECT_LABELS } from '@/components/education/archive';
import type { ToolType } from '@/types/tools';

interface SidebarProps {
  counts: {
    total: number;
    bookmarked: number;
    byType: Record<string, number>;
    bySubject: Record<string, number>;
    byMaestro: Record<string, number>;
  };
  subjects: string[];
  maestros: Array<{ id: string; name: string }>;
}

const TOOL_ICON_MAP: Partial<Record<ToolType, typeof Brain>> = {
  mindmap: Brain,
  quiz: HelpCircle,
  flashcard: Layers,
  demo: Play,
  summary: FileText,
  homework: FileText,
  webcam: Camera,
  pdf: FileText,
};

export function Sidebar({ counts, subjects, maestros }: SidebarProps) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [expandedSections, setExpandedSections] = useState({
    type: true,
    subject: false,
    maestro: false,
  });

  const currentType = searchParams.get('type');
  const currentSubject = searchParams.get('subject');
  const currentMaestro = searchParams.get('maestro');
  const isBookmarked = searchParams.get('bookmarked') === 'true';

  const navigate = (params: Record<string, string | null>) => {
    const current = new URLSearchParams(searchParams.toString());
    for (const [key, value] of Object.entries(params)) {
      if (value) {
        current.set(key, value);
      } else {
        current.delete(key);
      }
    }
    router.push(`/supporti?${current.toString()}`);
  };

  const toggleSection = (section: keyof typeof expandedSections) => {
    setExpandedSections(prev => ({ ...prev, [section]: !prev[section] }));
  };

  const isActive = (type: string | null, subject: string | null, maestro: string | null) => {
    return type === currentType && subject === currentSubject && maestro === currentMaestro;
  };

  return (
    <aside className="w-56 flex-shrink-0 border-r border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900/50 p-4 overflow-y-auto">
      <nav aria-label="Filtri materiali">
        {/* All Materials */}
        <button
          onClick={() => navigate({ type: null, subject: null, maestro: null, bookmarked: null })}
          className={cn(
            'w-full flex items-center gap-2 px-3 py-2 rounded-lg text-left text-sm font-medium transition-colors',
            !currentType && !currentSubject && !currentMaestro && !isBookmarked
              ? 'bg-primary text-white'
              : 'hover:bg-slate-200 dark:hover:bg-slate-800'
          )}
        >
          <BookOpen className="w-4 h-4" />
          Tutti i Supporti
          <span className="ml-auto text-xs opacity-70">{counts.total}</span>
        </button>

        {/* Bookmarked */}
        <button
          onClick={() => navigate({ bookmarked: 'true', type: null, subject: null, maestro: null })}
          className={cn(
            'w-full flex items-center gap-2 px-3 py-2 rounded-lg text-left text-sm transition-colors mt-1',
            isBookmarked
              ? 'bg-amber-100 dark:bg-amber-900/30 text-amber-700 dark:text-amber-300'
              : 'hover:bg-slate-200 dark:hover:bg-slate-800'
          )}
        >
          <Bookmark className="w-4 h-4" />
          Preferiti
          <span className="ml-auto text-xs opacity-70">{counts.bookmarked}</span>
        </button>

        {/* By Type */}
        <div className="mt-4">
          <button
            onClick={() => toggleSection('type')}
            className="w-full flex items-center gap-2 px-3 py-1.5 text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wide"
          >
            {expandedSections.type ? <ChevronDown className="w-3 h-3" /> : <ChevronRight className="w-3 h-3" />}
            Per Tipo
          </button>
          {expandedSections.type && (
            <div className="mt-1 space-y-0.5">
              {Object.entries(TOOL_LABELS).map(([type, label]) => {
                const Icon = TOOL_ICON_MAP[type as ToolType] || FileText;
                const count = counts.byType[type] || 0;
                if (count === 0) return null;
                return (
                  <button
                    key={type}
                    onClick={() => navigate({ type, subject: null, maestro: null, bookmarked: null })}
                    className={cn(
                      'w-full flex items-center gap-2 px-3 py-1.5 rounded-lg text-left text-sm transition-colors',
                      currentType === type
                        ? 'bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300'
                        : 'hover:bg-slate-200 dark:hover:bg-slate-800'
                    )}
                  >
                    <Icon className="w-4 h-4" />
                    {label}
                    <span className="ml-auto text-xs opacity-70">{count}</span>
                  </button>
                );
              })}
            </div>
          )}
        </div>

        {/* By Subject */}
        {subjects.length > 0 && (
          <div className="mt-4">
            <button
              onClick={() => toggleSection('subject')}
              className="w-full flex items-center gap-2 px-3 py-1.5 text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wide"
            >
              {expandedSections.subject ? <ChevronDown className="w-3 h-3" /> : <ChevronRight className="w-3 h-3" />}
              Per Materia
            </button>
            {expandedSections.subject && (
              <div className="mt-1 space-y-0.5 max-h-48 overflow-y-auto">
                {subjects.map(subject => {
                  const count = counts.bySubject[subject] || 0;
                  return (
                    <button
                      key={subject}
                      onClick={() => navigate({ subject, type: null, maestro: null, bookmarked: null })}
                      className={cn(
                        'w-full flex items-center gap-2 px-3 py-1.5 rounded-lg text-left text-sm transition-colors',
                        currentSubject === subject
                          ? 'bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-300'
                          : 'hover:bg-slate-200 dark:hover:bg-slate-800'
                      )}
                    >
                      {SUBJECT_LABELS[subject] || subject}
                      <span className="ml-auto text-xs opacity-70">{count}</span>
                    </button>
                  );
                })}
              </div>
            )}
          </div>
        )}

        {/* By Maestro */}
        {maestros.length > 0 && (
          <div className="mt-4">
            <button
              onClick={() => toggleSection('maestro')}
              className="w-full flex items-center gap-2 px-3 py-1.5 text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wide"
            >
              {expandedSections.maestro ? <ChevronDown className="w-3 h-3" /> : <ChevronRight className="w-3 h-3" />}
              Per Maestro
            </button>
            {expandedSections.maestro && (
              <div className="mt-1 space-y-0.5 max-h-48 overflow-y-auto">
                {maestros.map(maestro => {
                  const count = counts.byMaestro[maestro.id] || 0;
                  if (count === 0) return null;
                  return (
                    <button
                      key={maestro.id}
                      onClick={() => navigate({ maestro: maestro.id, type: null, subject: null, bookmarked: null })}
                      className={cn(
                        'w-full flex items-center gap-2 px-3 py-1.5 rounded-lg text-left text-sm transition-colors',
                        currentMaestro === maestro.id
                          ? 'bg-purple-100 dark:bg-purple-900/30 text-purple-700 dark:text-purple-300'
                          : 'hover:bg-slate-200 dark:hover:bg-slate-800'
                      )}
                    >
                      <Users className="w-4 h-4" />
                      {maestro.name}
                      <span className="ml-auto text-xs opacity-70">{count}</span>
                    </button>
                  );
                })}
              </div>
            )}
          </div>
        )}
      </nav>
    </aside>
  );
}
