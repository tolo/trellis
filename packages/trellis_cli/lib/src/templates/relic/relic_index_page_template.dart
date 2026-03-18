/// Generates the templates/index.html content for a Relic + Trellis project.
///
/// Demonstrates template inheritance, HTMX fragment rendering, and the
/// counter interaction pattern.
String relicIndexPageTemplate() => r'''
<html tl:extends="base.html">
<body>
  <main tl:define="content">
    <div tl:fragment="page-content">
      <h1>Welcome to Trellis + Relic</h1>
      <p>This is a Relic web application with Trellis templates and HTMX
         for interactive UI updates — no JavaScript frameworks needed.</p>

      <section tl:fragment="counter" id="counter" class="counter-section">
        <h2>HTMX Counter</h2>
        <div class="counter-display">
          <span class="counter-value" tl:text="${count}">0</span>
        </div>
        <div class="counter-controls">
          <button hx-post="/counter/decrement"
                  hx-target="#counter"
                  hx-swap="outerHTML"
                  tl:classappend="${isZero} ? 'disabled' : ''"
                  >-</button>
          <button hx-post="/counter/reset"
                  hx-target="#counter"
                  hx-swap="outerHTML"
                  >Reset</button>
          <button hx-post="/counter/increment"
                  hx-target="#counter"
                  hx-swap="outerHTML"
                  >+</button>
        </div>
        <p class="counter-hint">
          Each button click sends a POST request. The server renders only
          this counter section and returns it as an HTML fragment.
        </p>
      </section>

      <section class="features">
        <h2>What This Template Shows</h2>
        <ul>
          <li><strong>Relic router</strong> with path-based routing</li>
          <li><strong>No DI</strong> — engine passed explicitly to handlers</li>
          <li><strong>HTMX fragments</strong> — partial page updates without JavaScript</li>
          <li><strong>Template inheritance</strong> — <code>tl:extends</code> + <code>tl:define</code></li>
          <li><strong>Security headers</strong> — via <code>trellisSecurityHeaders()</code></li>
          <li><strong>Natural templates</strong> — valid HTML, browsable as prototypes</li>
        </ul>
      </section>
    </div>
  </main>
</body>
</html>
''';
