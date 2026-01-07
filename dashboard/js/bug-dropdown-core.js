/**
 * Bug Dropdown - Core Module
 * Class definition, constructor, storage, event binding
 */
class BugDropdown {
  constructor() {
    this.bugs = this.loadBugs();
    this.dropdown = document.querySelector('.bug-dropdown');
    this.toggle = this.dropdown?.querySelector('.bug-dropdown-toggle');
    this.menu = this.dropdown?.querySelector('.bug-dropdown-menu');
    this.list = this.dropdown?.querySelector('.bug-list');
    this.addBtn = this.dropdown?.querySelector('.add-bug-btn');
    this.archiveBtn = this.dropdown?.querySelector('.archive-btn');
    if (!this.dropdown) {
      console.warn('Bug dropdown component not found in DOM');
      return;
    }
    this.bindEvents();
    this.render();
  }
  loadBugs() {
    try {
      const saved = localStorage.getItem('myconvergio-bugs');
      return saved ? JSON.parse(saved) : [];
    } catch (e) {
      console.error('Failed to load bugs from localStorage:', e);
      return [];
    }
  }
  saveBugs() {
    try {
      localStorage.setItem('myconvergio-bugs', JSON.stringify(this.bugs));
    } catch (e) {
      console.error('Failed to save bugs to localStorage:', e);
      this.showToast('Storage quota exceeded', 'error');
    }
  }
  bindEvents() {
    // Toggle dropdown menu
    this.toggle.addEventListener('click', (e) => {
      e.stopPropagation();
      const wasOpen = this.menu.classList.contains('is-open');
      if (!wasOpen && typeof closeAllDropdowns === 'function') {
        closeAllDropdowns('bugDropdownMenu');
      }
      const isOpen = this.menu.classList.toggle('is-open');
      this.toggle.setAttribute('aria-expanded', isOpen);
    });
    // Add bug button
    this.addBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      this.addBug();
    });
    // Archive button
    this.archiveBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      this.archiveCompleted();
    });
    // Close dropdown when clicking outside
    document.addEventListener('click', (e) => {
      if (!this.dropdown.contains(e.target)) {
        this.menu.classList.remove('is-open');
        this.toggle.setAttribute('aria-expanded', 'false');
      }
    });
    // Close dropdown on Escape key
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && this.menu.classList.contains('is-open')) {
        this.menu.classList.remove('is-open');
        this.toggle.setAttribute('aria-expanded', 'false');
      }
    });
  }
  getAppVersion() {
    return localStorage.getItem('app-version') || '1.0.0';
  }
}

