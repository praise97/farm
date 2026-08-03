const identifierInput = document.getElementById('identifier');
const passwordInput = document.getElementById('password');
const togglePasswordButton = document.getElementById('togglePassword');
const passwordIcon = document.getElementById('pwIcon');
const loginForm = document.getElementById('loginForm');
const forgotPasswordLink = document.querySelector('.forgot-link');
const createAccountButton = document.getElementById('createAccountBtn');
const demoAccessButton = document.getElementById('demoAccessBtn');
const dashboardUrl = 'index.html';
const signupUrl = 'signup.html';
const resetPasswordUrl = 'reset-password.html';
const savedIdentifier = localStorage.getItem('farmSmartPro.lastIdentifier') || localStorage.getItem('farmSmartPro.lastEmail');

if (savedIdentifier && identifierInput) {
  identifierInput.value = savedIdentifier;
}

if (togglePasswordButton && passwordInput && passwordIcon) {
  togglePasswordButton.addEventListener('click', () => {
    const isHidden = passwordInput.type === 'password';
    passwordInput.type = isHidden ? 'text' : 'password';
    passwordIcon.classList.toggle('fa-eye', !isHidden);
    passwordIcon.classList.toggle('fa-eye-slash', isHidden);
  });
}

if (forgotPasswordLink) {
  forgotPasswordLink.addEventListener('click', (event) => {
    event.preventDefault();
    window.location.href = resetPasswordUrl;
  });
}

if (createAccountButton) {
  createAccountButton.addEventListener('click', () => {
    window.location.href = signupUrl;
  });
}

if (demoAccessButton) {
  demoAccessButton.addEventListener('click', () => {
    if (identifierInput) {
      identifierInput.value = 'johnfarmer';
    }

    if (passwordInput) {
      passwordInput.value = 'password';
    }

    window.location.href = dashboardUrl;
  });
}

if (loginForm) {
  loginForm.addEventListener('submit', (event) => {
    event.preventDefault();

    const identifier = identifierInput ? identifierInput.value.trim().toLowerCase() : '';
    const password = passwordInput.value.trim();

    if (!identifier || !password) {
      alert('Please enter both your email or username and password.');
      return;
    }

    const validIdentifiers = new Set(['farmer@example.com', 'johnfarmer']);

    if (validIdentifiers.has(identifier) && password === 'password') {
      localStorage.setItem('farmSmartPro.lastIdentifier', identifierInput.value.trim());
      window.location.href = dashboardUrl;
      return;
    }

    alert('Invalid credentials. Try farmer@example.com or johnfarmer with password / password for the demo.');
  });
}
