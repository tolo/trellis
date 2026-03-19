/// Generates the public/styles.css content for a Dart Frog + Trellis project.
///
/// Dart Frog serves static files from the `public/` directory by default.
String dartFrogStylesTemplate() => '''
/* Reset and base */
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

body {
  font-family: system-ui, -apple-system, sans-serif;
  line-height: 1.6;
  color: #333;
  max-width: 800px;
  margin: 0 auto;
  padding: 0 1rem;
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

/* Navigation */
nav {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem 0;
  border-bottom: 1px solid #e0e0e0;
}

nav .brand {
  font-weight: 700;
  font-size: 1.25rem;
  color: #2563eb;
  text-decoration: none;
}

.nav-links { display: flex; gap: 1.5rem; }
.nav-links a { color: #555; text-decoration: none; }
.nav-links a:hover { color: #2563eb; }

/* Main content */
main { flex: 1; padding: 2rem 0; }

h1 { margin-bottom: 1rem; color: #111; }
h2 { margin: 1.5rem 0 0.75rem; color: #222; }
p { margin-bottom: 1rem; }

/* Counter */
.counter-section {
  background: #f8f9fa;
  border-radius: 8px;
  padding: 2rem;
  margin: 2rem 0;
  text-align: center;
}

.counter-display { margin: 1.5rem 0; }

.counter-value {
  font-size: 3rem;
  font-weight: 700;
  color: #2563eb;
}

.counter-controls {
  display: flex;
  justify-content: center;
  gap: 0.75rem;
  margin: 1rem 0;
}

.counter-controls button {
  padding: 0.5rem 1.5rem;
  font-size: 1.25rem;
  border: 1px solid #d0d0d0;
  border-radius: 6px;
  background: #fff;
  cursor: pointer;
  transition: background 0.15s;
}

.counter-controls button:hover { background: #e8e8e8; }
.counter-controls button.disabled { opacity: 0.4; pointer-events: none; }

.counter-hint { font-size: 0.875rem; color: #888; margin-top: 1rem; }

/* Features list */
.features ul { padding-left: 1.5rem; }
.features li { margin-bottom: 0.5rem; }

/* Footer */
footer {
  padding: 1.5rem 0;
  border-top: 1px solid #e0e0e0;
  text-align: center;
  font-size: 0.875rem;
  color: #888;
}

footer a { color: #2563eb; text-decoration: none; }
footer a:hover { text-decoration: underline; }

/* Code */
code {
  background: #f0f0f0;
  padding: 0.15rem 0.35rem;
  border-radius: 3px;
  font-size: 0.9em;
}
''';
