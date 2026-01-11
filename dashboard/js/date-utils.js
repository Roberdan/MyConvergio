// Date Utilities - Handle UTC timestamps from SQLite
// SQLite datetime('now') stores UTC without 'Z' suffix

const DateUtils = {
  // Parse timestamp from DB as UTC
  parseUTC(dateStr) {
    if (!dateStr) return null;
    // If already has timezone info or ISO format, use as-is
    if (dateStr.includes('Z') || dateStr.includes('+') || dateStr.includes('T')) {
      return new Date(dateStr);
    }
    // SQLite format: "YYYY-MM-DD HH:MM:SS" - treat as UTC
    return new Date(dateStr.replace(' ', 'T') + 'Z');
  },

  // Format to local time string
  formatLocal(dateStr, options = {}) {
    const date = this.parseUTC(dateStr);
    if (!date || isNaN(date.getTime())) return '';
    const defaultOpts = { hour: '2-digit', minute: '2-digit' };
    return date.toLocaleString('it-IT', { ...defaultOpts, ...options });
  },

  // Format to local date string
  formatLocalDate(dateStr, options = {}) {
    const date = this.parseUTC(dateStr);
    if (!date || isNaN(date.getTime())) return '';
    const defaultOpts = { day: '2-digit', month: 'short' };
    return date.toLocaleDateString('it-IT', { ...defaultOpts, ...options });
  },

  // Format to local time only
  formatLocalTime(dateStr, options = {}) {
    const date = this.parseUTC(dateStr);
    if (!date || isNaN(date.getTime())) return '';
    const defaultOpts = { hour: '2-digit', minute: '2-digit' };
    return date.toLocaleTimeString('it-IT', { ...defaultOpts, ...options });
  }
};

window.DateUtils = DateUtils;
