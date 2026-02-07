#!/usr/bin/env node

/**
 * MyConvergio Backup Manager
 *
 * Handles backup creation, restoration, and management
 */

const fs = require("fs");
const path = require("path");
const os = require("os");
const crypto = require("crypto");

const CLAUDE_HOME = path.join(os.homedir(), ".claude");

function createBackup(reason = "manual") {
  const timestamp = new Date()
    .toISOString()
    .replace(/[:.]/g, "-")
    .split(".")[0];
  const backupDir = path.join(os.homedir(), `.claude-backup-${timestamp}`);

  const dirs = [
    "agents",
    "rules",
    "skills",
    "templates",
    "scripts",
    "hooks",
    "reference",
  ];
  const files = ["CLAUDE.md"];

  let hasContent = false;
  const backedUpFiles = [];

  // Create backup directory
  fs.mkdirSync(backupDir, { recursive: true });

  // Backup directories
  for (const dir of dirs) {
    const srcDir = path.join(CLAUDE_HOME, dir);
    if (fs.existsSync(srcDir) && fs.readdirSync(srcDir).length > 0) {
      hasContent = true;
      const destDir = path.join(backupDir, dir);
      copyRecursiveWithManifest(srcDir, destDir, backedUpFiles);
    }
  }

  // Backup individual files
  for (const file of files) {
    const srcFile = path.join(CLAUDE_HOME, file);
    if (fs.existsSync(srcFile)) {
      hasContent = true;
      const destFile = path.join(backupDir, file);
      fs.copyFileSync(srcFile, destFile);
      backedUpFiles.push({
        path: file,
        size: fs.statSync(srcFile).size,
        sha256: getFileSHA256(srcFile),
        modified: fs.statSync(srcFile).mtime.toISOString(),
      });
    }
  }

  if (!hasContent) {
    fs.rmdirSync(backupDir);
    return null;
  }

  // Create manifest
  const manifest = {
    timestamp: new Date().toISOString(),
    reason,
    claude_home: CLAUDE_HOME,
    files: backedUpFiles,
    total_size: backedUpFiles.reduce((sum, f) => sum + f.size, 0),
    file_count: backedUpFiles.length,
  };

  fs.writeFileSync(
    path.join(backupDir, "MANIFEST.json"),
    JSON.stringify(manifest, null, 2),
  );

  // Generate restore script
  generateRestoreScript(backupDir, manifest);

  return backupDir;
}

function copyRecursiveWithManifest(src, dest, manifestFiles) {
  if (!fs.existsSync(src)) return;

  fs.mkdirSync(dest, { recursive: true });

  const items = fs.readdirSync(src);
  for (const item of items) {
    const srcPath = path.join(src, item);
    const destPath = path.join(dest, item);
    const stat = fs.statSync(srcPath);

    if (stat.isDirectory()) {
      copyRecursiveWithManifest(srcPath, destPath, manifestFiles);
    } else {
      fs.copyFileSync(srcPath, destPath);

      // Add to manifest (relative to backup root)
      const relativePath = path.relative(
        path.dirname(path.dirname(dest)),
        destPath,
      );
      manifestFiles.push({
        path: relativePath,
        size: stat.size,
        sha256: getFileSHA256(srcPath),
        modified: stat.mtime.toISOString(),
      });
    }
  }
}

function getFileSHA256(filepath) {
  const content = fs.readFileSync(filepath);
  return crypto
    .createHash("sha256")
    .update(content)
    .digest("hex")
    .substring(0, 8);
}

function generateRestoreScript(backupDir, manifest) {
  const script = `#!/bin/bash
# MyConvergio Backup Restore Script
# Created: ${manifest.timestamp}
# Backup: ${backupDir}
# Files: ${manifest.file_count}

set -e

BACKUP_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_HOME="$HOME/.claude"

echo "🔄 Restoring backup from: $BACKUP_DIR"
echo ""
echo "⚠️  This will:"
echo "  - Replace ~/.claude/agents/ with backup"
echo "  - Replace ~/.claude/rules/ with backup"
echo "  - Replace ~/.claude/skills/ with backup"
echo "  - Replace ~/.claude/templates/ with backup"
echo "  - Replace ~/.claude/scripts/ with backup"
echo "  - Replace ~/.claude/hooks/ with backup"
echo "  - Replace ~/.claude/reference/ with backup"
echo "  - Restore ~/.claude/CLAUDE.md"
echo ""
echo "  Your current ~/.claude/ will be backed up to:"
echo "  ~/.claude-backup-pre-restore-$(date +%Y%m%d-%H%M%S)/"
echo ""
read -p "Continue? [y/N]: " confirm

if [[ "$confirm" != "y" ]]; then
  echo "Cancelled."
  exit 0
fi

# Backup current before restore
echo "Creating safety backup..."
SAFETY_BACKUP="$HOME/.claude-backup-pre-restore-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$SAFETY_BACKUP"
cp -r "$CLAUDE_HOME"/* "$SAFETY_BACKUP/" 2>/dev/null || true

# Restore
echo "Restoring files..."
[ -d "$BACKUP_DIR/agents" ] && cp -r "$BACKUP_DIR/agents" "$CLAUDE_HOME/"
[ -d "$BACKUP_DIR/rules" ] && cp -r "$BACKUP_DIR/rules" "$CLAUDE_HOME/"
[ -d "$BACKUP_DIR/skills" ] && cp -r "$BACKUP_DIR/skills" "$CLAUDE_HOME/"
[ -d "$BACKUP_DIR/templates" ] && cp -r "$BACKUP_DIR/templates" "$CLAUDE_HOME/"
[ -d "$BACKUP_DIR/scripts" ] && cp -r "$BACKUP_DIR/scripts" "$CLAUDE_HOME/"
[ -d "$BACKUP_DIR/hooks" ] && cp -r "$BACKUP_DIR/hooks" "$CLAUDE_HOME/"
[ -d "$BACKUP_DIR/reference" ] && cp -r "$BACKUP_DIR/reference" "$CLAUDE_HOME/"
[ -f "$BACKUP_DIR/CLAUDE.md" ] && cp "$BACKUP_DIR/CLAUDE.md" "$CLAUDE_HOME/"

echo "✅ Restore complete!"
echo ""
echo "📂 Safety backup: $SAFETY_BACKUP"
echo "   (in case you need to undo this restore)"
`;

  const scriptPath = path.join(backupDir, "restore.sh");
  fs.writeFileSync(scriptPath, script);
  fs.chmodSync(scriptPath, "755");
}

function restoreBackup(backupDir, options = {}) {
  const { onlyFiles = null } = options;

  // Validate backup
  const manifestPath = path.join(backupDir, "MANIFEST.json");
  if (!fs.existsSync(manifestPath)) {
    throw new Error("Invalid backup: MANIFEST.json not found");
  }

  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));

  // Create safety backup before restore
  const safetyBackup = createBackup("pre-restore");

  // Restore files
  const dirs = [
    "agents",
    "rules",
    "skills",
    "templates",
    "scripts",
    "hooks",
    "reference",
  ];
  const files = ["CLAUDE.md"];

  if (onlyFiles && onlyFiles.length > 0) {
    // Selective restore
    for (const file of onlyFiles) {
      const srcFile = path.join(backupDir, file);
      const destFile = path.join(CLAUDE_HOME, file);

      if (!fs.existsSync(srcFile)) {
        console.warn(`Warning: ${file} not found in backup, skipping`);
        continue;
      }

      const destDir = path.dirname(destFile);
      fs.mkdirSync(destDir, { recursive: true });
      fs.copyFileSync(srcFile, destFile);
    }
  } else {
    // Full restore
    for (const dir of dirs) {
      const srcDir = path.join(backupDir, dir);
      const destDir = path.join(CLAUDE_HOME, dir);

      if (fs.existsSync(srcDir)) {
        // Remove existing
        if (fs.existsSync(destDir)) {
          fs.rmSync(destDir, { recursive: true, force: true });
        }
        // Copy from backup
        copyRecursive(srcDir, destDir);
      }
    }

    for (const file of files) {
      const srcFile = path.join(backupDir, file);
      const destFile = path.join(CLAUDE_HOME, file);

      if (fs.existsSync(srcFile)) {
        fs.copyFileSync(srcFile, destFile);
      }
    }
  }

  return safetyBackup;
}

function copyRecursive(src, dest) {
  if (!fs.existsSync(src)) return;

  fs.mkdirSync(dest, { recursive: true });

  const items = fs.readdirSync(src);
  for (const item of items) {
    const srcPath = path.join(src, item);
    const destPath = path.join(dest, item);
    const stat = fs.statSync(srcPath);

    if (stat.isDirectory()) {
      copyRecursive(srcPath, destPath);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

function listBackups() {
  const homeDir = os.homedir();
  const backups = [];

  const items = fs.readdirSync(homeDir);
  for (const item of items) {
    if (item.startsWith(".claude-backup-")) {
      const backupPath = path.join(homeDir, item);
      const manifestPath = path.join(backupPath, "MANIFEST.json");

      if (fs.existsSync(manifestPath)) {
        const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
        backups.push({
          path: backupPath,
          name: item,
          timestamp: manifest.timestamp,
          reason: manifest.reason,
          fileCount: manifest.file_count,
          size: manifest.total_size,
        });
      }
    }
  }

  // Sort by timestamp descending
  backups.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

  return backups;
}

function cleanOldBackups(daysToKeep = 30) {
  const backups = listBackups();
  const cutoffDate = new Date();
  cutoffDate.setDate(cutoffDate.getDate() - daysToKeep);

  const removed = [];

  for (const backup of backups) {
    const backupDate = new Date(backup.timestamp);
    if (backupDate < cutoffDate) {
      fs.rmSync(backup.path, { recursive: true, force: true });
      removed.push(backup.name);
    }
  }

  return removed;
}

module.exports = {
  createBackup,
  restoreBackup,
  listBackups,
  cleanOldBackups,
  getFileSHA256,
};
