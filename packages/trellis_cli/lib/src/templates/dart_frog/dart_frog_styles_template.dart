/// Generates the public/styles.css content for a Dart Frog + Trellis project.
///
/// Dart Frog serves static files from the `public/` directory by default.
String dartFrogStylesTemplate() => '''
/* Trellis + Dart Frog starter styles */
:root {
  --color-primary: #2563eb;
  --color-bg: #fafafa;
  --color-text: #1a1a1a;
  --color-border: #e0e0e0;
  --color-muted: #666;
  --color-success: #16a34a;
  --radius: 8px;
}

*, *::before, *::after { box-sizing: border-box; }

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
nav a { color: var(--color-primary); text-decoration: none; margin-right: 1rem; }
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

/* Todo section */
.todos form {
  display: flex;
  gap: 0.5rem;
  margin-bottom: 1rem;
}
.todos input[type="text"] {
  flex: 1;
  padding: 0.4rem 0.75rem;
  border: 1px solid var(--color-border);
  border-radius: var(--radius);
  font-size: 1rem;
}
.todos button {
  padding: 0.4rem 1rem;
  background: var(--color-primary);
  color: white;
  border: none;
  border-radius: var(--radius);
  cursor: pointer;
  font-size: 0.875rem;
}
.todos button:hover { opacity: 0.9; }

.todo-items { list-style: none; padding: 0; }
.todo-items li {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.75rem 0;
  border-bottom: 1px solid var(--color-border);
}
.todo-items li.done span:first-child {
  text-decoration: line-through;
  color: var(--color-muted);
}
.actions { display: flex; gap: 0.25rem; }
.actions button {
  padding: 0.25rem 0.5rem;
  font-size: 0.75rem;
  background: var(--color-border);
  color: var(--color-text);
}
.actions button:first-child:hover { background: var(--color-success); color: white; }
.actions button:last-child:hover { background: #dc2626; color: white; }

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
