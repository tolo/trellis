/// Generates the static/styles.css content.
///
/// CSS custom properties, responsive layout, form styling. Under 100 lines.
String stylesTemplate() => '''
/* Trellis starter styles */
:root {
  --color-primary: #2563eb;
  --color-bg: #fafafa;
  --color-text: #1a1a1a;
  --color-border: #e0e0e0;
  --color-muted: #666;
  --radius: 8px;
}

*,
*::before,
*::after {
  box-sizing: border-box;
}

body {
  font-family: system-ui, -apple-system, sans-serif;
  line-height: 1.6;
  max-width: 800px;
  margin: 0 auto;
  padding: 2rem;
  color: var(--color-text);
  background: var(--color-bg);
}

header {
  border-bottom: 2px solid var(--color-border);
  padding-bottom: 1rem;
  margin-bottom: 2rem;
}

header h1 { margin: 0; color: var(--color-primary); }

nav a {
  color: var(--color-primary);
  text-decoration: none;
  margin-right: 1rem;
}

nav a:hover { text-decoration: underline; }

.hero {
  background: #eff6ff;
  padding: 2rem;
  border-radius: var(--radius);
  margin-bottom: 2rem;
}

.features ul { list-style: none; padding: 0; }

.features li {
  padding: 0.75rem 0;
  border-bottom: 1px solid var(--color-border);
}

.features strong { display: block; color: var(--color-primary); }

.greeting form {
  display: flex;
  gap: 0.5rem;
  align-items: end;
  margin-bottom: 1rem;
}

.greeting label { font-weight: 600; }

.greeting input[type="text"] {
  padding: 0.4rem 0.75rem;
  border: 1px solid var(--color-border);
  border-radius: var(--radius);
  font-size: 1rem;
}

.greeting button {
  padding: 0.4rem 1rem;
  background: var(--color-primary);
  color: white;
  border: none;
  border-radius: var(--radius);
  cursor: pointer;
  font-size: 1rem;
}

.greeting button:hover { opacity: 0.9; }

.result { padding: 1rem 0; }

.placeholder { color: var(--color-muted); font-style: italic; }

footer {
  margin-top: 3rem;
  padding-top: 1rem;
  border-top: 2px solid var(--color-border);
  color: var(--color-muted);
  font-size: 0.875rem;
}

footer a { color: var(--color-primary); }
''';
