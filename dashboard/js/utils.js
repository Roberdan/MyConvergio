// Utility Functions for Dashboard

/**
 * Global Logger - Replaces console.log for better debugging and production use
 * Levels: DEBUG, INFO, WARN, ERROR
 */
const Logger = {
  level: "INFO",
  levels: ["DEBUG", "INFO", "WARN", "ERROR"],
  enabled: true,

  setLevel(level) {
    if (this.levels.includes(level)) {
      this.level = level;
    }
  },

  shouldLog(level) {
    const order = this.levels.indexOf(level);
    const currentOrder = this.levels.indexOf(this.level);
    return order >= currentOrder && this.enabled;
  },

  debug(...args) {
    if (this.shouldLog("DEBUG")) {
      console.debug("[DEBUG]", ...args);
    }
  },

  info(...args) {
    if (this.shouldLog("INFO")) {
      console.info("[INFO]", ...args);
    }
  },

  warn(...args) {
    if (this.shouldLog("WARN")) {
      console.warn("[WARN]", ...args);
    }
  },

  error(...args) {
    if (this.shouldLog("ERROR")) {
      console.error("[ERROR]", ...args);
    }
  },

  time(label) {
    console.time(label);
  },

  timeEnd(label) {
    console.timeEnd(label);
  },
};

// Make logger available globally
window.Logger = Logger;

// Development mode - set to DEBUG to see all logs
if (window.location.search.includes("debug=true")) {
  Logger.setLevel("DEBUG");
}

/**
 * Escape HTML special characters to prevent XSS attacks
 * @param {string} text - Text to escape
 * @returns {string} Escaped HTML-safe text
 */
function escapeHtml(text) {
  if (!text) return "";

  const div = document.createElement("div");
  div.textContent = text;
  return div.innerHTML;
}

/**
 * Sanitize HTML input by removing potentially dangerous tags
 * @param {string} html - HTML string to sanitize
 * @returns {string} Sanitized HTML
 */
function sanitizeHtml(html) {
  if (!html) return "";

  // Create a temporary div to parse HTML
  const temp = document.createElement("div");
  temp.innerHTML = html;

  // Remove script tags and event handlers
  const scripts = temp.querySelectorAll("script");
  scripts.forEach((script) => script.remove());

  // Remove event handlers from all elements
  const allElements = temp.querySelectorAll("*");
  allElements.forEach((el) => {
    // Remove inline event handlers
    Array.from(el.attributes).forEach((attr) => {
      if (attr.name.startsWith("on")) {
        el.removeAttribute(attr.name);
      }
    });
  });

  return temp.innerHTML;
}

function decodeHtmlEntities(text) {
  const textarea = document.createElement("textarea");
  textarea.innerHTML = text;
  return textarea.value;
}

function truncateText(text, maxLength, suffix = "...") {
  if (!text || text.length <= maxLength) return text;
  return text.substring(0, maxLength - suffix.length) + suffix;
}

function capitalize(text) {
  if (!text) return "";
  return text.charAt(0).toUpperCase() + text.slice(1).toLowerCase();
}

function formatNumber(num) {
  if (typeof num !== "number") return "0";
  return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

function formatBytes(bytes, decimals = 2) {
  if (bytes === 0) return "0 Bytes";

  const k = 1024;
  const dm = decimals < 0 ? 0 : decimals;
  const sizes = ["Bytes", "KB", "MB", "GB"];
  const i = Math.floor(Math.log(bytes) / Math.log(k));

  return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + " " + sizes[i];
}

function isInViewport(el) {
  if (!el) return false;
  const rect = el.getBoundingClientRect();
  return (
    rect.top >= 0 &&
    rect.left >= 0 &&
    rect.bottom <=
      (window.innerHeight || document.documentElement.clientHeight) &&
    rect.right <= (window.innerWidth || document.documentElement.clientWidth)
  );
}

function deepClone(obj) {
  if (obj === null || typeof obj !== "object") return obj;
  if (obj instanceof Date) return new Date(obj.getTime());
  if (obj instanceof Array) return obj.map((item) => deepClone(item));
  if (obj instanceof Object) {
    const cloned = {};
    for (const key in obj) {
      if (obj.hasOwnProperty(key)) {
        cloned[key] = deepClone(obj[key]);
      }
    }
    return cloned;
  }
}

function debounce(func, delay) {
  let timeoutId;
  return function (...args) {
    clearTimeout(timeoutId);
    timeoutId = setTimeout(() => func.apply(this, args), delay);
  };
}

function throttle(func, limit) {
  let inThrottle;
  return function (...args) {
    if (!inThrottle) {
      func.apply(this, args);
      inThrottle = true;
      setTimeout(() => (inThrottle = false), limit);
    }
  };
}
