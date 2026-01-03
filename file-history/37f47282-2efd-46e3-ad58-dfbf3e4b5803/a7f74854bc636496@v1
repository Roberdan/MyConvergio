// ============================================================================
// STUDY KIT HANDLER
// Process PDF and generate study materials (summary, mindmap, demo, quiz)
// Wave 2: Auto-generate study kit from PDF upload
// ============================================================================

import { PDFParse } from 'pdf-parse';
import { chatCompletion } from '@/lib/ai/providers';
import { logger } from '@/lib/logger';
import type { MindmapData, QuizData, DemoData } from '@/types/tools';
import type { StudyKit } from '@/types/study-kit';

/**
 * Extract text from PDF buffer using pdf-parse v2 API
 * C-18 FIX: Improved error handling and logging
 */
export async function extractTextFromPDF(buffer: Buffer): Promise<{ text: string; pageCount: number }> {
  let parser: PDFParse | null = null;
  try {
    // Validate input
    if (!buffer || buffer.length === 0) {
      throw new Error('Empty or invalid PDF buffer');
    }

    logger.debug('Starting PDF extraction', { bufferSize: buffer.length });

    // Convert Buffer to Uint8Array for pdf-parse v2
    const data = new Uint8Array(buffer);

    // Create parser with Node.js-optimized settings
    parser = new PDFParse({
      data,
      // Disable features not needed for text extraction
      disableFontFace: true,
      isOffscreenCanvasSupported: false,
    });

    // Extract text first
    const textResult = await parser.getText();
    logger.debug('Text extraction complete', { textLength: textResult.text.length });

    // Get document info for page count
    const infoResult = await parser.getInfo();
    logger.debug('Info extraction complete', { pageCount: infoResult.total });

    return {
      text: textResult.text,
      pageCount: infoResult.total,
    };
  } catch (error) {
    // C-18 FIX: Preserve actual error message for debugging
    const errorMessage = error instanceof Error ? error.message : String(error);
    const errorStack = error instanceof Error ? error.stack : undefined;

    logger.error('Failed to extract text from PDF', {
      error: errorMessage,
      stack: errorStack,
      bufferSize: buffer?.length,
    });

    // Re-throw with actual error message for better debugging
    throw new Error(`Failed to parse PDF: ${errorMessage}`);
  } finally {
    if (parser) {
      try {
        await parser.destroy();
      } catch (destroyError) {
        logger.warn('Error destroying PDF parser', { error: String(destroyError) });
      }
    }
  }
}

/**
 * Generate summary from text using AI
 */
export async function generateSummary(text: string, title: string, subject?: string): Promise<string> {
  const prompt = `Sei un tutor educativo. Crea un riassunto chiaro e strutturato del seguente documento.

Titolo: ${title}
${subject ? `Materia: ${subject}` : ''}

DOCUMENTO:
${text.substring(0, 8000)} ${text.length > 8000 ? '...' : ''}

Crea un riassunto in italiano di massimo 500 parole che:
- Identifica i concetti chiave
- Organizza le informazioni in modo logico
- Usa un linguaggio chiaro e accessibile
- È adatto per studenti con DSA/ADHD`;

  const result = await chatCompletion(
    [{ role: 'user', content: prompt }],
    'Sei un tutor educativo esperto in didattica inclusiva per studenti con DSA e ADHD.',
    { temperature: 0.7, maxTokens: 2000 }
  );

  return result.content.trim();
}

/**
 * Generate mindmap from text using AI
 */
export async function generateMindmap(text: string, title: string, subject?: string): Promise<MindmapData> {
  const prompt = `Sei un tutor educativo. Crea una mappa mentale ben strutturata del seguente documento.

Titolo: ${title}
${subject ? `Materia: ${subject}` : ''}

DOCUMENTO:
${text.substring(0, 8000)} ${text.length > 8000 ? '...' : ''}

Crea una mappa mentale con:
- 4-6 rami principali (concetti chiave)
- 2-4 sotto-concetti per ogni ramo
- Etichette brevi e chiare (max 5 parole)

Rispondi SOLO con un JSON valido in questo formato:
{
  "title": "Titolo della mappa",
  "nodes": [
    {"id": "1", "label": "Ramo 1"},
    {"id": "1a", "label": "Sotto-concetto 1", "parentId": "1"},
    {"id": "1b", "label": "Sotto-concetto 2", "parentId": "1"}
  ]
}`;

  const result = await chatCompletion(
    [{ role: 'user', content: prompt }],
    'Sei un tutor educativo. Rispondi SOLO con JSON valido, senza testo aggiuntivo.',
    { temperature: 0.7, maxTokens: 1500 }
  );

  // Parse JSON response
  const jsonMatch = result.content.match(/\{[\s\S]*\}/);
  if (!jsonMatch) {
    throw new Error('Failed to parse mindmap JSON');
  }

  const mindmapData = JSON.parse(jsonMatch[0]);

  // Validate structure
  if (!mindmapData.title || !Array.isArray(mindmapData.nodes)) {
    throw new Error('Invalid mindmap structure');
  }

  return {
    title: String(mindmapData.title),
    nodes: (mindmapData.nodes as Array<{ id: string | number; label: string; parentId?: string | number }>).map((n) => ({
      id: String(n.id),
      label: String(n.label),
      parentId: n.parentId ? String(n.parentId) : null,
    })),
  };
}

/**
 * Generate interactive demo from text using AI
 */
export async function generateDemo(text: string, title: string, subject?: string): Promise<DemoData | null> {
  // Only generate demo for STEM subjects
  const stemSubjects = ['matematica', 'fisica', 'chimica', 'biologia', 'scienze', 'informatica', 'mathematics', 'physics', 'chemistry', 'biology', 'science', 'computer'];
  const isSTEM = subject && stemSubjects.some(s => subject.toLowerCase().includes(s));

  if (!isSTEM) {
    logger.info('Skipping demo generation for non-STEM subject', { subject });
    return null;
  }

  const prompt = `Sei un tutor educativo. Crea una dimostrazione interattiva HTML/CSS/JS per questo argomento.

Titolo: ${title}
Materia: ${subject}

DOCUMENTO:
${text.substring(0, 6000)} ${text.length > 6000 ? '...' : ''}

Crea una demo interattiva che visualizza un concetto chiave. Usa HTML semplice, CSS per lo stile, e JavaScript vanilla per l'interattività.

IMPORTANTE:
- NON usare librerie esterne
- Crea controlli interattivi (slider, bottoni)
- Usa canvas o SVG per visualizzazioni
- Codice sicuro (no fetch, no localStorage)

Rispondi SOLO con JSON in questo formato:
{
  "title": "Titolo demo",
  "description": "Breve descrizione",
  "html": "<div>...</div>",
  "css": "/* styles */",
  "js": "// javascript"
}`;

  const result = await chatCompletion(
    [{ role: 'user', content: prompt }],
    'Sei un tutor educativo. Rispondi SOLO con JSON valido.',
    { temperature: 0.7, maxTokens: 2000 }
  );

  // Parse JSON response
  const jsonMatch = result.content.match(/\{[\s\S]*\}/);
  if (!jsonMatch) {
    logger.warn('Failed to parse demo JSON');
    return null;
  }

  try {
    const demoData = JSON.parse(jsonMatch[0]);
    return {
      title: demoData.title || title,
      description: demoData.description,
      html: demoData.html || '',
      css: demoData.css || '',
      js: demoData.js || '',
    };
  } catch (error) {
    logger.error('Failed to parse demo JSON', { error });
    return null;
  }
}

/**
 * Generate quiz from text using AI
 */
export async function generateQuiz(text: string, title: string, subject?: string): Promise<QuizData> {
  const prompt = `Sei un tutor educativo. Crea un quiz con 5 domande a risposta multipla sul seguente documento.

Titolo: ${title}
${subject ? `Materia: ${subject}` : ''}

DOCUMENTO:
${text.substring(0, 8000)} ${text.length > 8000 ? '...' : ''}

Crea 5 domande con:
- 4 opzioni ciascuna
- Una sola risposta corretta
- Spiegazione della risposta corretta
- Difficoltà crescente

Rispondi SOLO con JSON valido:
{
  "topic": "Argomento del quiz",
  "questions": [
    {
      "question": "Testo domanda?",
      "options": ["A", "B", "C", "D"],
      "correctIndex": 0,
      "explanation": "Spiegazione"
    }
  ]
}`;

  const result = await chatCompletion(
    [{ role: 'user', content: prompt }],
    'Sei un tutor educativo. Rispondi SOLO con JSON valido.',
    { temperature: 0.7, maxTokens: 2000 }
  );

  // Parse JSON response
  const jsonMatch = result.content.match(/\{[\s\S]*\}/);
  if (!jsonMatch) {
    throw new Error('Failed to parse quiz JSON');
  }

  const quizData = JSON.parse(jsonMatch[0]);

  // Validate structure
  if (!quizData.topic || !Array.isArray(quizData.questions)) {
    throw new Error('Invalid quiz structure');
  }

  return {
    topic: String(quizData.topic),
    questions: (quizData.questions as Array<{
      question: string;
      options: string[];
      correctIndex: number;
      explanation?: string;
    }>).map((q) => ({
      question: String(q.question),
      options: q.options.map((o) => String(o)),
      correctIndex: Number(q.correctIndex),
      explanation: q.explanation ? String(q.explanation) : undefined,
    })),
  };
}

/**
 * Process PDF and generate complete study kit
 */
export async function processStudyKit(
  pdfBuffer: Buffer,
  title: string,
  subject?: string,
  onProgress?: (step: string, progress: number) => void
): Promise<Omit<StudyKit, 'id' | 'userId' | 'createdAt' | 'updatedAt'>> {
  try {
    // Step 1: Extract text from PDF
    onProgress?.('parsing', 0.1);
    const { text, pageCount } = await extractTextFromPDF(pdfBuffer);
    const wordCount = text.split(/\s+/).length;

    logger.info('Extracted PDF text', { pageCount, wordCount });

    // Step 2: Generate summary
    onProgress?.('generating_summary', 0.25);
    const summary = await generateSummary(text, title, subject);
    logger.info('Generated summary');

    // Step 3: Generate mindmap
    onProgress?.('generating_mindmap', 0.45);
    const mindmap = await generateMindmap(text, title, subject);
    logger.info('Generated mindmap');

    // Step 4: Generate demo (optional for STEM)
    onProgress?.('generating_demo', 0.65);
    const demo = await generateDemo(text, title, subject);
    if (demo) {
      logger.info('Generated demo');
    }

    // Step 5: Generate quiz
    onProgress?.('generating_quiz', 0.85);
    const quiz = await generateQuiz(text, title, subject);
    logger.info('Generated quiz');

    onProgress?.('complete', 1.0);

    return {
      sourceFile: 'uploaded.pdf',
      title,
      summary,
      mindmap,
      demo: demo || undefined,
      quiz,
      status: 'ready',
      subject,
      pageCount,
      wordCount,
    };
  } catch (error) {
    logger.error('Failed to process study kit', { error });
    throw error;
  }
}
