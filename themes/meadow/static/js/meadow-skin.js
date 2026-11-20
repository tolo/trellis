(() => {
  let saved;
  try {
    const value = localStorage.getItem('meadow-skin');
    if (value === 'dark' || value === 'light') saved = value;
  } catch (_) {}
  document.documentElement.dataset.skin = saved || '';
})();
