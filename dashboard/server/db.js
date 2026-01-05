// Database Configuration and Query Function

const { execSync } = require('child_process');

const CLAUDE_HOME = process.env.HOME + '/.claude';
const DB_FILE = CLAUDE_HOME + '/data/dashboard.db';

// Escape string for SQL to prevent injection
function escapeSQL(str) {
  if (str === null || str === undefined) return null;
  if (typeof str !== 'string') str = String(str);
  return str.replace(/'/g, "''");
}

// Execute SQLite query and return JSON
function query(sql) {
  try {
    const result = execSync(`sqlite3 -json "${DB_FILE}" "${sql.replace(/"/g, '\\"')}"`, {
      encoding: 'utf-8',
      maxBuffer: 10 * 1024 * 1024
    });
    return JSON.parse(result || '[]');
  } catch (e) {
    console.error('DB Error:', e.message);
    return [];
  }
}

module.exports = { query, escapeSQL, CLAUDE_HOME, DB_FILE };
