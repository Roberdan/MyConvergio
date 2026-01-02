#!/usr/bin/env node

/**
 * MyConvergio Post-Install Script
 *
 * Automatically copies agents, rules, and skills to ~/.claude/
 * after npm install -g myconvergio
 *
 * Features:
 * - Creates backup if existing installation found
 * - Saves manifest of installed files for safe uninstall
 * - Preserves user's custom files and CLAUDE.md
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

const CLAUDE_HOME = path.join(os.homedir(), '.claude');
const PACKAGE_ROOT = path.join(__dirname, '..');
const MANIFEST_FILE = path.join(CLAUDE_HOME, '.myconvergio-manifest.json');

// Colors for terminal output
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
};

function log(color, message) {
  // Use stderr for npm postinstall visibility (npm suppresses stdout)
  process.stderr.write(`${color}${message}${colors.reset}\n`);
}

function copyRecursive(src, dest, installedFiles = []) {
  if (!fs.existsSync(src)) {
    return installedFiles;
  }

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

  return installedFiles;
}

function loadManifest() {
  try {
    if (fs.existsSync(MANIFEST_FILE)) {
      return JSON.parse(fs.readFileSync(MANIFEST_FILE, 'utf8'));
    }
  } catch {}
  return { files: [], version: null };
}

function saveManifest(files, version) {
  const manifest = {
    version,
    installedAt: new Date().toISOString(),
    files
  };
  fs.mkdirSync(CLAUDE_HOME, { recursive: true });
  fs.writeFileSync(MANIFEST_FILE, JSON.stringify(manifest, null, 2));
}

function getVersion() {
  try {
    const versionFile = path.join(PACKAGE_ROOT, 'VERSION');
    const content = fs.readFileSync(versionFile, 'utf8');
    const match = content.match(/SYSTEM_VERSION=(.+)/);
    return match ? match[1].trim() : 'unknown';
  } catch {
    const pkg = require('../package.json');
    return pkg.version;
  }
}

function createBackup() {
  const backupDir = path.join(os.homedir(), '.claude-backup-' + Date.now());
  const dirs = ['agents', 'rules', 'skills'];
  let hasContent = false;

  for (const dir of dirs) {
    const srcDir = path.join(CLAUDE_HOME, dir);
    if (fs.existsSync(srcDir) && fs.readdirSync(srcDir).length > 0) {
      hasContent = true;
      copyRecursive(srcDir, path.join(backupDir, dir));
    }
  }

  return hasContent ? backupDir : null;
}

function countDirs(dir) {
  if (!fs.existsSync(dir)) return 0;
  return fs.readdirSync(dir).filter(f =>
    fs.statSync(path.join(dir, f)).isDirectory()
  ).length;
}

function hasExistingContent() {
  const dirs = ['agents', 'rules', 'skills'];
  for (const dir of dirs) {
    const dirPath = path.join(CLAUDE_HOME, dir);
    if (fs.existsSync(dirPath) && fs.readdirSync(dirPath).length > 0) {
      return true;
    }
  }
  return false;
}

function getInstallProfile() {
  const profile = process.env.MYCONVERGIO_PROFILE || 'minimal';
  const validProfiles = ['minimal', 'standard', 'full', 'lean'];
  if (!validProfiles.includes(profile)) {
    log(colors.yellow, `Unknown profile "${profile}", using "minimal"`);
    return 'minimal';
  }
  return profile;
}

function getAgentsForProfile(profile, srcAgents) {
  const minimal = [
    'leadership_strategy/ali-chief-of-staff.md',
    'core_utility/thor-quality-assurance-guardian.md',
    'technical_development/baccio-tech-architect.md',
    'technical_development/rex-code-reviewer.md',
    'technical_development/dario-debugger.md',
    'technical_development/otto-performance-optimizer.md',
    'release_management/app-release-manager.md',
    'release_management/feature-release-manager.md',
  ];

  const standard = [
    'leadership_strategy',
    'technical_development',
    'release_management',
    'compliance_legal',
    'core_utility',
  ];

  if (profile === 'minimal') {
    return { type: 'files', list: minimal };
  } else if (profile === 'standard') {
    return { type: 'categories', list: standard };
  } else {
    return { type: 'full', list: [] };
  }
}

function copyAgentsByProfile(srcAgents, destAgents, profile) {
  const agentSpec = getAgentsForProfile(profile, srcAgents);
  const installedFiles = [];

  fs.mkdirSync(destAgents, { recursive: true });

  // Always copy core utility files (CONSTITUTION, etc)
  const coreUtilSrc = path.join(srcAgents, 'core_utility');
  const coreUtilDest = path.join(destAgents, 'core_utility');
  if (fs.existsSync(coreUtilSrc)) {
    copyRecursive(coreUtilSrc, coreUtilDest, installedFiles);
  }

  if (agentSpec.type === 'files') {
    // Copy specific files
    for (const agentPath of agentSpec.list) {
      const srcPath = path.join(srcAgents, agentPath);
      const category = path.dirname(agentPath);
      const fileName = path.basename(agentPath);
      const destCategoryDir = path.join(destAgents, category);
      const destPath = path.join(destCategoryDir, fileName);

      if (fs.existsSync(srcPath)) {
        fs.mkdirSync(destCategoryDir, { recursive: true });
        fs.copyFileSync(srcPath, destPath);
        installedFiles.push(destPath);
      }
    }
  } else if (agentSpec.type === 'categories') {
    // Copy entire categories
    for (const category of agentSpec.list) {
      if (category === 'core_utility') continue; // Already copied
      const srcCat = path.join(srcAgents, category);
      const destCat = path.join(destAgents, category);
      if (fs.existsSync(srcCat)) {
        copyRecursive(srcCat, destCat, installedFiles);
      }
    }
  } else {
    // Full install
    copyRecursive(srcAgents, destAgents, installedFiles);
  }

  return installedFiles;
}

function main() {
  // Skip if running in CI or if MYCONVERGIO_SKIP_POSTINSTALL is set
  if (process.env.CI || process.env.MYCONVERGIO_SKIP_POSTINSTALL) {
    console.log('Skipping postinstall (CI environment or MYCONVERGIO_SKIP_POSTINSTALL set)');
    return;
  }

  const profile = getInstallProfile();
  log(colors.blue, `\n📦 MyConvergio Post-Install (${profile} profile)\n`);

  const srcAgents = path.join(PACKAGE_ROOT, '.claude', 'agents');
  const srcRules = path.join(PACKAGE_ROOT, '.claude', 'rules');
  const srcSkills = path.join(PACKAGE_ROOT, '.claude', 'skills');

  // Check if source directories exist
  if (!fs.existsSync(srcAgents)) {
    log(colors.yellow, 'Warning: Source agents directory not found. Skipping installation.');
    return;
  }

  // Check for existing content and ALWAYS backup if found
  const existingManifest = loadManifest();
  const hasContent = hasExistingContent();

  if (existingManifest.version) {
    log(colors.yellow, `Upgrading from v${existingManifest.version}...`);
  } else if (hasContent) {
    log(colors.yellow, 'Existing ~/.claude/ content detected (not installed via npm).');
  }

  if (hasContent) {
    log(colors.yellow, 'Creating backup before installation...\n');
    const backupDir = createBackup();
    if (backupDir) {
      log(colors.green, `  ✓ Backup created: ${backupDir}\n`);
    }
  } else {
    log(colors.blue, 'Fresh installation to ~/.claude/\n');
  }

  let installedFiles = [];

  // Install agents based on profile
  installedFiles = copyAgentsByProfile(srcAgents, path.join(CLAUDE_HOME, 'agents'), profile);
  const agentCount = installedFiles.filter(f => f.endsWith('.md') &&
    !f.includes('CONSTITUTION') && !f.includes('CommonValues')).length;
  log(colors.green, `  ✓ Installed ${agentCount} agents`);

  // Install rules
  copyRecursive(srcRules, path.join(CLAUDE_HOME, 'rules'), installedFiles);
  log(colors.green, `  ✓ Installed rules`);

  // Install skills
  copyRecursive(srcSkills, path.join(CLAUDE_HOME, 'skills'), installedFiles);
  const skillsCount = countDirs(path.join(CLAUDE_HOME, 'skills'));
  log(colors.green, `  ✓ Installed ${skillsCount} skills`);

  // Save manifest for safe uninstall
  const version = getVersion();
  saveManifest(installedFiles, version);
  log(colors.green, `  ✓ Saved manifest (${installedFiles.length} files)`);

  process.stderr.write('\n');
  log(colors.green, '✅ MyConvergio installed successfully!');
  process.stderr.write('\n');

  if (profile === 'minimal') {
    log(colors.yellow, '💡 Minimal installation complete (8 core agents)');
    process.stderr.write('    To install more agents, run:\n');
    process.stderr.write('    • myconvergio install --standard  (20 agents)\n');
    process.stderr.write('    • myconvergio install --full      (all 57 agents)\n');
    process.stderr.write('    • myconvergio install --lean      (optimized)\n\n');
  }

  log(colors.yellow, 'Your ~/.claude/CLAUDE.md was NOT modified.');
  process.stderr.write('Create your own configuration file if needed.\n');
  process.stderr.write('Run `myconvergio help` for available commands.\n\n');
}

main();
