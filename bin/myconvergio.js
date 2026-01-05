#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const os = require('os');
const readline = require('readline');

const CLAUDE_HOME = path.join(os.homedir(), '.claude');
const PACKAGE_ROOT = path.join(__dirname, '..');
const VERSION_FILE = path.join(PACKAGE_ROOT, 'VERSION');
const MANIFEST_FILE = path.join(CLAUDE_HOME, '.myconvergio-manifest.json');

// Import new modules
const backupManager = require('../scripts/backup-manager');
const gitManager = require('../scripts/git-manager');
const postinstallInteractive = require('../scripts/postinstall-interactive');

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

function getVersion() {
  try {
    const content = fs.readFileSync(VERSION_FILE, 'utf8');
    const match = content.match(/SYSTEM_VERSION=(.+)/);
    return match ? match[1].trim() : 'unknown';
  } catch {
    const pkg = require('../package.json');
    return pkg.version;
  }
}

function countInstalled() {
  const counts = { agents: 0, rules: 0, skills: 0 };

  const agentsDir = path.join(CLAUDE_HOME, 'agents');
  if (fs.existsSync(agentsDir)) {
    counts.agents = countMdFiles(agentsDir);
  }

  const rulesDir = path.join(CLAUDE_HOME, 'rules');
  if (fs.existsSync(rulesDir)) {
    counts.rules = countMdFiles(rulesDir);
  }

  const skillsDir = path.join(CLAUDE_HOME, 'skills');
  if (fs.existsSync(skillsDir)) {
    counts.skills = fs.readdirSync(skillsDir).filter(f =>
      fs.statSync(path.join(skillsDir, f)).isDirectory()
    ).length;
  }

  return counts;
}

function countMdFiles(dir) {
  let count = 0;
  const items = fs.readdirSync(dir);
  for (const item of items) {
    const fullPath = path.join(dir, item);
    const stat = fs.statSync(fullPath);
    if (stat.isDirectory()) {
      count += countMdFiles(fullPath);
    } else if (item.endsWith('.md') &&
               !['CONSTITUTION.md', 'CommonValuesAndPrinciples.md', 'SECURITY_FRAMEWORK_TEMPLATE.md'].includes(item)) {
      count++;
    }
  }
  return count;
}

function copyRecursive(src, dest, installedFiles = []) {
  if (!fs.existsSync(src)) return installedFiles;

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
  return { files: [], version: null, installedAt: null };
}

function saveManifest(files, version) {
  const manifest = {
    version,
    installedAt: new Date().toISOString(),
    files
  };
  fs.writeFileSync(MANIFEST_FILE, JSON.stringify(manifest, null, 2));
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

  if (hasContent) {
    return backupDir;
  }
  return null;
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

function getAgentsForProfile(profile) {
  const minimal = [
    'leadership_strategy/ali-chief-of-staff.md',
    'core_utility/thor-quality-assurance-guardian.md',
    'core_utility/strategic-planner.md',
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
    // 'full' and 'lean' both install all agents (lean uses agents-lean directory)
    return { type: 'full', list: [] };
  }
}

function copyAgentsByProfile(srcAgents, destAgents, profile) {
  const agentSpec = getAgentsForProfile(profile);
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

function install(options = {}) {
  const profile = options.profile || 'full';
  const skipBackup = options.skipBackup || false;

  log(colors.blue, `Installing MyConvergio (${profile} profile) to ~/.claude/...\n`);

  // Check for existing content and ALWAYS backup if found
  const existingManifest = loadManifest();
  const hasContent = hasExistingContent();

  if (!skipBackup && hasContent) {
    if (existingManifest.version) {
      log(colors.yellow, `Upgrading from v${existingManifest.version}...`);
    } else {
      log(colors.yellow, 'Existing ~/.claude/ content detected.');
    }
    log(colors.yellow, 'Creating backup before installation...\n');
    const backupDir = createBackup();
    if (backupDir) {
      log(colors.green, `  ✓ Backup created: ${backupDir}\n`);
    }
  } else if (!hasContent) {
    log(colors.blue, 'Fresh installation to ~/.claude/\n');
  }

  // For lean profile, use agents-lean directory if available
  const agentsLeanDir = path.join(PACKAGE_ROOT, '.claude', 'agents-lean');
  const srcAgents = (profile === 'lean' && fs.existsSync(agentsLeanDir))
    ? agentsLeanDir
    : path.join(PACKAGE_ROOT, '.claude', 'agents');

  // For minimal/lean profiles, use consolidated rules if available
  const consolidatedRules = path.join(PACKAGE_ROOT, '.claude', 'rules', 'consolidated');
  const srcRules = ((profile === 'minimal' || profile === 'lean') && fs.existsSync(consolidatedRules))
    ? consolidatedRules
    : path.join(PACKAGE_ROOT, '.claude', 'rules');

  const srcSkills = path.join(PACKAGE_ROOT, '.claude', 'skills');

  let installedFiles = [];

  // Install agents based on profile
  installedFiles = copyAgentsByProfile(srcAgents, path.join(CLAUDE_HOME, 'agents'), profile);
  const agentCount = installedFiles.filter(f => f.endsWith('.md') &&
    !f.includes('CONSTITUTION') && !f.includes('CommonValues')).length;
  log(colors.green, `  ✓ Installed ${agentCount} agents`);

  // Install rules
  copyRecursive(srcRules, path.join(CLAUDE_HOME, 'rules'), installedFiles);
  log(colors.green, '  ✓ Installed rules');

  // Install skills
  copyRecursive(srcSkills, path.join(CLAUDE_HOME, 'skills'), installedFiles);
  log(colors.green, '  ✓ Installed skills');

  // Save manifest
  const version = getVersion();
  saveManifest(installedFiles, version);
  log(colors.green, `  ✓ Saved manifest (${installedFiles.length} files)`);

  console.log('');
  log(colors.green, '✅ Installation complete!');
  console.log('');

  if (profile === 'minimal') {
    log(colors.yellow, '💡 Minimal installation (9 core agents + consolidated rules)');
    console.log('    To install more: myconvergio install --standard or --full\n');
  } else if (profile === 'standard') {
    log(colors.yellow, '💡 Standard installation (~25 agents)');
    console.log('    To install all: myconvergio install --full\n');
  } else if (profile === 'lean') {
    log(colors.yellow, '💡 Lean installation (all 57 agents, 20% smaller + consolidated rules)');
    console.log('    Optimized for reduced context usage.\n');
  }

  log(colors.yellow, 'Note: Your ~/.claude/CLAUDE.md was NOT modified.');
  console.log('      Create your own configuration file if needed.');
}

function uninstall() {
  log(colors.blue, 'Removing MyConvergio from ~/.claude/...\n');

  const manifest = loadManifest();

  if (manifest.files && manifest.files.length > 0) {
    // Safe uninstall: only remove files we installed
    log(colors.yellow, `Removing ${manifest.files.length} files installed by MyConvergio...\n`);

    let removed = 0;
    for (const file of manifest.files) {
      if (fs.existsSync(file)) {
        fs.unlinkSync(file);
        removed++;
      }
    }

    // Clean up empty directories
    const dirs = ['agents', 'rules', 'skills'];
    for (const dir of dirs) {
      cleanEmptyDirs(path.join(CLAUDE_HOME, dir));
    }

    // Remove manifest
    if (fs.existsSync(MANIFEST_FILE)) {
      fs.unlinkSync(MANIFEST_FILE);
    }

    log(colors.green, `  ✓ Removed ${removed} files`);
    console.log('');
    log(colors.green, '✅ Uninstall complete!');
    log(colors.yellow, 'Your custom files were preserved.');
  } else {
    // No manifest - warn user
    log(colors.yellow, '⚠️  No installation manifest found.');
    log(colors.yellow, 'This means MyConvergio was installed before manifest tracking,');
    log(colors.yellow, 'or was installed via git clone.\n');
    log(colors.yellow, 'To avoid deleting your custom files, please manually remove:');
    console.log('  ~/.claude/agents/');
    console.log('  ~/.claude/rules/');
    console.log('  ~/.claude/skills/');
    console.log('');
    log(colors.yellow, 'Or use: make clean (if installed via git clone)');
  }

  console.log('');
  log(colors.yellow, 'Note: ~/.claude/CLAUDE.md was NOT removed (user config).');
}

function cleanEmptyDirs(dir) {
  if (!fs.existsSync(dir)) return;

  const items = fs.readdirSync(dir);
  for (const item of items) {
    const fullPath = path.join(dir, item);
    if (fs.statSync(fullPath).isDirectory()) {
      cleanEmptyDirs(fullPath);
    }
  }

  // Check if directory is now empty
  if (fs.readdirSync(dir).length === 0) {
    fs.rmdirSync(dir);
  }
}

function showVersion() {
  const version = getVersion();
  log(colors.blue, `MyConvergio v${version}`);
  console.log('');

  const counts = countInstalled();
  log(colors.blue, 'Installed Components:');
  console.log(`  Agents: ${counts.agents > 0 ? counts.agents : colors.red + 'not installed' + colors.reset}`);
  console.log(`  Rules:  ${counts.rules > 0 ? counts.rules : colors.red + 'not installed' + colors.reset}`);
  console.log(`  Skills: ${counts.skills > 0 ? counts.skills : colors.red + 'not installed' + colors.reset}`);
}

function listAgents() {
  log(colors.blue, 'Installed Agents:\n');

  const agentsDir = path.join(CLAUDE_HOME, 'agents');
  if (!fs.existsSync(agentsDir)) {
    log(colors.red, 'No agents installed. Run: myconvergio install');
    return;
  }

  const categories = fs.readdirSync(agentsDir).filter(f =>
    fs.statSync(path.join(agentsDir, f)).isDirectory()
  );

  let totalAgents = 0;

  for (const category of categories.sort()) {
    const categoryPath = path.join(agentsDir, category);
    const agents = fs.readdirSync(categoryPath).filter(f =>
      f.endsWith('.md') &&
      !['CONSTITUTION.md', 'CommonValuesAndPrinciples.md', 'SECURITY_FRAMEWORK_TEMPLATE.md', 'MICROSOFT_VALUES.md'].includes(f)
    );

    if (agents.length === 0) continue;

    log(colors.yellow, `\n${category}/`);

    for (const agent of agents.sort()) {
      const agentPath = path.join(categoryPath, agent);
      const content = fs.readFileSync(agentPath, 'utf8');

      // Extract version from YAML frontmatter
      const versionMatch = content.match(/^version:\s*["']?([^"'\n]+)["']?/m);
      const version = versionMatch ? versionMatch[1] : 'unknown';

      // Extract model from YAML frontmatter
      const modelMatch = content.match(/^model:\s*["']?([^"'\n]+)["']?/m);
      const model = modelMatch ? modelMatch[1] : 'haiku';

      const agentName = agent.replace('.md', '');
      const modelColor = model === 'opus' ? colors.red : model === 'sonnet' ? colors.yellow : colors.reset;

      console.log(`  ${agentName.padEnd(45)} v${version.padEnd(8)} ${modelColor}${model}${colors.reset}`);
      totalAgents++;
    }
  }

  console.log('');
  log(colors.green, `Total: ${totalAgents} agents`);
}

function detectHardware() {
  const cpuCount = require('os').cpus().length;
  const totalMem = Math.round(require('os').totalmem() / (1024 * 1024 * 1024)); // GB

  if (totalMem >= 32 && cpuCount >= 10) {
    return 'high';
  } else if (totalMem >= 16 && cpuCount >= 6) {
    return 'mid';
  } else {
    return 'low';
  }
}

function showSettings() {
  const os = require('os');
  const cpuCount = os.cpus().length;
  const totalMem = Math.round(os.totalmem() / (1024 * 1024 * 1024));
  const cpuModel = os.cpus()[0].model;
  const recommendedProfile = detectHardware();

  log(colors.blue, '\nHardware Detection\n');
  console.log(`  CPU: ${cpuModel}`);
  console.log(`  Cores: ${cpuCount}`);
  console.log(`  RAM: ${totalMem}GB`);
  console.log('');

  log(colors.yellow, `Recommended settings profile: ${recommendedProfile}-spec`);
  console.log('');

  const templatePath = path.join(PACKAGE_ROOT, '.claude', 'settings-templates', `${recommendedProfile}-spec.json`);
  const settingsPath = path.join(CLAUDE_HOME, 'settings.json');

  if (fs.existsSync(settingsPath)) {
    log(colors.yellow, 'You already have a settings.json file.');
    console.log(`To apply recommended settings, run:\n`);
    console.log(`  cp "${templatePath}" "${settingsPath}"`);
  } else {
    console.log('To apply recommended settings, run:\n');
    console.log(`  mkdir -p ~/.claude && cp "${templatePath}" "${settingsPath}"`);
  }

  console.log('');
  log(colors.blue, 'Available templates:');
  console.log('  low-spec.json   - 8GB RAM, 4 cores (conservative)');
  console.log('  mid-spec.json   - 16GB RAM, 8 cores (balanced)');
  console.log('  high-spec.json  - 32GB+ RAM, 10+ cores (maximum performance)');
  console.log('');
  console.log(`Templates located in: ${path.join(PACKAGE_ROOT, '.claude', 'settings-templates')}`);
}

function showHelp() {
  console.log(`
${colors.blue}MyConvergio - Claude Code Subagents Suite${colors.reset}

${colors.yellow}Usage:${colors.reset}
  myconvergio [command] [options]

${colors.yellow}Commands:${colors.reset}
  install              Install/reinstall agents, rules, and skills to ~/.claude/
  install-interactive  Interactive installation with conflict detection
  uninstall            Remove all installed components from ~/.claude/
  agents               List all installed agents with versions
  settings             Detect hardware and recommend settings profile
  version              Show version and installation status

  backup               Create manual backup of ~/.claude
  restore <dir>        Restore from backup directory
  list-backups         List all available backups

  git-init             Initialize git tracking for ~/.claude (opt-in)
  git-status           Show git status of ~/.claude
  git-commit [msg]     Commit changes to ~/.claude git repo

  help                 Show this help message

${colors.yellow}Install Options:${colors.reset}
  --minimal   Install 8 core agents (~50KB)
              ali, thor, baccio, rex, dario, otto, release managers

  --standard  Install 20 essential agents (~200KB)
              Leadership, technical, release, compliance categories

  --full      Install all 57 agents (~800KB) [default]
              Complete ecosystem

  --lean      Install optimized agents with reduced context (~400KB)
              All agents but stripped Security Frameworks

${colors.yellow}Examples:${colors.reset}
  npm install -g myconvergio                  # Installs minimal by default
  MYCONVERGIO_PROFILE=full npm install -g myconvergio

  myconvergio install --minimal               # 8 core agents
  myconvergio install --standard              # 20 agents
  myconvergio install --full                  # All 57 agents
  myconvergio install --lean                  # Optimized

  myconvergio install-interactive             # Safe interactive install
  myconvergio backup                          # Create backup
  myconvergio restore ~/.claude-backup-...    # Restore backup
  myconvergio git-init                        # Enable git tracking

  myconvergio agents                          # List installed
  myconvergio version                         # Check version
  myconvergio uninstall                       # Remove all

${colors.yellow}Environment Variables:${colors.reset}
  MYCONVERGIO_PROFILE=minimal|standard|full|lean
    Set default profile for npm postinstall

${colors.yellow}More info:${colors.reset}
  https://github.com/roberdan/MyConvergio
`);
}

// Backup commands
function createManualBackup() {
  log(colors.blue, 'Creating backup of ~/.claude/...\n');
  const backupDir = backupManager.createBackup('manual');

  if (backupDir) {
    log(colors.green, `✅ Backup created: ${backupDir}`);
    console.log(`   Restore script: ${path.join(backupDir, 'restore.sh')}`);
    console.log(`   Manifest: ${path.join(backupDir, 'MANIFEST.json')}`);
  } else {
    log(colors.yellow, 'ℹ️  No content to backup (empty ~/.claude directory)');
  }
}

function restoreFromBackup(backupDir) {
  if (!backupDir) {
    log(colors.red, '❌ Error: Please specify backup directory');
    console.log('   Usage: myconvergio restore <backup-directory>');
    console.log('\n   List available backups: myconvergio list-backups');
    return;
  }

  if (!fs.existsSync(backupDir)) {
    log(colors.red, `❌ Error: Backup directory not found: ${backupDir}`);
    return;
  }

  const manifestPath = path.join(backupDir, 'MANIFEST.json');
  if (!fs.existsSync(manifestPath)) {
    log(colors.red, '❌ Error: Invalid backup (MANIFEST.json not found)');
    return;
  }

  log(colors.blue, `Restoring from: ${backupDir}\n`);

  const safetyBackup = backupManager.restoreBackup(backupDir);

  log(colors.green, '✅ Restore complete!');
  console.log(`   Safety backup created: ${safetyBackup}`);
  console.log('   (in case you need to undo this restore)');
}

function listBackupsCommand() {
  const backups = backupManager.listBackups();

  if (backups.length === 0) {
    log(colors.yellow, 'No backups found.');
    console.log('   Create one with: myconvergio backup');
    return;
  }

  log(colors.blue, `Found ${backups.length} backup(s):\n`);

  for (const backup of backups) {
    const date = new Date(backup.timestamp);
    const dateStr = date.toLocaleString();
    const sizeKB = Math.round(backup.size / 1024);

    console.log(`${colors.yellow}${backup.name}${colors.reset}`);
    console.log(`  Date:   ${dateStr}`);
    console.log(`  Reason: ${backup.reason}`);
    console.log(`  Files:  ${backup.fileCount} (${sizeKB}KB)`);
    console.log(`  Path:   ${backup.path}`);
    console.log('');
  }
}

// Git commands
function initGitCommand() {
  if (gitManager.isGitInitialized()) {
    log(colors.yellow, '⚠️  Git already initialized in ~/.claude');
    console.log('   Use: myconvergio git-status');
    return;
  }

  log(colors.blue, 'Initializing git tracking for ~/.claude...\n');

  const result = gitManager.initGit();

  if (result.success) {
    log(colors.green, '✅ Git tracking initialized!');
    console.log('   .gitignore created');
    console.log('   Initial commit created');

    if (result.hasChanges) {
      console.log(`\n   ${result.changes.length} file(s) ready to commit`);
      console.log('   Use: myconvergio git-commit');
    }
  } else {
    log(colors.red, `❌ ${result.message}`);
    if (result.error) {
      console.log(`   Error: ${result.error}`);
    }
  }
}

function gitStatusCommand() {
  if (!gitManager.isGitInitialized()) {
    log(colors.yellow, '⚠️  Git not initialized in ~/.claude');
    console.log('   Enable with: myconvergio git-init');
    return;
  }

  const status = gitManager.getGitStatus();

  if (status.error) {
    log(colors.red, `❌ Error: ${status.error}`);
    return;
  }

  log(colors.blue, 'Git Status (~/.claude):\n');

  if (status.hasChanges) {
    console.log(status.status);
    console.log('');
    log(colors.yellow, `${status.changes.length} file(s) with changes`);
    console.log('   Commit with: myconvergio git-commit');
  } else {
    log(colors.green, '✓ Working tree clean (no changes)');
  }
}

function gitCommitCommand(message) {
  if (!gitManager.isGitInitialized()) {
    log(colors.yellow, '⚠️  Git not initialized in ~/.claude');
    console.log('   Enable with: myconvergio git-init');
    return;
  }

  const result = gitManager.commitChanges(message);

  if (result.success) {
    log(colors.green, '✅ Changes committed!');
    console.log(`   Message: ${result.commitMessage}`);
  } else {
    log(colors.yellow, result.message);
  }
}

function installInteractiveCommand() {
  log(colors.blue, 'Starting interactive installation...\n');
  postinstallInteractive.main().catch(err => {
    log(colors.red, `❌ Installation failed: ${err.message}`);
    process.exit(1);
  });
}

// Main
const args = process.argv.slice(2);
const command = args[0] || 'help';

// Parse flags
const hasFlag = (flag) => args.includes(flag);
const profile = hasFlag('--minimal') ? 'minimal' :
                hasFlag('--standard') ? 'standard' :
                hasFlag('--lean') ? 'lean' :
                hasFlag('--full') ? 'full' :
                'full'; // default for CLI

switch (command) {
  case 'install':
  case 'reinstall':
  case 'update':
    install({ profile, skipBackup: false });
    break;
  case 'install-interactive':
    installInteractiveCommand();
    break;
  case 'uninstall':
  case 'remove':
    uninstall();
    break;
  case 'agents':
  case 'list':
    listAgents();
    break;
  case 'settings':
  case 'hardware':
    showSettings();
    break;
  case 'version':
  case '-v':
  case '--version':
    showVersion();
    break;
  case 'backup':
    createManualBackup();
    break;
  case 'restore':
    restoreFromBackup(args[1]);
    break;
  case 'list-backups':
  case 'backups':
    listBackupsCommand();
    break;
  case 'git-init':
    initGitCommand();
    break;
  case 'git-status':
    gitStatusCommand();
    break;
  case 'git-commit':
    gitCommitCommand(args.slice(1).join(' '));
    break;
  case 'help':
  case '-h':
  case '--help':
  default:
    showHelp();
    break;
}
