'use client';

/**
 * Interactive MarkMap Renderer
 *
 * Extended version of MarkMapRenderer with support for real-time modifications
 * via voice commands. Exposes an imperative handle for programmatic control.
 *
 * Part of Phase 7: Voice Commands for Mindmaps
 */

import {
  useEffect,
  useRef,
  useState,
  useCallback,
  forwardRef,
  useImperativeHandle,
} from 'react';
import { motion } from 'framer-motion';
import { Markmap } from 'markmap-view';
import { Transformer } from 'markmap-lib';
import {
  Printer,
  Download,
  ZoomIn,
  ZoomOut,
  Accessibility,
  RotateCcw,
  Maximize,
  Minimize,
  Undo2,
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { logger } from '@/lib/logger';
import { useAccessibilityStore } from '@/lib/accessibility/accessibility-store';
import { nanoid } from 'nanoid';
import type { MindmapNode } from './markmap-renderer';

// ============================================================================
// TYPES
// ============================================================================

// Color name to hex mapping for Italian color commands
const COLOR_MAP: Record<string, string> = {
  rosso: '#ef4444',
  red: '#ef4444',
  blu: '#3b82f6',
  blue: '#3b82f6',
  verde: '#10b981',
  green: '#10b981',
  giallo: '#facc15',
  yellow: '#facc15',
  arancione: '#f97316',
  orange: '#f97316',
  viola: '#8b5cf6',
  purple: '#8b5cf6',
  rosa: '#ec4899',
  pink: '#ec4899',
};

// Props for the interactive renderer
export interface InteractiveMarkMapRendererProps {
  title: string;
  initialMarkdown?: string;
  initialNodes?: MindmapNode[];
  className?: string;
  onNodesChange?: (nodes: MindmapNode[]) => void;
}

// Imperative handle exposed by the component
export interface InteractiveMarkMapHandle {
  // Modification methods
  addNode: (concept: string, parentNodeLabel?: string) => boolean;
  expandNode: (nodeLabel: string, suggestions?: string[]) => boolean;
  deleteNode: (nodeLabel: string) => boolean;
  focusNode: (nodeLabel: string) => boolean;
  setNodeColor: (nodeLabel: string, color: string) => boolean;
  connectNodes: (nodeALabel: string, nodeBLabel: string) => boolean;

  // View methods
  zoomIn: () => void;
  zoomOut: () => void;
  resetView: () => void;
  toggleFullscreen: () => Promise<void>;

  // State methods
  getNodes: () => MindmapNode[];
  setNodes: (nodes: MindmapNode[]) => void;
  undo: () => boolean;
}

// Transformer instance for markdown parsing
const transformer = new Transformer();

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

// Convert markdown to nodes (simplified parsing)
function markdownToNodes(markdown: string): MindmapNode[] {
  const lines = markdown.split('\n').filter((line) => line.trim());
  const root: MindmapNode[] = [];
  const stack: { node: MindmapNode; depth: number }[] = [];

  for (const line of lines) {
    const match = line.match(/^(#+)\s+(.+)$/);
    if (!match) continue;

    const depth = match[1].length;
    const label = match[2].trim();
    const node: MindmapNode = {
      id: nanoid(8),
      label,
      children: [],
    };

    if (depth === 1) {
      // This is the root title, skip
      continue;
    }

    // Find parent at depth - 1
    while (stack.length > 0 && stack[stack.length - 1].depth >= depth) {
      stack.pop();
    }

    if (stack.length === 0) {
      root.push(node);
    } else {
      const parent = stack[stack.length - 1].node;
      if (!parent.children) parent.children = [];
      parent.children.push(node);
    }

    stack.push({ node, depth });
  }

  return root;
}

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

// Find a node by label (case-insensitive, partial match)
function findNodeByLabel(
  nodes: MindmapNode[],
  label: string
): { node: MindmapNode; parent: MindmapNode | null; index: number } | null {
  const normalizedLabel = label.toLowerCase().trim();

  const search = (
    nodeList: MindmapNode[],
    parent: MindmapNode | null
  ): { node: MindmapNode; parent: MindmapNode | null; index: number } | null => {
    for (let i = 0; i < nodeList.length; i++) {
      const node = nodeList[i];
      if (node.label.toLowerCase().includes(normalizedLabel)) {
        return { node, parent, index: i };
      }
      if (node.children && node.children.length > 0) {
        const found = search(node.children, node);
        if (found) return found;
      }
    }
    return null;
  };

  return search(nodes, null);
}

// Deep clone nodes
function cloneNodes(nodes: MindmapNode[]): MindmapNode[] {
  return JSON.parse(JSON.stringify(nodes));
}

// ============================================================================
// COMPONENT
// ============================================================================

export const InteractiveMarkMapRenderer = forwardRef<
  InteractiveMarkMapHandle,
  InteractiveMarkMapRendererProps
>(function InteractiveMarkMapRenderer(
  { title, initialMarkdown, initialNodes, className, onNodesChange },
  ref
) {
  const svgRef = useRef<SVGSVGElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const markmapRef = useRef<Markmap | null>(null);

  const [error, setError] = useState<string | null>(null);
  const [rendered, setRendered] = useState(false);
  const [zoom, setZoom] = useState(1);
  const [accessibilityMode, setAccessibilityMode] = useState(false);
  const [isFullscreen, setIsFullscreen] = useState(false);

  // Internal node state for modifications
  const [nodes, setNodesState] = useState<MindmapNode[]>(() => {
    if (initialNodes && initialNodes.length > 0) {
      return cloneNodes(initialNodes);
    }
    if (initialMarkdown) {
      return markdownToNodes(initialMarkdown);
    }
    return [];
  });

  // Undo history
  const [history, setHistory] = useState<MindmapNode[][]>([]);

  const { settings } = useAccessibilityStore();

  // Save state for undo
  const saveToHistory = useCallback(() => {
    setHistory((prev) => [...prev.slice(-20), cloneNodes(nodes)]);
  }, [nodes]);

  // Update nodes and notify parent
  const updateNodes = useCallback(
    (newNodes: MindmapNode[]) => {
      saveToHistory();
      setNodesState(newNodes);
      onNodesChange?.(newNodes);
    },
    [saveToHistory, onNodesChange]
  );

  // ============================================================================
  // MODIFICATION METHODS
  // ============================================================================

  const addNode = useCallback(
    (concept: string, parentNodeLabel?: string): boolean => {
      const newNode: MindmapNode = {
        id: nanoid(8),
        label: concept,
        children: [],
      };

      if (!parentNodeLabel) {
        // Add to root level
        updateNodes([...nodes, newNode]);
        logger.info('[InteractiveMarkmap] Added root node', { concept });
        return true;
      }

      // Find parent node
      const found = findNodeByLabel(nodes, parentNodeLabel);
      if (!found) {
        // If parent not found, add to root
        updateNodes([...nodes, newNode]);
        logger.warn('[InteractiveMarkmap] Parent not found, added to root', {
          concept,
          parentNodeLabel,
        });
        return true;
      }

      // Add to parent
      const newNodes = cloneNodes(nodes);
      const parentInClone = findNodeByLabel(newNodes, parentNodeLabel);
      if (parentInClone) {
        if (!parentInClone.node.children) parentInClone.node.children = [];
        parentInClone.node.children.push(newNode);
        updateNodes(newNodes);
        logger.info('[InteractiveMarkmap] Added child node', {
          concept,
          parentNodeLabel,
        });
        return true;
      }

      return false;
    },
    [nodes, updateNodes]
  );

  const expandNode = useCallback(
    (nodeLabel: string, suggestions?: string[]): boolean => {
      const found = findNodeByLabel(nodes, nodeLabel);
      if (!found) {
        logger.warn('[InteractiveMarkmap] Node not found for expand', {
          nodeLabel,
        });
        return false;
      }

      const newNodes = cloneNodes(nodes);
      const nodeInClone = findNodeByLabel(newNodes, nodeLabel);
      if (!nodeInClone) return false;

      // Add suggestions as children
      const childLabels = suggestions || [
        `${nodeLabel} - Dettaglio 1`,
        `${nodeLabel} - Dettaglio 2`,
        `${nodeLabel} - Dettaglio 3`,
      ];

      if (!nodeInClone.node.children) nodeInClone.node.children = [];
      for (const label of childLabels) {
        nodeInClone.node.children.push({
          id: nanoid(8),
          label,
          children: [],
        });
      }

      updateNodes(newNodes);
      logger.info('[InteractiveMarkmap] Expanded node', {
        nodeLabel,
        childCount: childLabels.length,
      });
      return true;
    },
    [nodes, updateNodes]
  );

  const deleteNode = useCallback(
    (nodeLabel: string): boolean => {
      const found = findNodeByLabel(nodes, nodeLabel);
      if (!found) {
        logger.warn('[InteractiveMarkmap] Node not found for delete', {
          nodeLabel,
        });
        return false;
      }

      const newNodes = cloneNodes(nodes);

      if (!found.parent) {
        // Root level node
        newNodes.splice(found.index, 1);
      } else {
        const parentInClone = findNodeByLabel(newNodes, found.parent.label);
        if (parentInClone && parentInClone.node.children) {
          const idx = parentInClone.node.children.findIndex(
            (c) => c.label.toLowerCase() === found.node.label.toLowerCase()
          );
          if (idx >= 0) {
            parentInClone.node.children.splice(idx, 1);
          }
        }
      }

      updateNodes(newNodes);
      logger.info('[InteractiveMarkmap] Deleted node', { nodeLabel });
      return true;
    },
    [nodes, updateNodes]
  );

  const focusNode = useCallback(
    (nodeLabel: string): boolean => {
      if (!markmapRef.current || !svgRef.current) return false;

      // Find the node in the SVG
      const textElements = svgRef.current.querySelectorAll('text, foreignObject');
      const normalizedLabel = nodeLabel.toLowerCase().trim();

      for (const el of textElements) {
        const text = el.textContent?.toLowerCase().trim();
        if (text && text.includes(normalizedLabel)) {
          // Get the g element that contains this node
          let parent = el.parentElement;
          while (parent && parent.tagName !== 'g') {
            parent = parent.parentElement;
          }

          if (parent) {
            // Scroll into view
            parent.scrollIntoView({ behavior: 'smooth', block: 'center' });

            // Flash highlight
            const svgParent = parent as unknown as SVGElement;
            const originalFill = svgParent.style.fill;
            svgParent.style.fill = '#facc15';
            setTimeout(() => {
              svgParent.style.fill = originalFill;
            }, 1000);

            logger.info('[InteractiveMarkmap] Focused on node', { nodeLabel });
            return true;
          }
        }
      }

      logger.warn('[InteractiveMarkmap] Node not found for focus', { nodeLabel });
      return false;
    },
    []
  );

  const setNodeColor = useCallback(
    (nodeLabel: string, color: string): boolean => {
      const found = findNodeByLabel(nodes, nodeLabel);
      if (!found) {
        logger.warn('[InteractiveMarkmap] Node not found for color', {
          nodeLabel,
        });
        return false;
      }

      // Resolve color name to hex
      const resolvedColor = COLOR_MAP[color.toLowerCase()] || color;

      const newNodes = cloneNodes(nodes);
      const nodeInClone = findNodeByLabel(newNodes, nodeLabel);
      if (nodeInClone) {
        nodeInClone.node.color = resolvedColor;
        updateNodes(newNodes);
        logger.info('[InteractiveMarkmap] Set node color', {
          nodeLabel,
          color: resolvedColor,
        });
        return true;
      }

      return false;
    },
    [nodes, updateNodes]
  );

  const connectNodes = useCallback(
    (nodeALabel: string, nodeBLabel: string): boolean => {
      // In a tree structure, "connect" means move nodeB under nodeA
      const foundA = findNodeByLabel(nodes, nodeALabel);
      const foundB = findNodeByLabel(nodes, nodeBLabel);

      if (!foundA || !foundB) {
        logger.warn('[InteractiveMarkmap] Nodes not found for connect', {
          nodeALabel,
          nodeBLabel,
        });
        return false;
      }

      // Remove nodeB from its current position
      const newNodes = cloneNodes(nodes);

      // First, find and remove nodeB
      const foundBInClone = findNodeByLabel(newNodes, nodeBLabel);
      if (!foundBInClone) return false;

      const nodeBCopy = cloneNodes([foundBInClone.node])[0];

      if (!foundBInClone.parent) {
        // Remove from root
        const idx = newNodes.findIndex(
          (n) => n.label.toLowerCase() === nodeBLabel.toLowerCase()
        );
        if (idx >= 0) newNodes.splice(idx, 1);
      } else {
        const parent = findNodeByLabel(newNodes, foundBInClone.parent.label);
        if (parent && parent.node.children) {
          const idx = parent.node.children.findIndex(
            (c) => c.label.toLowerCase() === nodeBLabel.toLowerCase()
          );
          if (idx >= 0) parent.node.children.splice(idx, 1);
        }
      }

      // Now add nodeB under nodeA
      const foundAInClone = findNodeByLabel(newNodes, nodeALabel);
      if (foundAInClone) {
        if (!foundAInClone.node.children) foundAInClone.node.children = [];
        foundAInClone.node.children.push(nodeBCopy);
        updateNodes(newNodes);
        logger.info('[InteractiveMarkmap] Connected nodes', {
          nodeALabel,
          nodeBLabel,
        });
        return true;
      }

      return false;
    },
    [nodes, updateNodes]
  );

  const undo = useCallback((): boolean => {
    if (history.length === 0) return false;
    const prevState = history[history.length - 1];
    setHistory((h) => h.slice(0, -1));
    setNodesState(prevState);
    onNodesChange?.(prevState);
    logger.info('[InteractiveMarkmap] Undo performed');
    return true;
  }, [history, onNodesChange]);

  // ============================================================================
  // VIEW METHODS
  // ============================================================================

  const handleZoomIn = useCallback(() => {
    if (markmapRef.current) {
      markmapRef.current.rescale(1.25);
    }
    setZoom((z) => Math.min(z * 1.25, 3));
  }, []);

  const handleZoomOut = useCallback(() => {
    if (markmapRef.current) {
      markmapRef.current.rescale(0.8);
    }
    setZoom((z) => Math.max(z * 0.8, 0.5));
  }, []);

  const handleReset = useCallback(() => {
    if (markmapRef.current) {
      markmapRef.current.fit();
    }
    setZoom(1);
  }, []);

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

  // ============================================================================
  // IMPERATIVE HANDLE
  // ============================================================================

  useImperativeHandle(
    ref,
    () => ({
      addNode,
      expandNode,
      deleteNode,
      focusNode,
      setNodeColor,
      connectNodes,
      zoomIn: handleZoomIn,
      zoomOut: handleZoomOut,
      resetView: handleReset,
      toggleFullscreen: handleFullscreen,
      getNodes: () => cloneNodes(nodes),
      setNodes: (newNodes: MindmapNode[]) => {
        saveToHistory();
        setNodesState(cloneNodes(newNodes));
        onNodesChange?.(newNodes);
      },
      undo,
    }),
    [
      addNode,
      expandNode,
      deleteNode,
      focusNode,
      setNodeColor,
      connectNodes,
      handleZoomIn,
      handleZoomOut,
      handleReset,
      handleFullscreen,
      nodes,
      saveToHistory,
      onNodesChange,
      undo,
    ]
  );

  // ============================================================================
  // RENDER MINDMAP
  // ============================================================================

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

        // Get markdown from nodes
        const content = nodesToMarkdown(nodes, title);
        const { root } = transformer.transform(content);

        // Determine font family based on accessibility settings
        const fontFamily =
          settings.dyslexiaFont || accessibilityMode
            ? 'OpenDyslexic, Comic Sans MS, sans-serif'
            : 'Arial, Helvetica, sans-serif';

        // Determine colors based on accessibility settings
        const isHighContrast = settings.highContrast || accessibilityMode;

        // Create or update markmap
        if (markmapRef.current) {
          markmapRef.current.destroy();
        }

        markmapRef.current = Markmap.create(
          svgRef.current,
          {
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
                const colors = ['#ffff00', '#00ffff', '#ff00ff', '#00ff00', '#ff8000'];
                return colors[node.state?.depth % colors.length] || '#ffffff';
              }
              const colors = ['#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#ec4899'];
              return colors[node.state?.depth % colors.length] || '#64748b';
            },
          },
          root
        );

        // Apply custom styles after render
        setTimeout(() => {
          if (svgRef.current) {
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
                const r = parseFloat(circle.getAttribute('r') || '4');
                if (r < 6) {
                  circle.setAttribute('r', '6');
                }
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

            if (isHighContrast) {
              const rect = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
              rect.setAttribute('width', '100%');
              rect.setAttribute('height', '100%');
              rect.setAttribute('fill', '#000000');
              svgRef.current.insertBefore(rect, svgRef.current.firstChild);
            }
          }
        }, 100);

        svgRef.current.setAttribute('role', 'img');
        svgRef.current.setAttribute('aria-label', `Mappa mentale: ${title}`);

        setRendered(true);
      } catch (err) {
        const errorMsg = err instanceof Error ? err.message : String(err);
        setError(errorMsg);
        logger.error('InteractiveMarkMap render error', { error: String(err) });
      }
    };

    renderMindmap();
  }, [
    nodes,
    title,
    settings.dyslexiaFont,
    settings.highContrast,
    settings.largeText,
    accessibilityMode,
  ]);

  // Listen for fullscreen changes
  useEffect(() => {
    const handleFullscreenChange = () => {
      setIsFullscreen(!!document.fullscreenElement);
      if (markmapRef.current) {
        setTimeout(() => markmapRef.current?.fit(), 100);
      }
    };

    document.addEventListener('fullscreenchange', handleFullscreenChange);
    return () => document.removeEventListener('fullscreenchange', handleFullscreenChange);
  }, []);

  // ============================================================================
  // RENDER
  // ============================================================================

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
      aria-label={`Mappa mentale interattiva: ${title}`}
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
        <div className="flex items-center gap-2">
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
          {nodes.length > 0 && (
            <span className="text-xs text-slate-500 dark:text-slate-400">
              ({nodes.length} nodi)
            </span>
          )}
        </div>

        <div className="flex items-center gap-2">
          {/* Undo */}
          <button
            onClick={undo}
            disabled={history.length === 0}
            className={cn(
              'p-2 rounded-lg transition-colors',
              history.length === 0 && 'opacity-50 cursor-not-allowed',
              settings.highContrast
                ? 'bg-yellow-400 text-black hover:bg-yellow-300'
                : 'bg-slate-200 dark:bg-slate-700 hover:bg-slate-300 dark:hover:bg-slate-600'
            )}
            title="Annulla (Ctrl+Z)"
            aria-label="Annulla ultima modifica"
          >
            <Undo2 className="w-4 h-4" />
          </button>

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
            onClick={() => {
              // Simplified download for now
              const markdown = nodesToMarkdown(nodes, title);
              const blob = new Blob([markdown], { type: 'text/markdown' });
              const url = URL.createObjectURL(blob);
              const a = document.createElement('a');
              a.href = url;
              a.download = `mappa-mentale-${title.toLowerCase().replace(/\s+/g, '-')}.md`;
              a.click();
              URL.revokeObjectURL(url);
            }}
            className={cn(
              'p-2 rounded-lg transition-colors',
              settings.highContrast
                ? 'bg-yellow-400 text-black hover:bg-yellow-300'
                : 'bg-slate-200 dark:bg-slate-700 hover:bg-slate-300 dark:hover:bg-slate-600'
            )}
            title="Scarica Markdown"
            aria-label="Scarica mappa come Markdown"
          >
            <Download className="w-4 h-4" />
          </button>

          {/* Print */}
          <button
            onClick={() => window.print()}
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
          minHeight: isFullscreen ? 'calc(100vh - 60px)' : '400px',
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
                !rendered &&
                  (settings.highContrast ? 'bg-gray-800' : 'bg-slate-100 dark:bg-slate-700/50')
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
        {rendered && `Mappa mentale "${title}" renderizzata con ${nodes.length} nodi.`}
      </div>
    </motion.div>
  );
});

// Export types for external use
export type { MindmapNode };
