// Dropdown Management - Unified dropdown handler
// Closes all dropdowns when clicking outside

const DropdownManager = {
  registered: [
    { menu: 'projectMenu', trigger: '.logo, .project-name' },
    { menu: 'waveMenuList', trigger: '.wave-menu-trigger' },
    { menu: 'gitBranchList', trigger: '#gitBranchToggle' },
    { menu: 'bugDropdownMenu', trigger: '.bug-dropdown-toggle' }
  ],

  closeAll(exceptMenu = null) {
    this.registered.forEach(({ menu }) => {
      if (menu === exceptMenu) return;
      const el = document.getElementById(menu);
      if (el) {
        el.style.display = 'none';
        el.classList.remove('is-open');
      }
    });
  },

  handleClick(e) {
    let clickedInDropdown = false;
    let clickedMenuId = null;

    this.registered.forEach(({ menu, trigger }) => {
      const menuEl = document.getElementById(menu);
      const triggerEls = document.querySelectorAll(trigger);

      if (menuEl?.contains(e.target)) {
        clickedInDropdown = true;
        clickedMenuId = menu;
      }

      triggerEls.forEach(triggerEl => {
        if (triggerEl?.contains(e.target)) {
          clickedInDropdown = true;
          clickedMenuId = menu;
        }
      });
    });

    if (!clickedInDropdown) {
      this.closeAll();
    }
  },

  init() {
    document.addEventListener('click', (e) => this.handleClick(e));
  }
};

window.DropdownManager = DropdownManager;
DropdownManager.init();
