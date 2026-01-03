'use client';

/**
 * Supporti View (Wave 4)
 * Main view combining sidebar + materials grid
 */

import { useState, useEffect, useMemo, useCallback, useRef, type ChangeEvent } from 'react';
import { AnimatePresence } from 'framer-motion';
import { useRouter, useSearchParams } from 'next/navigation';
import Fuse from 'fuse.js';
import { Grid, List, Search, X, ChevronRight, Home } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { logger } from '@/lib/logger';
import { getActiveMaterials, deleteMaterial } from '@/lib/storage/materials-db';
import { getAllMaestri } from '@/data/maestri';
import {
  type SortBy,
  type ViewMode,
  type ArchiveItem,
  SORT_OPTIONS,
  TOOL_LABELS,
  SUBJECT_LABELS,
  updateMaterialInteraction,
  EmptyState,
  GridView,
  ListView,
  MaterialViewer,
} from '@/components/education/archive';
import { Sidebar } from './sidebar';

interface SupportiViewProps {
  initialType?: string;
  initialSubject?: string;
  initialMaestro?: string;
  initialSource?: string;
}

export function SupportiView({
  initialType,
  initialSubject,
  initialMaestro,
}: SupportiViewProps) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [sortBy, setSortBy] = useState<SortBy>('date');
  const [searchQuery, setSearchQuery] = useState('');
  const [viewMode, setViewMode] = useState<ViewMode>('grid');
  const [materials, setMaterials] = useState<ArchiveItem[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedItem, setSelectedItem] = useState<ArchiveItem | null>(null);
  const [debouncedQuery, setDebouncedQuery] = useState('');
  const searchTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Get current filters from URL
  const typeFilter = searchParams.get('type') || initialType;
  const subjectFilter = searchParams.get('subject') || initialSubject;
  const maestroFilter = searchParams.get('maestro') || initialMaestro;
  const isBookmarked = searchParams.get('bookmarked') === 'true';

  // Load all maestri for sidebar
  const allMaestri = useMemo(() =>
    getAllMaestri().map(m => ({ id: m.id, name: m.name })),
  []);

  // Debounce search
  useEffect(() => {
    if (searchTimerRef.current) clearTimeout(searchTimerRef.current);
    searchTimerRef.current = setTimeout(() => setDebouncedQuery(searchQuery), 200);
    return () => { if (searchTimerRef.current) clearTimeout(searchTimerRef.current); };
  }, [searchQuery]);

  // Load materials
  useEffect(() => {
    async function load() {
      setIsLoading(true);
      try {
        const records = await getActiveMaterials();
        setMaterials(records as ArchiveItem[]);
      } catch (error) {
        logger.error('Failed to load materials', { error });
      }
      setIsLoading(false);
    }
    load();
  }, []);

  // Compute counts for sidebar
  const counts = useMemo(() => {
    const result = {
      total: materials.length,
      bookmarked: 0,
      byType: {} as Record<string, number>,
      bySubject: {} as Record<string, number>,
      byMaestro: {} as Record<string, number>,
    };
    for (const item of materials) {
      if (item.isBookmarked) result.bookmarked++;
      result.byType[item.toolType] = (result.byType[item.toolType] || 0) + 1;
      if (item.subject) result.bySubject[item.subject] = (result.bySubject[item.subject] || 0) + 1;
      if (item.maestroId) result.byMaestro[item.maestroId] = (result.byMaestro[item.maestroId] || 0) + 1;
    }
    return result;
  }, [materials]);

  // Extract unique subjects
  const subjects = useMemo(() =>
    Array.from(new Set(materials.map(m => m.subject).filter(Boolean) as string[])).sort(),
  [materials]);

  // Filter and sort
  const filtered = useMemo(() => {
    let result = [...materials];

    if (isBookmarked) {
      result = result.filter(item => item.isBookmarked);
    }
    if (typeFilter) {
      result = result.filter(item => item.toolType === typeFilter);
    }
    if (subjectFilter) {
      result = result.filter(item => item.subject === subjectFilter);
    }
    if (maestroFilter) {
      result = result.filter(item => item.maestroId === maestroFilter);
    }

    // Fuzzy search
    if (debouncedQuery.trim()) {
      const fuse = new Fuse(result, {
        keys: [
          { name: 'title', weight: 2 },
          { name: 'subject', weight: 1 },
          { name: 'maestroId', weight: 0.5 },
        ],
        threshold: 0.3,
        ignoreLocation: true,
        minMatchCharLength: 2,
      });
      result = fuse.search(debouncedQuery).map(r => r.item);
    }

    // Sort
    result.sort((a, b) => {
      switch (sortBy) {
        case 'date': return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();
        case 'type': return a.toolType.localeCompare(b.toolType);
        case 'rating': return (b.userRating || 0) - (a.userRating || 0);
        case 'views': return (b.viewCount || 0) - (a.viewCount || 0);
        default: return 0;
      }
    });

    return result;
  }, [materials, typeFilter, subjectFilter, maestroFilter, isBookmarked, debouncedQuery, sortBy]);

  // Handlers
  const handleDelete = async (toolId: string) => {
    if (!confirm('Sei sicuro di voler eliminare questo materiale?')) return;
    try {
      await deleteMaterial(toolId);
      setMaterials(prev => prev.filter(m => m.toolId !== toolId));
    } catch (error) {
      logger.error('Failed to delete', { error });
    }
  };

  const handleView = useCallback((item: ArchiveItem) => setSelectedItem(item), []);
  const handleCloseViewer = useCallback(() => setSelectedItem(null), []);
  const handleSearchChange = (e: ChangeEvent<HTMLInputElement>) => setSearchQuery(e.target.value);

  const handleBookmark = useCallback(async (toolId: string, isBookmarked: boolean) => {
    const success = await updateMaterialInteraction(toolId, { isBookmarked });
    if (success) setMaterials(prev => prev.map(m => m.toolId === toolId ? { ...m, isBookmarked } : m));
  }, []);

  const handleRate = useCallback(async (toolId: string, userRating: number) => {
    const success = await updateMaterialInteraction(toolId, { userRating });
    if (success) setMaterials(prev => prev.map(m => m.toolId === toolId ? { ...m, userRating } : m));
  }, []);

  // Build breadcrumb
  const breadcrumb = useMemo(() => {
    const parts: Array<{ label: string; href?: string }> = [{ label: 'Supporti', href: '/supporti' }];
    if (typeFilter) parts.push({ label: TOOL_LABELS[typeFilter as keyof typeof TOOL_LABELS] || typeFilter });
    if (subjectFilter) parts.push({ label: SUBJECT_LABELS[subjectFilter] || subjectFilter });
    if (maestroFilter) {
      const m = allMaestri.find(x => x.id === maestroFilter);
      parts.push({ label: m?.name || maestroFilter });
    }
    if (isBookmarked) parts.push({ label: 'Preferiti' });
    return parts;
  }, [typeFilter, subjectFilter, maestroFilter, isBookmarked, allMaestri]);

  return (
    <div className="flex h-full">
      <Sidebar counts={counts} subjects={subjects} maestros={allMaestri} />

      <div className="flex-1 p-6 overflow-y-auto">
        {/* Breadcrumb */}
        <nav aria-label="Breadcrumb" className="mb-4">
          <ol className="flex items-center gap-1 text-sm text-slate-500">
            <li><Home className="w-4 h-4" /></li>
            {breadcrumb.map((item, i) => (
              <li key={i} className="flex items-center gap-1">
                <ChevronRight className="w-4 h-4" />
                {item.href ? (
                  <button onClick={() => router.push(item.href!)} className="hover:text-primary">{item.label}</button>
                ) : (
                  <span className="text-slate-900 dark:text-white font-medium">{item.label}</span>
                )}
              </li>
            ))}
          </ol>
        </nav>

        {/* Header */}
        <div className="flex flex-col sm:flex-row gap-4 items-start sm:items-center justify-between mb-6">
          <div>
            <h1 className="text-2xl font-bold text-slate-900 dark:text-white">I Tuoi Supporti</h1>
            <p className="text-sm text-slate-500">{filtered.length} materiali</p>
          </div>

          <div className="flex items-center gap-2 w-full sm:w-auto">
            <div className="relative flex-1 sm:flex-initial">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
              <input
                type="text"
                placeholder="Cerca..."
                value={searchQuery}
                onChange={handleSearchChange}
                className="pl-9 w-full sm:w-48 h-10 rounded-md border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900 text-sm focus:ring-2 focus:ring-primary"
                aria-label="Cerca materiali"
              />
              {searchQuery && (
                <button onClick={() => setSearchQuery('')} className="absolute right-3 top-1/2 -translate-y-1/2">
                  <X className="w-4 h-4 text-slate-400" />
                </button>
              )}
            </div>

            <select
              value={sortBy}
              onChange={e => setSortBy(e.target.value as SortBy)}
              className="appearance-none pl-8 pr-8 h-9 rounded-md border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900 text-sm cursor-pointer"
              aria-label="Ordina per"
            >
              {SORT_OPTIONS.map(opt => <option key={opt.value} value={opt.value}>{opt.label}</option>)}
            </select>

            <div className="flex border rounded-lg dark:border-slate-700">
              <Button
                variant="ghost"
                size="icon"
                className={cn('rounded-r-none', viewMode === 'grid' && 'bg-slate-100 dark:bg-slate-800')}
                onClick={() => setViewMode('grid')}
                aria-label="Vista griglia"
              >
                <Grid className="w-4 h-4" />
              </Button>
              <Button
                variant="ghost"
                size="icon"
                className={cn('rounded-l-none', viewMode === 'list' && 'bg-slate-100 dark:bg-slate-800')}
                onClick={() => setViewMode('list')}
                aria-label="Vista lista"
              >
                <List className="w-4 h-4" />
              </Button>
            </div>
          </div>
        </div>

        {/* Content */}
        {isLoading ? (
          <div className="flex items-center justify-center py-16">
            <div className="animate-spin w-8 h-8 border-2 border-primary border-t-transparent rounded-full" />
          </div>
        ) : filtered.length === 0 ? (
          <EmptyState filter="all" />
        ) : viewMode === 'grid' ? (
          <GridView items={filtered} onDelete={handleDelete} onView={handleView} onBookmark={handleBookmark} onRate={handleRate} />
        ) : (
          <ListView items={filtered} onDelete={handleDelete} onView={handleView} onBookmark={handleBookmark} onRate={handleRate} />
        )}
      </div>

      <AnimatePresence>
        {selectedItem && <MaterialViewer item={selectedItem} onClose={handleCloseViewer} />}
      </AnimatePresence>
    </div>
  );
}
