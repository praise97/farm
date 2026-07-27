const dateLabel = document.getElementById('dashboard-date');
const logoutButton = document.querySelector('.logout');

if (dateLabel) {
  const currentDate = new Date();
  dateLabel.textContent = currentDate.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
}

document.querySelectorAll('.sidebar nav a').forEach((link) => {
  link.addEventListener('click', (event) => {
    const href = link.getAttribute('href');

    if (!href || href === '#') {
      event.preventDefault();
    }

    document.querySelectorAll('.sidebar nav a.active').forEach((activeLink) => {
      activeLink.classList.remove('active');
    });
    link.classList.add('active');
  });
});

if (logoutButton) {
  logoutButton.addEventListener('click', () => {
    localStorage.removeItem('farmSmartPro.lastEmail');
    localStorage.removeItem('farmSmartPro.lastIdentifier');
    sessionStorage.clear();
    window.location.href = 'login.html';
  });
}
