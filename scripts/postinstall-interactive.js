#!/usr/bin/env node

/**
 * MyConvergio Interactive Installation
 *
 * Safe, interactive installation with conflict detection and backup
 * Usage: node postinstall-interactive.js [--accept-all|--keep-all|--skip-conflicts]
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

const backupManager = require('./backup-manager');
const conflictResolver = require('./conflict-resolver');

const CLAUDE_HOME = path.join(os.homedir(), '.claude');
const PACKAGE_ROOT = path.join(__dirname, '..');

// Parse CLI flags
const args = process.argv.slice(2);
const mode = args.includes('--accept-all')
  ? 'accept-all'
  : args.includes('--keep-all')
  ? 'keep-all'
  : args.includes('--skip-conflicts')
  ? 'skip-conflicts'
  : 'interactive';

// Directory and file mapping
const INSTALL_MAP = {
  dirs: [
    { src: '.claude/agents', dest: 'agents' },
    { src: '.claude/rules', dest: 'rules' },
    { src: '.claude/skills', dest: 'skills' },
    { src: '.claude/templates', dest: 'templates' },
    { src: '.claude/scripts', dest: 'scripts' }
  ],
  files: [
    { src: '.claude/CLAUDE.md', dest: 'CLAUDE.md' }
  ]
};

// Copy directory recursively, collecting installed files
function copyRecursive(src, dest, installedFiles = []) {
  if (!fs.existsSync(src)) return;

  fs.mkdirSync(dest, { recursive: true });

  const items = fs.readdirSync(src);
  for (const item of items) {
    const srcPath = path.join(src, item);
    const destPath = path.join(dest, item);
    const stat = fs.statSync(srcPath);

    if (stat.isDirectory()) {
      copyRecursive(srcPath, destPath, installedFiles);
    } else {
      fs.copyFileSync(srcPath, destPath);
      installedFiles.push(destPath);
    }
  }
}

// Collect all files that would be installed
function collectInstallationFiles() {
  const files = { new: [], conflicts: [] };

  // Collect directory files
  for (const dirMap of INSTALL_MAP.dirs) {
    const srcDir = path.join(PACKAGE_ROOT, dirMap.src);
    const destDir = path.join(CLAUDE_HOME, dirMap.dest);

    if (fs.existsSync(srcDir)) {
      const conflicts = conflictResolver.detectConflicts(srcDir, destDir, dirMap.dest);
      files.conflicts.push(...conflicts);

      // Also track new files (files that don't exist in target)
      const newFiles = findNewFiles(srcDir, destDir, dirMap.dest);
      files.new.push(...newFiles);
    }
  }

  // Collect individual files
  for (const fileMap of INSTALL_MAP.files) {
    const srcFile = path.join(PACKAGE_ROOT, fileMap.src);
    const destFile = path.join(CLAUDE_HOME, fileMap.dest);

    if (fs.existsSync(srcFile)) {
      if (fs.existsSync(destFile)) {
        // Potential conflict
        const srcHash = backupManager.getFileSHA256(srcFile);
        const destHash = backupManager.getFileSHA256(destFile);

        if (srcHash !== destHash) {
          files.conflicts.push({
            file: fileMap.dest,
            sourcePath: srcFile,
            targetPath: destFile,
            sourceHash: srcHash,
            targetHash: destHash,
            sourceSize: fs.statSync(srcFile).size,
            targetSize: fs.statSync(destFile).size,
            action: null
          });
        }
      } else {
        files.new.push(fileMap.dest);
      }
    }
  }

  return files;
}

// Find new files (exist in source but not in target)
function findNewFiles(srcDir, destDir, relativePath = '') {
  const newFiles = [];

  if (!fs.existsSync(srcDir)) return newFiles;

  const items = fs.readdirSync(srcDir);
  for (const item of items) {
    const srcPath = path.join(srcDir, item);
    const destPath = path.join(destDir, item);
    const relPath = path.join(relativePath, item);
    const stat = fs.statSync(srcPath);

    if (stat.isDirectory()) {
      const subNew = findNewFiles(srcPath, destPath, relPath);
      newFiles.push(...subNew);
    } else {
      if (!fs.existsSync(destPath)) {
        newFiles.push(relPath);
      }
    }
  }

  return newFiles;
}

// Show pre-flight summary
function showPreflightSummary(files) {
  console.log('\n╔════════════════════════════════════════════════════════════╗');
  console.log('║          MyConvergio Installation Pre-Flight Check        ║');
  console.log('╚════════════════════════════════════════════════════════════╝\n');

  console.log(`📂 Installation target: ${CLAUDE_HOME}\n`);

  console.log(`✨ New files to install: ${files.new.length}`);
  if (files.new.length > 0 && files.new.length <= 10) {
    files.new.forEach(f => console.log(`   + ${f}`));
  } else if (files.new.length > 10) {
    files.new.slice(0, 5).forEach(f => console.log(`   + ${f}`));
    console.log(`   ... and ${files.new.length - 5} more`);
  }
  console.log('');

  console.log(`⚠️  Conflicting files: ${files.conflicts.length}`);
  if (files.conflicts.length > 0 && files.conflicts.length <= 10) {
    files.conflicts.forEach(c => console.log(`   ! ${c.file}`));
  } else if (files.conflicts.length > 10) {
    files.conflicts.slice(0, 5).forEach(c => console.log(`   ! ${c.file}`));
    console.log(`   ... and ${files.conflicts.length - 5} more`);
  }
  console.log('');
}

// Install new files (non-conflicting)
function installNewFiles(files) {
  const installed = [];

  for (const dirMap of INSTALL_MAP.dirs) {
    const srcDir = path.join(PACKAGE_ROOT, dirMap.src);
    const destDir = path.join(CLAUDE_HOME, dirMap.dest);

    if (fs.existsSync(srcDir)) {
      installNewFilesInDir(srcDir, destDir, dirMap.dest, files.new, installed);
    }
  }

  for (const fileMap of INSTALL_MAP.files) {
    const srcFile = path.join(PACKAGE_ROOT, fileMap.src);
    const destFile = path.join(CLAUDE_HOME, fileMap.dest);

    if (fs.existsSync(srcFile) && !fs.existsSync(destFile)) {
      const destDir = path.dirname(destFile);
      fs.mkdirSync(destDir, { recursive: true });
      fs.copyFileSync(srcFile, destFile);
      installed.push(fileMap.dest);
    }
  }

  return installed;
}

function installNewFilesInDir(srcDir, destDir, relativePath, newFilesList, installed) {
  if (!fs.existsSync(srcDir)) return;

  fs.mkdirSync(destDir, { recursive: true });

  const items = fs.readdirSync(srcDir);
  for (const item of items) {
    const srcPath = path.join(srcDir, item);
    const destPath = path.join(destDir, item);
    const relPath = path.join(relativePath, item);
    const stat = fs.statSync(srcPath);

    if (stat.isDirectory()) {
      installNewFilesInDir(srcPath, destPath, relPath, newFilesList, installed);
    } else {
      // Only install if in new files list
      if (newFilesList.includes(relPath)) {
        fs.copyFileSync(srcPath, destPath);
        installed.push(relPath);
      }
    }
  }
}

// Main installation flow
async function main() {
  console.log('\n🚀 MyConvergio Interactive Installation\n');

  // Ensure Claude home exists
  if (!fs.existsSync(CLAUDE_HOME)) {
    fs.mkdirSync(CLAUDE_HOME, { recursive: true });
  }

  // Pre-flight check
  console.log('Step 1: Analyzing your current installation...\n');
  const files = collectInstallationFiles();
  showPreflightSummary(files);

  // Create backup if there's existing content
  let backupDir = null;
  if (files.conflicts.length > 0 || files.new.length > 0) {
    console.log('Step 2: Creating safety backup...\n');
    backupDir = backupManager.createBackup('pre-install');

    if (backupDir) {
      console.log(`✅ Backup created: ${backupDir}`);
      console.log(`   Restore script: ${path.join(backupDir, 'restore.sh')}\n`);
    } else {
      console.log('ℹ️  No existing content to backup.\n');
    }
  }

  // Handle conflicts
  let resolvedConflicts = [];
  let skippedConflicts = [];

  if (files.conflicts.length > 0) {
    console.log('Step 3: Resolving conflicts...\n');

    if (mode === 'skip-conflicts') {
      console.log('⏭️  Skipping all conflicts (--skip-conflicts flag)\n');
      skippedConflicts = files.conflicts;
    } else {
      conflictResolver.showConflictSummary(files.conflicts);

      const resolution = await conflictResolver.resolveConflicts(files.conflicts, mode);
      resolvedConflicts = resolution.resolved;
      skippedConflicts = resolution.skipped;

      conflictResolver.showResolutionSummary(resolvedConflicts, skippedConflicts);
    }
  }

  // Install new files
  console.log('\nStep 4: Installing new files...\n');
  const installedNew = installNewFiles(files);
  console.log(`✅ Installed ${installedNew.length} new file(s)\n`);

  // Apply conflict resolutions
  if (resolvedConflicts.length > 0) {
    console.log('Step 5: Applying conflict resolutions...\n');
    const results = conflictResolver.applyResolutions(resolvedConflicts);

    if (results.success.length > 0) {
      console.log(`✅ Applied ${results.success.length} resolution(s)\n`);
    }

    if (results.failed.length > 0) {
      console.log(`❌ Failed to apply ${results.failed.length} resolution(s):\n`);
      results.failed.forEach(f => console.log(`   - ${f.file}: ${f.error}`));
      console.log('');
    }
  }

  // Final report
  console.log('\n╔════════════════════════════════════════════════════════════╗');
  console.log('║                 INSTALLATION COMPLETE                      ║');
  console.log('╚════════════════════════════════════════════════════════════╝\n');

  console.log(`📊 Summary:`);
  console.log(`   - New files installed: ${installedNew.length}`);
  console.log(`   - Conflicts resolved: ${resolvedConflicts.length}`);
  console.log(`   - Conflicts skipped: ${skippedConflicts.length}\n`);

  if (backupDir) {
    console.log(`🔄 Backup Location: ${backupDir}`);
    console.log(`   To restore: bash ${path.join(backupDir, 'restore.sh')}\n`);
  }

  if (skippedConflicts.length > 0) {
    console.log('⚠️  Some files were skipped due to conflicts.');
    console.log('   Re-run with --accept-all to use MyConvergio versions\n');
  }

  console.log('✨ MyConvergio is ready to use!\n');
}

// Run if called directly
if (require.main === module) {
  main().catch(err => {
    console.error('\n❌ Installation failed:', err.message);
    console.error(err.stack);
    process.exit(1);
  });
}

module.exports = { main, collectInstallationFiles, showPreflightSummary };
