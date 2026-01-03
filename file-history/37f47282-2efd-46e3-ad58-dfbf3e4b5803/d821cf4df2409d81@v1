'use client';

import { useEffect, useRef, useState, useCallback } from 'react';
import { motion } from 'framer-motion';
import { Markmap } from 'markmap-view';
import { Transformer } from 'markmap-lib';
import { Printer, Download, ZoomIn, ZoomOut, Accessibility, RotateCcw, Maximize, Minimize } from 'lucide-react';
import { cn } from '@/lib/utils';
import { logger } from '@/lib/logger';
import { useAccessibilityStore } from '@/lib/accessibility/accessibility-store';
import {
  convertParentIdToChildren,
  detectNodeFormat,
  type FlatNode,
} from '@/lib/tools/mindmap-utils';

// Node structure for programmatic mindmap creation
export interface MindmapNode {
  id: string;
  label: string;
  children?: MindmapNode[];
  icon?: string;
  color?: string;
}

// Props can accept either markdown string OR structured nodes
export interface MarkMapRendererProps {
  title: string;
  markdown?: string;
  nodes?: MindmapNode[];
  className?: string;
}

// Transformer instance for markdown parsing
const transformer = new Transformer();

// Convert structured nodes to markdown format
function nodesToMarkdown(nodes: MindmapNode[], title: string): string {
  const buildMarkdown = (node: MindmapNode, depth: number): string => {
    const prefix = '#'.repeat(depth + 1);
    let result = `${prefix} ${node.label}\n`;

    if (node.children && node.children.length > 0) {
      for (const child of node.children) {
        result += buildMarkdown(child, depth + 1);
      }
    }

    return result;
  };

  let markdown = `# ${title}\n`;
  for (const node of nodes) {
    markdown += buildMarkdown(node, 1);
  }

  return markdown;
}

export function MarkMapRenderer({ title, markdown, nodes, className }: MarkMapRendererProps) {
  const svgRef = useRef<SVGSVGElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const markmapRef = useRef<Markmap | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [rendered, setRendered] = useState(false);
  const [zoom, setZoom] = useState(1);
  const [accessibilityMode, setAccessibilityMode] = useState(false);
  const [isFullscreen, setIsFullscreen] = useState(false);

  const { settings } = useAccessibilityStore();

  // Get the markdown content - ADR 0020: Handle both parentId and children formats
  const getMarkdownContent = useCallback((): string => {
    // Prefer pre-generated markdown if available
    if (markdown) {
      return markdown;
    }

    if (nodes && nodes.length > 0) {
      // Detect node format and convert if needed
      const format = detectNodeFormat(nodes);

      if (format === 'parentId') {
        // Convert parentId format to children format for rendering
        const treeNodes = convertParentIdToChildren(nodes as FlatNode[]);
        return nodesToMarkdown(treeNodes, title);
      }

      // Already in children format or unknown (treat as children)
      return nodesToMarkdown(nodes, title);
    }

    return `# ${title}\n## No content`;
  }, [markdown, nodes, title]);

  // Generate accessible description
  const generateTextDescription = useCallback((): string => {
    if (nodes && nodes.length > 0) {
      const describeNode = (node: MindmapNode): string => {
        let desc = node.label;
        if (node.children && node.children.length > 0) {
          desc += ': ' + node.children.map(c => describeNode(c)).join(', ');
        }
        return desc;
      };
      return `${title} con i seguenti rami: ${nodes.map(n => describeNode(n)).join('; ')}`;
    }
    return `Mappa mentale: ${title}`;
  }, [nodes, title]);

  // Render mindmap
  useEffect(() => {
    const renderMindmap = async () => {
      if (!svgRef.current || !containerRef.current) return;

      // FIX BUG 16: Check container dimensions before rendering to prevent SVGLength error
      const container = containerRef.current;
      const rect = container.getBoundingClientRect();
      if (rect.width === 0 || rect.height === 0) {
        // Container not yet laid out, wait for next frame
        requestAnimationFrame(() => renderMindmap());
        return;
      }

      try {
        setError(null);
        setRendered(false);

        // Set explicit dimensions on SVG to prevent SVGLength error
        svgRef.current.setAttribute('width', String(rect.width));
        svgRef.current.setAttribute('height', String(rect.height - 60)); // Account for toolbar

        // Clear previous content
        svgRef.current.innerHTML = '';

        // Get markdown and transform to markmap data
        const content = getMarkdownContent();
        const { root } = transformer.transform(content);

        // Determine font family based on accessibility settings
        const fontFamily = settings.dyslexiaFont || accessibilityMode
          ? 'OpenDyslexic, Comic Sans MS, sans-serif'
          : 'Arial, Helvetica, sans-serif';

        // Determine colors based on accessibility settings
        const isHighContrast = settings.highContrast || accessibilityMode;

        // Create or update markmap
        if (markmapRef.current) {
          markmapRef.current.destroy();
        }

        markmapRef.current = Markmap.create(svgRef.current, {
          autoFit: true,
          duration: 300,
          maxWidth: 280,
          paddingX: 16,
          spacingVertical: 8,
          spacingHorizontal: 100,
          initialExpandLevel: 3, // Start with first 3 levels expanded, rest collapsed
          zoom: true, // Enable zoom/pan
          pan: true,  // Enable panning
          color: (node) => {
            if (isHighContrast) {
              // High contrast colors
              const colors = ['#ffff00', '#00ffff', '#ff00ff', '#00ff00', '#ff8000'];
              return colors[node.state?.depth % colors.length] || '#ffffff';
            }
            // Normal theme colors
            const colors = ['#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#ec4899'];
            return colors[node.state?.depth % colors.length] || '#64748b';
          },
        }, root);

        // Apply custom styles after render
        setTimeout(() => {
          if (svgRef.current) {
            // Apply font to all text elements
            const textElements = svgRef.current.querySelectorAll('text, foreignObject');
            textElements.forEach((el) => {
              if (el instanceof SVGElement || el instanceof HTMLElement) {
                el.style.fontFamily = fontFamily;
                if (settings.largeText) {
                  el.style.fontSize = '16px';
                }
              }
            });

            // C-20 FIX: Style expand/collapse circles for better visibility and ensure they're clickable
            const circles = svgRef.current.querySelectorAll('circle');
            circles.forEach((circle) => {
              if (circle instanceof SVGCircleElement) {
                circle.style.cursor = 'pointer';
                circle.style.pointerEvents = 'auto';
                // Make circles larger and more visible
                const r = parseFloat(circle.getAttribute('r') || '4');
                if (r < 6) {
                  circle.setAttribute('r', '6');
                }
                // Ensure stroke is visible
                if (!circle.getAttribute('stroke')) {
                  circle.setAttribute('stroke', isHighContrast ? '#ffffff' : '#475569');
                  circle.setAttribute('stroke-width', '2');
                }
              }
            });

            // C-20 FIX: Ensure all g elements (node groups) have pointer-events enabled
            const nodeGroups = svgRef.current.querySelectorAll('g.markmap-node');
            nodeGroups.forEach((g) => {
              if (g instanceof SVGGElement) {
                g.style.pointerEvents = 'auto';
                g.style.cursor = 'pointer';
              }
            });

            // High contrast background
            if (isHighContrast) {
              const rect = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
              rect.setAttribute('width', '100%');
              rect.setAttribute('height', '100%');
              rect.setAttribute('fill', '#000000');
              svgRef.current.insertBefore(rect, svgRef.current.firstChild);
            }
          }
        }, 100);

        // Add ARIA attributes
        svgRef.current.setAttribute('role', 'img');
        svgRef.current.setAttribute('aria-label', `Mappa mentale: ${title}`);

        // Add title and desc for screen readers
        const titleEl = document.createElementNS('http://www.w3.org/2000/svg', 'title');
        titleEl.textContent = `Mappa mentale: ${title}`;
        svgRef.current.insertBefore(titleEl, svgRef.current.firstChild);

        const descEl = document.createElementNS('http://www.w3.org/2000/svg', 'desc');
        descEl.textContent = generateTextDescription();
        svgRef.current.insertBefore(descEl, svgRef.current.firstChild?.nextSibling || null);

        setRendered(true);
      } catch (err) {
        const errorMsg = err instanceof Error ? err.message : String(err);
        setError(errorMsg);
        logger.error('MarkMap render error', { error: String(err) });
      }
    };

    renderMindmap();
  }, [markdown, nodes, title, settings.dyslexiaFont, settings.highContrast, settings.largeText, accessibilityMode, getMarkdownContent, generateTextDescription]);

  // Zoom controls
  const handleZoomIn = useCallback(() => {
    if (markmapRef.current) {
      markmapRef.current.rescale(1.25);
    }
    setZoom(z => Math.min(z * 1.25, 3));
  }, []);

  const handleZoomOut = useCallback(() => {
    if (markmapRef.current) {
      markmapRef.current.rescale(0.8);
    }
    setZoom(z => Math.max(z * 0.8, 0.5));
  }, []);

  const handleReset = useCallback(() => {
    if (markmapRef.current) {
      markmapRef.current.fit();
    }
    setZoom(1);
  }, []);

  // Fullscreen toggle
  const handleFullscreen = useCallback(async () => {
    if (!containerRef.current) return;

    try {
      if (!document.fullscreenElement) {
        await containerRef.current.requestFullscreen();
        setIsFullscreen(true);
      } else {
        await document.exitFullscreen();
        setIsFullscreen(false);
      }
    } catch (err) {
      logger.error('Fullscreen error', { error: String(err) });
    }
  }, []);

  // Listen for fullscreen changes (user may exit with Escape)
  useEffect(() => {
    const handleFullscreenChange = () => {
      setIsFullscreen(!!document.fullscreenElement);
      // Re-fit the mindmap when entering/exiting fullscreen
      if (markmapRef.current) {
        setTimeout(() => markmapRef.current?.fit(), 100);
      }
    };

    document.addEventListener('fullscreenchange', handleFullscreenChange);
    return () => document.removeEventListener('fullscreenchange', handleFullscreenChange);
  }, []);

  // Print functionality - expands labels to prevent truncation
  const handlePrint = useCallback(() => {
    if (!svgRef.current) return;

    const printWindow = window.open('', '_blank');
    if (!printWindow) return;

    const svgClone = svgRef.current.cloneNode(true) as SVGSVGElement;

    // Fix truncated labels: expand all foreignObject elements to fit their content
    const foreignObjects = svgClone.querySelectorAll('foreignObject');
    foreignObjects.forEach((fo) => {
      // Remove width constraint to let text flow naturally
      fo.setAttribute('width', '600'); // Expanded width for printing
      // Also update any nested div with max-width
      const divs = fo.querySelectorAll('div');
      divs.forEach((div) => {
        if (div instanceof HTMLElement) {
          div.style.maxWidth = 'none';
          div.style.width = 'auto';
          div.style.whiteSpace = 'nowrap';
          div.style.overflow = 'visible';
        }
      });
    });

    // Expand the SVG viewBox to accommodate wider labels
    const bbox = svgRef.current.getBBox();
    const expandedWidth = Math.max(bbox.width * 1.5, 1600);
    const expandedHeight = Math.max(bbox.height + 200, 1000);
    svgClone.setAttribute('width', String(expandedWidth));
    svgClone.setAttribute('height', String(expandedHeight));
    svgClone.setAttribute('viewBox', `${bbox.x - 100} ${bbox.y - 50} ${expandedWidth} ${expandedHeight}`);

    const svgString = new XMLSerializer().serializeToString(svgClone);

    printWindow.document.write(`
      <!DOCTYPE html>
      <html>
        <head>
          <title>Mappa Mentale: ${title}</title>
          <style>
            @import url('https://fonts.cdnfonts.com/css/opendyslexic');

            * {
              box-sizing: border-box;
              margin: 0;
              padding: 0;
            }

            html, body {
              width: 100%;
              height: 100%;
              margin: 0;
              padding: 0;
              font-family: ${settings.dyslexiaFont ? 'OpenDyslexic, ' : ''}Arial, sans-serif;
              background: white;
            }

            .print-page {
              width: 100%;
              height: 100vh;
              display: flex;
              flex-direction: column;
              padding: 10mm;
            }

            h1 {
              text-align: center;
              font-size: ${settings.largeText ? '24pt' : '18pt'};
              margin-bottom: 8mm;
              flex-shrink: 0;
            }

            .mindmap-container {
              flex: 1;
              display: flex;
              justify-content: center;
              align-items: center;
              overflow: visible;
              min-height: 0;
            }

            .mindmap-container svg {
              max-width: 100%;
              max-height: 100%;
              width: auto;
              height: auto;
              overflow: visible;
            }

            /* Ensure all text is visible */
            foreignObject { overflow: visible !important; }
            foreignObject div {
              max-width: none !important;
              white-space: nowrap !important;
              overflow: visible !important;
            }

            @media print {
              @page {
                size: A4 landscape;
                margin: 5mm;
              }

              html, body {
                -webkit-print-color-adjust: exact;
                print-color-adjust: exact;
              }

              .print-page {
                height: 100%;
                page-break-after: avoid;
                padding: 5mm;
              }

              h1 {
                font-size: ${settings.largeText ? '20pt' : '16pt'};
                margin-bottom: 5mm;
              }
            }
          </style>
        </head>
        <body>
          <div class="print-page">
            <h1>${title}</h1>
            <div class="mindmap-container">${svgString}</div>
          </div>
          <script>
            window.onload = function() {
              setTimeout(function() { window.print(); window.close(); }, 500);
            };
          </script>
        </body>
      </html>
    `);
    printWindow.document.close();
  }, [title, settings.dyslexiaFont, settings.largeText]);

  // Download as PNG - expands labels to prevent truncation
  const handleDownload = useCallback(async () => {
    if (!svgRef.current) return;

    try {
      const svgClone = svgRef.current.cloneNode(true) as SVGSVGElement;

      // Fix truncated labels: expand all foreignObject elements to fit their content
      const foreignObjects = svgClone.querySelectorAll('foreignObject');
      foreignObjects.forEach((fo) => {
        fo.setAttribute('width', '600'); // Expanded width for download
        const divs = fo.querySelectorAll('div');
        divs.forEach((div) => {
          if (div instanceof HTMLElement) {
            div.style.maxWidth = 'none';
            div.style.width = 'auto';
            div.style.whiteSpace = 'nowrap';
            div.style.overflow = 'visible';
          }
        });
      });

      // Get dimensions with extra space for expanded labels
      const bbox = svgRef.current.getBBox();
      const width = Math.max(bbox.width * 1.5, 2000);
      const height = Math.max(bbox.height + 200, 1200);

      svgClone.setAttribute('width', String(width));
      svgClone.setAttribute('height', String(height));
      svgClone.setAttribute('viewBox', `${bbox.x - 100} ${bbox.y - 50} ${width} ${height}`);

      // Inline styles
      const allElements = svgClone.querySelectorAll('*');
      allElements.forEach((el) => {
        if (el instanceof SVGElement || el instanceof HTMLElement) {
          const computed = window.getComputedStyle(el);
          ['fill', 'stroke', 'stroke-width', 'font-family', 'font-size', 'font-weight'].forEach((prop) => {
            const value = computed.getPropertyValue(prop);
            if (value && value !== 'none' && value !== 'initial') {
              (el as HTMLElement).style.setProperty(prop, value);
            }
          });
        }
      });

      // Create canvas
      const canvas = document.createElement('canvas');
      canvas.width = width;
      canvas.height = height;
      const ctx = canvas.getContext('2d');
      if (!ctx) return;

      // White background
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, 0, width, height);

      // SVG to data URL
      const serializer = new XMLSerializer();
      let svgString = serializer.serializeToString(svgClone);
      if (!svgString.includes('xmlns=')) {
        svgString = svgString.replace('<svg', '<svg xmlns="http://www.w3.org/2000/svg"');
      }

      const base64 = btoa(unescape(encodeURIComponent(svgString)));
      const dataUrl = `data:image/svg+xml;base64,${base64}`;

      const img = new Image();
      img.crossOrigin = 'anonymous';

      img.onload = () => {
        ctx.drawImage(img, 0, 0, width, height);
        canvas.toBlob((blob) => {
          if (!blob) return;
          const url = URL.createObjectURL(blob);
          const a = document.createElement('a');
          a.href = url;
          a.download = `mappa-mentale-${title.toLowerCase().replace(/\s+/g, '-')}.png`;
          document.body.appendChild(a);
          a.click();
          document.body.removeChild(a);
          URL.revokeObjectURL(url);
        }, 'image/png');
      };

      img.onerror = () => {
        // Fallback: download SVG
        const svgBlob = new Blob([svgString], { type: 'image/svg+xml' });
        const url = URL.createObjectURL(svgBlob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `mappa-mentale-${title.toLowerCase().replace(/\s+/g, '-')}.svg`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
      };

      img.src = dataUrl;
    } catch (err) {
      logger.error('Export error', { error: String(err) });
    }
  }, [title]);

  return (
    <motion.div
      ref={containerRef}
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      className={cn(
        'rounded-xl border overflow-hidden',
        settings.highContrast
          ? 'border-white bg-black'
          : 'border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800',
        isFullscreen && 'fixed inset-0 z-50 rounded-none',
        className
      )}
      role="region"
      aria-label={`Mappa mentale: ${title}`}
    >
      {/* Toolbar */}
      <div
        className={cn(
          'flex items-center justify-between px-4 py-2 border-b',
          settings.highContrast
            ? 'border-white bg-black'
            : 'border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800/50'
        )}
      >
        <h3
          className={cn(
            'font-semibold',
            settings.dyslexiaFont && 'tracking-wide',
            settings.highContrast ? 'text-yellow-400' : 'text-slate-700 dark:text-slate-200'
          )}
          style={{ fontSize: `${14 * (settings.largeText ? 1.2 : 1)}px` }}
        >
          {title}
        </h3>

        <div className="flex items-center gap-2">
          {/* Accessibility toggle */}
          <button
            onClick={() => setAccessibilityMode(!accessibilityMode)}
            className={cn(
              'p-2 rounded-lg transition-colors',
              accessibilityMode
                ? 'bg-accent-themed text-white'
                : settings.highContrast
                  ? 'bg-yellow-400 text-black hover:bg-yellow-300'
                  : 'bg-slate-200 dark:bg-slate-700 hover:bg-slate-300 dark:hover:bg-slate-600'
            )}
            title="Modalita accessibilita"
            aria-label="Attiva/disattiva modalita accessibilita"
          >
            <Accessibility className="w-4 h-4" />
          </button>

          {/* Reset view */}
          <button
            onClick={handleReset}
            className={cn(
              'p-2 rounded-lg transition-colors',
              settings.highContrast
                ? 'bg-yellow-400 text-black hover:bg-yellow-300'
                : 'bg-slate-200 dark:bg-slate-700 hover:bg-slate-300 dark:hover:bg-slate-600'
            )}
            title="Ripristina vista"
            aria-label="Ripristina vista"
          >
            <RotateCcw className="w-4 h-4" />
          </button>

          {/* Zoom controls */}
          <button
            onClick={handleZoomOut}
            className={cn(
              'p-2 rounded-lg transition-colors',
              settings.highContrast
                ? 'bg-yellow-400 text-black hover:bg-yellow-300'
                : 'bg-slate-200 dark:bg-slate-700 hover:bg-slate-300 dark:hover:bg-slate-600'
            )}
            title="Riduci zoom"
            aria-label="Riduci zoom"
          >
            <ZoomOut className="w-4 h-4" />
          </button>

          <span
            className={cn(
              'text-sm min-w-[4rem] text-center',
              settings.highContrast ? 'text-white' : 'text-slate-600 dark:text-slate-400'
            )}
          >
            {Math.round(zoom * 100)}%
          </span>

          <button
            onClick={handleZoomIn}
            className={cn(
              'p-2 rounded-lg transition-colors',
              settings.highContrast
                ? 'bg-yellow-400 text-black hover:bg-yellow-300'
                : 'bg-slate-200 dark:bg-slate-700 hover:bg-slate-300 dark:hover:bg-slate-600'
            )}
            title="Aumenta zoom"
            aria-label="Aumenta zoom"
          >
            <ZoomIn className="w-4 h-4" />
          </button>

          {/* Fullscreen toggle */}
          <button
            onClick={handleFullscreen}
            className={cn(
              'p-2 rounded-lg transition-colors',
              isFullscreen
                ? 'bg-green-500 text-white hover:bg-green-600'
                : settings.highContrast
                  ? 'bg-yellow-400 text-black hover:bg-yellow-300'
                  : 'bg-slate-200 dark:bg-slate-700 hover:bg-slate-300 dark:hover:bg-slate-600'
            )}
            title={isFullscreen ? 'Esci da schermo intero' : 'Schermo intero'}
            aria-label={isFullscreen ? 'Esci da schermo intero' : 'Schermo intero'}
          >
            {isFullscreen ? <Minimize className="w-4 h-4" /> : <Maximize className="w-4 h-4" />}
          </button>

          {/* Download */}
          <button
            onClick={handleDownload}
            className={cn(
              'p-2 rounded-lg transition-colors',
              settings.highContrast
                ? 'bg-yellow-400 text-black hover:bg-yellow-300'
                : 'bg-slate-200 dark:bg-slate-700 hover:bg-slate-300 dark:hover:bg-slate-600'
            )}
            title="Scarica PNG"
            aria-label="Scarica mappa come PNG"
          >
            <Download className="w-4 h-4" />
          </button>

          {/* Print */}
          <button
            onClick={handlePrint}
            className={cn(
              'p-2 rounded-lg transition-colors',
              settings.highContrast
                ? 'bg-yellow-400 text-black hover:bg-yellow-300'
                : 'bg-accent-themed text-white hover:brightness-110'
            )}
            title="Stampa"
            aria-label="Stampa mappa mentale"
          >
            <Printer className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* Mindmap container - centered with pan/zoom support */}
      <div
        className={cn(
          'flex items-center justify-center overflow-hidden relative',
          settings.highContrast ? 'bg-black' : 'bg-white dark:bg-slate-900',
          isFullscreen && 'flex-1'
        )}
        style={{
          height: isFullscreen ? 'calc(100vh - 60px)' : '500px',
          minHeight: isFullscreen ? 'calc(100vh - 60px)' : '400px'
        }}
      >
        {error ? (
          <div
            className={cn(
              'p-4 rounded-lg text-sm',
              settings.highContrast
                ? 'bg-red-900 border-2 border-red-500 text-white'
                : 'bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-600 dark:text-red-400'
            )}
            role="alert"
          >
            <strong>Errore:</strong> {error}
          </div>
        ) : (
          <>
            <svg
              ref={svgRef}
              width="100%"
              height="100%"
              className={cn(
                'absolute inset-0 w-full h-full cursor-grab active:cursor-grabbing',
                !rendered && 'animate-pulse rounded-lg',
                !rendered && (settings.highContrast ? 'bg-gray-800' : 'bg-slate-100 dark:bg-slate-700/50')
              )}
              style={{ touchAction: 'none', minWidth: '400px', minHeight: '300px' }}
            />
            {rendered && (
              <div className="absolute bottom-2 left-2 text-xs text-slate-400 dark:text-slate-500 pointer-events-none select-none">
                Trascina per spostare • Scroll/pinch per zoom • Click sui nodi per espandere/comprimere
              </div>
            )}
          </>
        )}
      </div>

      {/* Screen reader description */}
      <div className="sr-only" aria-live="polite">
        {rendered && `Mappa mentale "${title}" renderizzata con successo.`}
      </div>
    </motion.div>
  );
}

// Helper to create mindmap from topics (same interface as before)
export function createMindmapFromTopics(
  title: string,
  topics: Array<{ name: string; subtopics?: string[] }>
): { title: string; nodes: MindmapNode[] } {
  return {
    title,
    nodes: topics.map((topic, i) => ({
      id: `topic-${i}`,
      label: topic.name,
      children: topic.subtopics?.map((sub, j) => ({
        id: `topic-${i}-sub-${j}`,
        label: sub,
      })),
    })),
  };
}

// Helper to create mindmap from markdown
export function createMindmapFromMarkdown(
  title: string,
  markdown: string
): { title: string; markdown: string } {
  return { title, markdown };
}

// Backward compatibility alias (old name was MindmapRenderer)
export { MarkMapRenderer as MindmapRenderer };

// Example mindmaps for testing
export const exampleMindmaps = {
  matematica: createMindmapFromTopics('Matematica', [
    { name: 'Algebra', subtopics: ['Equazioni di primo grado', 'Equazioni di secondo grado', 'Polinomi e fattorizzazione'] },
    { name: 'Geometria', subtopics: ['Triangoli e proprieta', 'Cerchi e circonferenze', 'Solidi geometrici'] },
    { name: 'Analisi', subtopics: ['Limiti e continuita', 'Derivate e applicazioni', 'Integrali definiti'] },
  ]),

  storia: createMindmapFromTopics('Storia', [
    { name: 'Antichita', subtopics: ['Civilta greca', 'Impero romano', 'Antico Egitto'] },
    { name: 'Medioevo', subtopics: ['Sistema feudale', 'Le Crociate', 'Comuni italiani'] },
    { name: 'Eta Moderna', subtopics: ['Rinascimento italiano', 'Scoperte geografiche', 'Riforma protestante'] },
  ]),
};
