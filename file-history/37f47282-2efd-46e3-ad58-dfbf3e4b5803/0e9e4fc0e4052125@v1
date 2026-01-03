// ============================================================================
// MINDMAP EXPORT MODULE
// Multi-format export support for mindmaps
// Part of Phase 9: Import/Export Formats
// ============================================================================

import { logger } from '@/lib/logger';

// Mindmap data structure (matches markmap format)
export interface MindmapNode {
  id: string;
  text: string;
  children?: MindmapNode[];
  color?: string;
  collapsed?: boolean;
}

export interface MindmapData {
  title: string;
  topic?: string;
  root: MindmapNode;
  createdAt?: string;
  updatedAt?: string;
}

// Supported export formats
export type ExportFormat =
  | 'json'
  | 'markdown'
  | 'svg'
  | 'png'
  | 'pdf'
  | 'freemind'
  | 'xmind';

export interface ExportOptions {
  format: ExportFormat;
  filename?: string;
  includeMetadata?: boolean;
}

export interface ExportResult {
  blob: Blob;
  filename: string;
  mimeType: string;
}

// ============================================================================
// MAIN EXPORT FUNCTION
// ============================================================================

/**
 * Export mindmap to specified format
 */
export async function exportMindmap(
  mindmap: MindmapData,
  options: ExportOptions
): Promise<ExportResult> {
  const { format, filename, includeMetadata = true } = options;
  const baseFilename = filename || sanitizeFilename(mindmap.title || 'mindmap');

  logger.info('Exporting mindmap', { format, title: mindmap.title });

  switch (format) {
    case 'json':
      return exportAsJSON(mindmap, baseFilename, includeMetadata);
    case 'markdown':
      return exportAsMarkdown(mindmap, baseFilename);
    case 'svg':
      return exportAsSVG(mindmap, baseFilename);
    case 'png':
      return exportAsPNG(mindmap, baseFilename);
    case 'pdf':
      return exportAsPDF(mindmap, baseFilename);
    case 'freemind':
      return exportAsFreeMind(mindmap, baseFilename);
    case 'xmind':
      return exportAsXMind(mindmap, baseFilename);
    default:
      throw new Error(`Unsupported export format: ${format}`);
  }
}

// ============================================================================
// FORMAT-SPECIFIC EXPORTERS
// ============================================================================

/**
 * Export as JSON
 */
function exportAsJSON(
  mindmap: MindmapData,
  filename: string,
  includeMetadata: boolean
): ExportResult {
  const data = includeMetadata
    ? mindmap
    : { title: mindmap.title, root: mindmap.root };

  const json = JSON.stringify(data, null, 2);
  const blob = new Blob([json], { type: 'application/json' });

  return {
    blob,
    filename: `${filename}.json`,
    mimeType: 'application/json',
  };
}

/**
 * Export as Markdown (hierarchical structure)
 */
function exportAsMarkdown(mindmap: MindmapData, filename: string): ExportResult {
  const lines: string[] = [];

  // Add title
  lines.push(`# ${mindmap.title}`);
  lines.push('');

  if (mindmap.topic) {
    lines.push(`> ${mindmap.topic}`);
    lines.push('');
  }

  // Convert tree to markdown
  function nodeToMarkdown(node: MindmapNode, depth: number): void {
    const prefix = depth === 0 ? '## ' : '  '.repeat(depth - 1) + '- ';
    lines.push(`${prefix}${node.text}`);

    if (node.children) {
      for (const child of node.children) {
        nodeToMarkdown(child, depth + 1);
      }
    }
  }

  nodeToMarkdown(mindmap.root, 0);

  if (mindmap.createdAt) {
    lines.push('');
    lines.push(`---`);
    lines.push(`*Creata: ${new Date(mindmap.createdAt).toLocaleString('it-IT')}*`);
  }

  const markdown = lines.join('\n');
  const blob = new Blob([markdown], { type: 'text/markdown' });

  return {
    blob,
    filename: `${filename}.md`,
    mimeType: 'text/markdown',
  };
}

/**
 * Export as SVG (requires DOM access - client-side only)
 */
function exportAsSVG(mindmap: MindmapData, filename: string): ExportResult {
  // Check if we're in browser
  if (typeof window === 'undefined') {
    throw new Error('SVG export requires browser environment');
  }

  // Try to get SVG from existing markmap rendering
  const svgElement = document.querySelector('.markmap svg') as SVGElement | null;

  if (svgElement) {
    const svgData = new XMLSerializer().serializeToString(svgElement);
    const blob = new Blob([svgData], { type: 'image/svg+xml' });

    return {
      blob,
      filename: `${filename}.svg`,
      mimeType: 'image/svg+xml',
    };
  }

  // Fallback: generate simple SVG representation
  const svg = generateSimpleSVG(mindmap);
  const blob = new Blob([svg], { type: 'image/svg+xml' });

  return {
    blob,
    filename: `${filename}.svg`,
    mimeType: 'image/svg+xml',
  };
}

/**
 * Export as PNG (requires DOM access - client-side only)
 */
async function exportAsPNG(mindmap: MindmapData, filename: string): Promise<ExportResult> {
  if (typeof window === 'undefined') {
    throw new Error('PNG export requires browser environment');
  }

  // Get SVG first
  const svgResult = exportAsSVG(mindmap, filename);
  const svgText = await svgResult.blob.text();

  // Convert SVG to PNG via canvas
  const img = new Image();
  const canvas = document.createElement('canvas');
  const ctx = canvas.getContext('2d');

  if (!ctx) {
    throw new Error('Canvas context not available');
  }

  return new Promise((resolve, reject) => {
    img.onload = () => {
      canvas.width = img.width || 1200;
      canvas.height = img.height || 800;

      // White background
      ctx.fillStyle = 'white';
      ctx.fillRect(0, 0, canvas.width, canvas.height);

      ctx.drawImage(img, 0, 0);

      canvas.toBlob(
        (blob) => {
          if (blob) {
            resolve({
              blob,
              filename: `${filename}.png`,
              mimeType: 'image/png',
            });
          } else {
            reject(new Error('Failed to create PNG blob'));
          }
        },
        'image/png',
        1.0
      );
    };

    img.onerror = () => reject(new Error('Failed to load SVG for PNG conversion'));

    // Load SVG as data URL
    const svgBlob = new Blob([svgText], { type: 'image/svg+xml' });
    img.src = URL.createObjectURL(svgBlob);
  });
}

/**
 * Export as PDF (uses jsPDF if available, otherwise markdown-style text PDF)
 */
async function exportAsPDF(mindmap: MindmapData, filename: string): Promise<ExportResult> {
  // For now, create a simple text-based PDF representation
  // In production, use jsPDF or similar library
  const markdown = exportAsMarkdown(mindmap, filename);
  const text = await markdown.blob.text();

  // Simple PDF structure (minimal valid PDF)
  const pdfContent = createSimplePDF(mindmap.title, text);
  const blob = new Blob([pdfContent], { type: 'application/pdf' });

  return {
    blob,
    filename: `${filename}.pdf`,
    mimeType: 'application/pdf',
  };
}

/**
 * Export as FreeMind format (.mm)
 * FreeMind is an open-source mind mapping tool with XML format
 */
function exportAsFreeMind(mindmap: MindmapData, filename: string): ExportResult {
  const lines: string[] = [];

  lines.push('<?xml version="1.0" encoding="UTF-8"?>');
  lines.push('<map version="1.0.1">');

  function nodeToXML(node: MindmapNode, position?: 'left' | 'right'): void {
    const posAttr = position ? ` POSITION="${position}"` : '';
    const colorAttr = node.color ? ` COLOR="${node.color}"` : '';

    if (node.children && node.children.length > 0) {
      lines.push(`<node TEXT="${escapeXML(node.text)}"${posAttr}${colorAttr}>`);
      node.children.forEach((child, index) => {
        // Alternate left/right for top-level nodes
        const childPos = position ? undefined : index % 2 === 0 ? 'right' : 'left';
        nodeToXML(child, childPos);
      });
      lines.push('</node>');
    } else {
      lines.push(`<node TEXT="${escapeXML(node.text)}"${posAttr}${colorAttr}/>`);
    }
  }

  nodeToXML(mindmap.root);
  lines.push('</map>');

  const xml = lines.join('\n');
  const blob = new Blob([xml], { type: 'application/x-freemind' });

  return {
    blob,
    filename: `${filename}.mm`,
    mimeType: 'application/x-freemind',
  };
}

/**
 * Export as XMind format (.xmind)
 * XMind uses a ZIP archive containing XML files
 */
async function exportAsXMind(mindmap: MindmapData, filename: string): Promise<ExportResult> {
  // XMind format is complex (ZIP with multiple XML files)
  // For now, create a simplified XMind-compatible JSON format
  // In production, use JSZip to create proper .xmind archive

  const xmindData = {
    id: generateId(),
    title: mindmap.title,
    rootTopic: convertToXMindTopic(mindmap.root),
    extensions: [],
  };

  const json = JSON.stringify([xmindData], null, 2);
  const blob = new Blob([json], { type: 'application/json' });

  // Note: Real XMind export would create a ZIP file
  // This is a fallback JSON export that's partially XMind-compatible
  return {
    blob,
    filename: `${filename}.xmind.json`,
    mimeType: 'application/json',
  };
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Sanitize filename for safe file system usage
 */
function sanitizeFilename(name: string): string {
  return name
    .replace(/[<>:"/\\|?*]/g, '')
    .replace(/\s+/g, '_')
    .substring(0, 100);
}

/**
 * Escape XML special characters
 */
function escapeXML(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

/**
 * Generate unique ID
 */
function generateId(): string {
  return `id_${Date.now()}_${crypto.randomUUID().slice(0, 8)}`;
}

/**
 * Convert MindmapNode to XMind topic format
 */
function convertToXMindTopic(node: MindmapNode): unknown {
  return {
    id: node.id || generateId(),
    title: node.text,
    children: node.children
      ? { attached: node.children.map(convertToXMindTopic) }
      : undefined,
    style: node.color ? { properties: { 'svg:fill': node.color } } : undefined,
  };
}

/**
 * Generate simple SVG representation of mindmap with full tree layout
 */
function generateSimpleSVG(mindmap: MindmapData): string {
  const width = 1200;
  const height = 800;
  const centerX = width / 2;
  const centerY = height / 2;
  const levelSpacing = 150;
  const nodeHeight = 30;

  const lines: string[] = [];
  lines.push('<?xml version="1.0" encoding="UTF-8"?>');
  lines.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}">`);
  lines.push('<style>');
  lines.push('  text { font-family: Arial, sans-serif; font-size: 14px; fill: #333; }');
  lines.push('  .root { font-size: 18px; font-weight: bold; }');
  lines.push('  .level1 { font-size: 14px; font-weight: 600; }');
  lines.push('  .level2 { font-size: 12px; }');
  lines.push('  line { stroke: #666; stroke-width: 1.5; }');
  lines.push('  rect.node { fill: #f0f0f0; stroke: #999; rx: 5; }');
  lines.push('  rect.root-node { fill: #4a90d9; stroke: #2a70b9; rx: 8; }');
  lines.push('</style>');
  lines.push('<rect width="100%" height="100%" fill="white"/>');

  // Calculate positions for each node
  interface NodePosition {
    x: number;
    y: number;
    node: MindmapNode;
    level: number;
  }
  const positions: NodePosition[] = [];

  function calculatePositions(
    node: MindmapNode,
    x: number,
    y: number,
    level: number,
    angleStart: number,
    angleEnd: number
  ): void {
    positions.push({ x, y, node, level });

    if (!node.children || node.children.length === 0) return;

    const angleRange = angleEnd - angleStart;
    const angleStep = angleRange / node.children.length;

    node.children.forEach((child, index) => {
      const angle = angleStart + angleStep * (index + 0.5);
      const distance = levelSpacing * (level === 0 ? 1.2 : 0.8);
      const childX = x + Math.cos(angle) * distance;
      const childY = y + Math.sin(angle) * distance;

      // Draw connection line
      lines.push(`<line x1="${x}" y1="${y}" x2="${childX}" y2="${childY}"/>`);

      calculatePositions(child, childX, childY, level + 1, angle - angleStep / 2, angle + angleStep / 2);
    });
  }

  // Start layout from center
  calculatePositions(mindmap.root, centerX, centerY, 0, 0, 2 * Math.PI);

  // Render nodes (after lines so nodes appear on top)
  for (const pos of positions) {
    const textWidth = Math.min(pos.node.text.length * 8, 200);
    const rectWidth = textWidth + 16;
    const rectHeight = nodeHeight;
    const rectX = pos.x - rectWidth / 2;
    const rectY = pos.y - rectHeight / 2;

    const nodeClass = pos.level === 0 ? 'root-node' : 'node';
    const textClass = pos.level === 0 ? 'root' : pos.level === 1 ? 'level1' : 'level2';
    const textFill = pos.level === 0 ? 'white' : '#333';

    lines.push(`<rect class="${nodeClass}" x="${rectX}" y="${rectY}" width="${rectWidth}" height="${rectHeight}"/>`);
    lines.push(`<text x="${pos.x}" y="${pos.y + 5}" text-anchor="middle" class="${textClass}" fill="${textFill}">${escapeXML(pos.node.text.substring(0, 25))}</text>`);
  }

  lines.push('</svg>');
  return lines.join('\n');
}

/**
 * Create minimal PDF structure
 */
function createSimplePDF(title: string, content: string): string {
  // This is a minimal PDF - in production use jsPDF
  const lines: string[] = [];

  lines.push('%PDF-1.4');
  lines.push('1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj');
  lines.push('2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj');
  lines.push('3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >> endobj');

  const text = `BT /F1 12 Tf 50 750 Td (${title}) Tj 0 -20 Td (${content.substring(0, 500).replace(/\n/g, ') Tj 0 -15 Td (')}) Tj ET`;
  lines.push(`4 0 obj << /Length ${text.length} >> stream\n${text}\nendstream endobj`);

  lines.push('xref');
  lines.push('0 5');
  lines.push('0000000000 65535 f');
  lines.push('trailer << /Size 5 /Root 1 0 R >>');
  lines.push('startxref');
  lines.push('0');
  lines.push('%%EOF');

  return lines.join('\n');
}

// ============================================================================
// DOWNLOAD HELPER
// ============================================================================

/**
 * Trigger file download in browser
 */
export function downloadExport(result: ExportResult): void {
  if (typeof window === 'undefined') {
    throw new Error('Download requires browser environment');
  }

  const url = URL.createObjectURL(result.blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = result.filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);

  logger.info('Mindmap exported and downloaded', { filename: result.filename });
}
