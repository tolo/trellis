/// Generates the templates/pages/index.html content.
///
/// Demonstrates template inheritance, HTMX fragment rendering, and the counter
/// interaction pattern used across the starter templates.
String indexPageTemplate() => r'''
<html tl:extends="layouts/base.html">
<body>
  <main tl:define="content">
    <div tl:fragment="page-content">
      <h1>Welcome to Trellis + Shelf</h1>
      <p>This is a Shelf web application with Trellis templates and HTMX
         for interactive UI updates — no JavaScript frameworks needed.</p>

      <section tl:fragment="counter" id="counter" class="counter-section">
        <h2>HTMX Counter</h2>
        <div class="counter-display">
          <span class="counter-value" tl:text="${count}">0</span>
        </div>
        <div class="counter-controls">
          <button type="button"
                  hx-post="/counter/decrement"
                  hx-target="#counter"
                  hx-swap="outerHTML"
                  hx-include="[name='_csrf']"
                  tl:classappend="${isZero} ? 'disabled' : ''">-</button>
          <button type="button"
                  hx-post="/counter/reset"
                  hx-target="#counter"
                  hx-swap="outerHTML"
                  hx-include="[name='_csrf']">Reset</button>
          <button type="button"
                  hx-post="/counter/increment"
                  hx-target="#counter"
                  hx-swap="outerHTML"
                  hx-include="[name='_csrf']">+</button>
        </div>
        <input type="hidden" name="_csrf" tl:attr="value=${csrfToken}">
        <p class="counter-hint">
          Each button click sends a POST request. The server renders only
          this counter section and returns it as an HTML fragment.
        </p>
      </section>

      <section class="features">
        <h2>What This Template Shows</h2>
        <ul>
          <li tl:each="feature : ${features}">
            <strong tl:text="${feature.name}">Feature name</strong>
            <span tl:text="${feature.description}">Feature description</span>
          </li>
        </ul>
      </section>
    </div>
  </main>
</body>
</html>
''';
