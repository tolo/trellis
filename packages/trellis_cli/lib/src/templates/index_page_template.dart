/// Generates the templates/pages/index.html content.
///
/// Demonstrates `tl:extends`, `tl:define`, `tl:each`, `tl:text`, `tl:fragment`,
/// and HTMX interactions (hx-get, hx-post, hx-target, hx-swap) with CSRF.
String indexPageTemplate() => r'''
<html tl:extends="layouts/base.html">
<body>
  <main tl:define="content">
    <section class="hero">
      <h2 tl:text="${message}">Welcome message</h2>
    </section>

    <section class="features">
      <h3>Features</h3>
      <ul>
        <li tl:each="feature : ${features}">
          <strong tl:text="${feature.name}">Feature name</strong>
          <span tl:text="${feature.description}">Feature description</span>
        </li>
      </ul>
    </section>

    <!-- HTMX hx-get demo — loads server status on click -->
    <section class="status">
      <h3>Server Status</h3>
      <button hx-get="/status" hx-target="#status-result" hx-swap="innerHTML">Check Status</button>
      <div id="status-result" class="result">
        <p class="placeholder">Click to check server status.</p>
      </div>
    </section>

    <!-- HTMX hx-post demo — greeting form with CSRF protection -->
    <section class="greeting">
      <h3>Try HTMX</h3>
      <form hx-post="/greet" hx-target="#greeting-result" hx-swap="innerHTML">
        <input type="hidden" name="_csrf" tl:attr="value=${csrfToken}">
        <label for="name">Your name:</label>
        <input type="text" id="name" name="name" placeholder="Enter your name" required>
        <button type="submit">Greet</button>
      </form>
      <div id="greeting-result" class="result">
        <p class="placeholder">Submit the form to see a greeting.</p>
      </div>
    </section>
  </main>
</body>
</html>
''';
