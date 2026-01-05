#!/usr/bin/env node

/**
 * MyConvergio Conflict Resolver
 *
 * Interactive conflict resolution for installation
 */

const fs = require('fs');
const path = require('path');
const readline = require('readline');
const crypto = require('crypto');

const { getFileSHA256 } = require('./backup-manager');

// Detect all conflicts between source and target directories
function detectConflicts(sourceDir, targetDir, relativePath = '') {
  const conflicts = [];

  if (!fs.existsSync(sourceDir)) return conflicts;
  if (!fs.existsSync(targetDir)) return conflicts;

  const items = fs.readdirSync(sourceDir);

  for (const item of items) {
    const srcPath = path.join(sourceDir, item);
    const tgtPath = path.join(targetDir, item);
    const relPath = path.join(relativePath, item);
    const stat = fs.statSync(srcPath);

    if (stat.isDirectory()) {
      // Recurse into directories
      const subConflicts = detectConflicts(srcPath, tgtPath, relPath);
      conflicts.push(...subConflicts);
    } else {
      // Check if file exists in target
      if (fs.existsSync(tgtPath)) {
        const srcHash = getFileSHA256(srcPath);
        const tgtHash = getFileSHA256(tgtPath);

        // Only conflict if files are different
        if (srcHash !== tgtHash) {
          const srcSize = fs.statSync(srcPath).size;
          const tgtSize = fs.statSync(tgtPath).size;

          conflicts.push({
            file: relPath,
            sourcePath: srcPath,
            targetPath: tgtPath,
            sourceHash: srcHash,
            targetHash: tgtHash,
            sourceSize: srcSize,
            targetSize: tgtSize,
            action: null // Will be set during resolution
          });
        }
      }
    }
  }

  return conflicts;
}

// Show summary of conflicts
function showConflictSummary(conflicts) {
  console.log('\n╔════════════════════════════════════════════════════════════╗');
  console.log('║              CONFLICT DETECTION RESULTS                    ║');
  console.log('╚════════════════════════════════════════════════════════════╝\n');

  if (conflicts.length === 0) {
    console.log('✅ No conflicts detected. All files are either new or unchanged.\n');
    return;
  }

  console.log(`⚠️  Found ${conflicts.length} conflicting file(s):\n`);

  for (let i = 0; i < conflicts.length; i++) {
    const c = conflicts[i];
    const sizeChange = c.sourceSize - c.targetSize;
    const sizeStr = sizeChange > 0
      ? `+${sizeChange} bytes`
      : sizeChange < 0
      ? `${sizeChange} bytes`
      : 'same size';

    console.log(`  ${i + 1}. ${c.file}`);
    console.log(`     Your file:  ${c.targetHash} (${c.targetSize} bytes)`);
    console.log(`     Our file:   ${c.sourceHash} (${c.sourceSize} bytes) [${sizeStr}]`);
    console.log('');
  }
}

// Show diff between two files (simplified text diff)
function showFileDiff(conflict) {
  const yourContent = fs.readFileSync(conflict.targetPath, 'utf8');
  const ourContent = fs.readFileSync(conflict.sourcePath, 'utf8');

  console.log('\n─────────────────────────────────────────────────────────────');
  console.log(`FILE: ${conflict.file}`);
  console.log('─────────────────────────────────────────────────────────────\n');

  // Simple line-by-line comparison (first 20 lines max)
  const yourLines = yourContent.split('\n').slice(0, 20);
  const ourLines = ourContent.split('\n').slice(0, 20);
  const maxLines = Math.max(yourLines.length, ourLines.length);

  console.log('YOUR VERSION              |  OUR VERSION');
  console.log('──────────────────────────┼──────────────────────────────');

  for (let i = 0; i < Math.min(maxLines, 10); i++) {
    const yourLine = (yourLines[i] || '').substring(0, 25).padEnd(25);
    const ourLine = (ourLines[i] || '').substring(0, 25);
    const marker = yourLines[i] !== ourLines[i] ? '│*' : '│ ';
    console.log(`${yourLine} ${marker} ${ourLine}`);
  }

  if (maxLines > 10) {
    console.log(`... (${maxLines - 10} more lines) ...`);
  }

  console.log('\n');
}

// Interactive resolution for a single conflict
async function resolveConflictInteractive(conflict, rl) {
  console.log('\n═══════════════════════════════════════════════════════════════');
  console.log(`  CONFLICT: ${conflict.file}`);
  console.log('═══════════════════════════════════════════════════════════════');

  showFileDiff(conflict);

  console.log('Choose an action:');
  console.log('  [k] Keep yours    - Keep your existing file');
  console.log('  [u] Use ours      - Replace with MyConvergio version');
  console.log('  [d] Show diff     - Show detailed comparison');
  console.log('  [s] Skip          - Skip this file for now');
  console.log('  [a] Accept all    - Use MyConvergio for ALL remaining conflicts');
  console.log('  [K] Keep all      - Keep yours for ALL remaining conflicts');
  console.log('');

  return new Promise((resolve) => {
    rl.question('Your choice [k/u/d/s/a/K]: ', (answer) => {
      resolve(answer.toLowerCase().trim());
    });
  });
}

// Resolve all conflicts with specified mode
async function resolveConflicts(conflicts, mode = 'interactive') {
  if (conflicts.length === 0) {
    return { resolved: [], skipped: [] };
  }

  const resolved = [];
  const skipped = [];

  if (mode === 'accept-all') {
    // Accept all MyConvergio versions
    for (const conflict of conflicts) {
      conflict.action = 'use-ours';
      resolved.push(conflict);
    }
    return { resolved, skipped };
  }

  if (mode === 'keep-all') {
    // Keep all existing versions
    for (const conflict of conflicts) {
      conflict.action = 'keep-yours';
      resolved.push(conflict);
    }
    return { resolved, skipped };
  }

  // Interactive mode
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  let autoMode = null; // Will be set to 'accept-all' or 'keep-all' if user chooses

  for (const conflict of conflicts) {
    if (autoMode === 'accept-all') {
      conflict.action = 'use-ours';
      resolved.push(conflict);
      continue;
    }

    if (autoMode === 'keep-all') {
      conflict.action = 'keep-yours';
      resolved.push(conflict);
      continue;
    }

    let choice = await resolveConflictInteractive(conflict, rl);

    while (choice === 'd') {
      // Show diff again
      showFileDiff(conflict);
      choice = await resolveConflictInteractive(conflict, rl);
    }

    switch (choice) {
      case 'k':
        conflict.action = 'keep-yours';
        resolved.push(conflict);
        break;
      case 'u':
        conflict.action = 'use-ours';
        resolved.push(conflict);
        break;
      case 's':
        conflict.action = 'skip';
        skipped.push(conflict);
        break;
      case 'a':
        conflict.action = 'use-ours';
        resolved.push(conflict);
        autoMode = 'accept-all';
        console.log('\n✓ Auto-accepting all remaining conflicts with MyConvergio version\n');
        break;
      case 'K':
        conflict.action = 'keep-yours';
        resolved.push(conflict);
        autoMode = 'keep-all';
        console.log('\n✓ Auto-keeping all remaining conflicts with your version\n');
        break;
      default:
        console.log('\nInvalid choice. Skipping this file.\n');
        conflict.action = 'skip';
        skipped.push(conflict);
    }
  }

  rl.close();

  return { resolved, skipped };
}

// Show resolution summary
function showResolutionSummary(resolved, skipped) {
  console.log('\n╔════════════════════════════════════════════════════════════╗');
  console.log('║              CONFLICT RESOLUTION SUMMARY                   ║');
  console.log('╚════════════════════════════════════════════════════════════╝\n');

  const useOurs = resolved.filter(c => c.action === 'use-ours');
  const keepYours = resolved.filter(c => c.action === 'keep-yours');

  console.log(`Files to replace with MyConvergio version: ${useOurs.length}`);
  if (useOurs.length > 0) {
    useOurs.forEach(c => console.log(`  ✓ ${c.file}`));
  }
  console.log('');

  console.log(`Files to keep (your version): ${keepYours.length}`);
  if (keepYours.length > 0) {
    keepYours.forEach(c => console.log(`  ✓ ${c.file}`));
  }
  console.log('');

  if (skipped.length > 0) {
    console.log(`Files skipped: ${skipped.length}`);
    skipped.forEach(c => console.log(`  - ${c.file}`));
    console.log('');
  }
}

// Apply resolution actions (copy files as decided)
function applyResolutions(resolved) {
  const results = { success: [], failed: [] };

  for (const conflict of resolved) {
    try {
      if (conflict.action === 'use-ours') {
        // Copy source to target
        fs.copyFileSync(conflict.sourcePath, conflict.targetPath);
        results.success.push(conflict.file);
      } else if (conflict.action === 'keep-yours') {
        // Do nothing - keep existing file
        results.success.push(conflict.file);
      }
    } catch (err) {
      results.failed.push({ file: conflict.file, error: err.message });
    }
  }

  return results;
}

module.exports = {
  detectConflicts,
  showConflictSummary,
  showFileDiff,
  resolveConflicts,
  showResolutionSummary,
  applyResolutions
};
