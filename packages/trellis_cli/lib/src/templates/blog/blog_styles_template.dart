/// Generates the static/styles.css content for a blog project.
///
/// Provides clean, minimal blog styling: typography, layout, navigation,
/// post formatting, tags, pagination, and footer.
String blogStylesTemplate() => '''
/* ── Reset & base ─────────────────────────────────────────────── */
*, *::before, *::after { box-sizing: border-box; }

body {
  font-family: system-ui, -apple-system, sans-serif;
  color: #1f2937;
  max-width: 800px;
  margin: 0 auto;
  padding: 1rem 1.5rem;
  line-height: 1.7;
}

/* ── Header / nav ─────────────────────────────────────────────── */
header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem 0;
  border-bottom: 1px solid #e5e7eb;
  margin-bottom: 2.5rem;
}

.site-title {
  font-weight: 700;
  font-size: 1.25rem;
  text-decoration: none;
  color: #1f2937;
}

header nav a {
  margin-left: 1.25rem;
  color: #6b7280;
  text-decoration: none;
  font-size: 0.9rem;
}

header nav a:hover { color: #2563eb; }

/* ── Typography ───────────────────────────────────────────────── */
h1 { font-size: 2rem; margin: 0 0 0.5rem; }
h2 { font-size: 1.5rem; margin: 2rem 0 0.75rem; }
h3 { font-size: 1.2rem; margin: 1.5rem 0 0.5rem; }

a { color: #2563eb; }
a:hover { text-decoration: none; }

p { margin: 0.75rem 0; }
pre, code { font-family: ui-monospace, monospace; font-size: 0.9em; }
pre { background: #f3f4f6; padding: 1rem; border-radius: 6px; overflow-x: auto; }
code { background: #f3f4f6; padding: 0.1em 0.3em; border-radius: 3px; }

/* ── Post list ────────────────────────────────────────────────── */
.post-list {
  list-style: none;
  padding: 0;
  margin: 0;
}

.post-list li {
  padding: 1.25rem 0;
  border-bottom: 1px solid #e5e7eb;
}

.post-list article h2 { margin: 0 0 0.25rem; font-size: 1.2rem; }
.post-list article h3 { margin: 0 0 0.25rem; font-size: 1.1rem; }
.post-list article h2 a, .post-list article h3 a { text-decoration: none; }
.post-list article h2 a:hover, .post-list article h3 a:hover { text-decoration: underline; }
.post-list time { display: block; color: #6b7280; font-size: 0.875rem; margin-bottom: 0.4rem; }
.post-list p { margin: 0; color: #4b5563; font-size: 0.95rem; }

/* ── Post ─────────────────────────────────────────────────────── */
.post header { border: none; margin-bottom: 1.5rem; display: block; }
.post header h1 { margin-bottom: 0.25rem; }
.post header time { color: #6b7280; font-size: 0.875rem; }

/* ── Tags ─────────────────────────────────────────────────────── */
.tags {
  list-style: none;
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
  padding: 0;
  margin: 0.5rem 0;
}

.tags li a {
  background: #eff6ff;
  color: #2563eb;
  padding: 0.2rem 0.6rem;
  border-radius: 9999px;
  font-size: 0.8rem;
  text-decoration: none;
}

.tags li a:hover { background: #dbeafe; }

/* ── Pagination ───────────────────────────────────────────────── */
.pagination {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 2rem 0 1rem;
  color: #6b7280;
  font-size: 0.9rem;
}

/* ── Footer ───────────────────────────────────────────────────── */
footer {
  margin-top: 4rem;
  padding-top: 1rem;
  border-top: 1px solid #e5e7eb;
  color: #9ca3af;
  font-size: 0.875rem;
}

/* ── Hero ─────────────────────────────────────────────────────── */
.hero {
  margin-bottom: 2.5rem;
  padding: 2rem 0;
  border-bottom: 1px solid #e5e7eb;
}

.hero h1 { font-size: 2.5rem; margin-bottom: 0.5rem; }
.hero p { color: #4b5563; font-size: 1.1rem; }

.recent-posts h2 { margin-bottom: 1rem; }
''';
