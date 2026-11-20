(() => {
  let saved;
  try {
    const value = localStorage.getItem('trellis-theme');
    if (value === 'dark' || value === 'light') saved = value;
  } catch (_) {}
  document.documentElement.dataset.theme = saved || (matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light");
})();
