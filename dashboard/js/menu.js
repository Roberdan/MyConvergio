// Mobile Hamburger Menu Handler

let mobileMenuOpen = false;

// Initialize hamburger menu
function initHamburgerMenu() {
  const hamburgerBtn = document.getElementById('hamburgerMenu');
  const navMenu = document.getElementById('navMenu');

  if (!hamburgerBtn || !navMenu) return;

  // Toggle menu on hamburger click
  hamburgerBtn.addEventListener('click', toggleMobileMenu);

  // Close menu when clicking on a nav link
  const navLinks = navMenu.querySelectorAll('a');
  navLinks.forEach(link => {
    link.addEventListener('click', closeMobileMenu);
  });

  // Close menu when clicking outside
  document.addEventListener('click', (e) => {
    if (!hamburgerBtn.contains(e.target) && !navMenu.contains(e.target)) {
      closeMobileMenu();
    }
  });

  // Close menu on escape key
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && mobileMenuOpen) {
      closeMobileMenu();
    }
  });

  // Handle window resize - close menu if switching to desktop
  window.addEventListener('resize', () => {
    if (window.innerWidth > 767) {
      closeMobileMenu();
    }
  });
}

// Toggle mobile menu
function toggleMobileMenu(e) {
  e?.preventDefault?.();
  if (mobileMenuOpen) {
    closeMobileMenu();
  } else {
    openMobileMenu();
  }
}

// Open mobile menu
function openMobileMenu() {
  const hamburgerBtn = document.getElementById('hamburgerMenu');
  if (!hamburgerBtn) return;

  hamburgerBtn.classList.add('active');
  document.body.classList.add('menu-open');
  mobileMenuOpen = true;

  // Focus first menu item for accessibility
  const firstLink = document.querySelector('#navMenu a');
  if (firstLink) {
    setTimeout(() => firstLink.focus(), 100);
  }
}

// Close mobile menu
function closeMobileMenu() {
  const hamburgerBtn = document.getElementById('hamburgerMenu');
  if (!hamburgerBtn) return;

  hamburgerBtn.classList.remove('active');
  document.body.classList.remove('menu-open');
  mobileMenuOpen = false;
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', initHamburgerMenu);

// Also initialize if this script loads after DOM ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initHamburgerMenu);
} else {
  initHamburgerMenu();
}
