#!/usr/bin/env node

/**
 * Generate Lean Agent Variants
 *
 * Strips Security & Ethics Framework sections from agents to reduce context usage.
 * Creates lean versions in .claude/agents-lean/ directory.
 *
 * Reduction: ~15-20% per agent (removes ~30-50 lines of boilerplate)
 */

const fs = require('fs');
const path = require('path');

const AGENTS_SRC = path.join(__dirname, '..', '.claude', 'agents');
const AGENTS_LEAN = path.join(__dirname, '..', '.claude', 'agents-lean');

// Colors for terminal output
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  red: '\x1b[31m',
};

function log(color, message) {
  console.log(`${color}${message}${colors.reset}`);
}

/**
 * Strip Security & Ethics Framework section from agent content
 */
function stripSecurityFramework(content) {
  let result = content;

  // Remove Copyright notice (HTML comment)
  result = result.replace(/<!--\s*\nCopyright.*?-->/gs, '');

  // Remove Security & Ethics Framework section
  // Pattern: ## Security & Ethics Framework ... ## Core Identity (or ## Core Competencies)
  result = result.replace(
    /## Security & Ethics Framework[\s\S]*?(?=## Core Identity|## Core Competencies|## Operating Mode)/,
    ''
  );

  // Remove Example line from description in frontmatter
  result = result.replace(
    /(description:.*?)\n\s*Example:.*?\n/s,
    '$1\n'
  );

  // Clean up multiple consecutive blank lines
  result = result.replace(/\n{3,}/g, '\n\n');

  return result;
}

/**
 * Process a single agent file
 */
function processAgent(srcPath, destPath) {
  const content = fs.readFileSync(srcPath, 'utf8');
  const leanContent = stripSecurityFramework(content);

  // Ensure destination directory exists
  fs.mkdirSync(path.dirname(destPath), { recursive: true });

  // Write lean version
  fs.writeFileSync(destPath, leanContent);

  // Calculate reduction
  const originalSize = Buffer.byteLength(content, 'utf8');
  const leanSize = Buffer.byteLength(leanContent, 'utf8');
  const reduction = ((originalSize - leanSize) / originalSize * 100).toFixed(1);

  return { originalSize, leanSize, reduction };
}

/**
 * Process all agents recursively
 */
function processDirectory(srcDir, destDir, stats = { total: 0, processed: 0, totalReduction: 0 }) {
  if (!fs.existsSync(srcDir)) {
    return stats;
  }

  const items = fs.readdirSync(srcDir);

  for (const item of items) {
    const srcPath = path.join(srcDir, item);
    const destPath = path.join(destDir, item);
    const stat = fs.statSync(srcPath);

    if (stat.isDirectory()) {
      processDirectory(srcPath, destPath, stats);
    } else if (item.endsWith('.md') && !item.includes('.lean.')) {
      // Skip template files and already lean files
      if (['CONSTITUTION.md', 'CommonValuesAndPrinciples.md', 'SECURITY_FRAMEWORK_TEMPLATE.md', 'MICROSOFT_VALUES.md'].includes(item)) {
        // Copy these as-is
        fs.mkdirSync(path.dirname(destPath), { recursive: true });
        fs.copyFileSync(srcPath, destPath);
        continue;
      }

      stats.total++;
      const result = processAgent(srcPath, destPath);
      stats.processed++;
      stats.totalReduction += parseFloat(result.reduction);

      const relPath = path.relative(AGENTS_SRC, srcPath);
      console.log(`  ${relPath.padEnd(60)} ${result.reduction}% reduction`);
    }
  }

  return stats;
}

function main() {
  log(colors.blue, '\nGenerating Lean Agent Variants\n');
  log(colors.blue, '================================\n');

  // Clean existing lean directory
  if (fs.existsSync(AGENTS_LEAN)) {
    fs.rmSync(AGENTS_LEAN, { recursive: true });
  }
  fs.mkdirSync(AGENTS_LEAN, { recursive: true });

  // Process all agents
  const stats = processDirectory(AGENTS_SRC, AGENTS_LEAN);

  console.log('');
  log(colors.green, `\nProcessed ${stats.processed}/${stats.total} agents`);
  log(colors.green, `Average reduction: ${(stats.totalReduction / stats.processed).toFixed(1)}%`);
  log(colors.yellow, `\nLean agents saved to: ${AGENTS_LEAN}`);

  // Calculate total size reduction
  const srcSize = getDirSize(AGENTS_SRC);
  const leanSize = getDirSize(AGENTS_LEAN);
  const totalReduction = ((srcSize - leanSize) / srcSize * 100).toFixed(1);

  log(colors.blue, `\nTotal size: ${(srcSize / 1024).toFixed(1)}KB → ${(leanSize / 1024).toFixed(1)}KB (${totalReduction}% reduction)`);
}

function getDirSize(dir) {
  let size = 0;
  const items = fs.readdirSync(dir);
  for (const item of items) {
    const fullPath = path.join(dir, item);
    const stat = fs.statSync(fullPath);
    if (stat.isDirectory()) {
      size += getDirSize(fullPath);
    } else {
      size += stat.size;
    }
  }
  return size;
}

main();
