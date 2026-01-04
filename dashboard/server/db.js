// Database Configuration and Query Function

const { execSync } = require('child_process');

const CLAUDE_HOME = process.env.HOME + '/.claude';
const DB_FILE = CLAUDE_HOME + '/data/dashboard.db';

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

module.exports = { query, CLAUDE_HOME, DB_FILE };
