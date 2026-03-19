/// Generates the templates/pages/about.html content for a Shelf + Trellis project.
///
/// Explains the Shelf-specific patterns used in the starter: middleware
/// ordering, request context, CSRF protection, and dev-mode hot reload.
String aboutPageTemplate() => r'''
<html tl:extends="layouts/base.html">
<body>
  <main tl:define="content">
    <div tl:fragment="page-content">
      <h1>About This App</h1>

      <h2>Shelf Pipeline</h2>
      <p>Shelf composes your application as a middleware pipeline around a final
         handler. This starter wraps the router with logging, security headers,
         Trellis engine injection, CSRF protection, and optional dev-mode live
         reload. The order matters because each middleware builds on the work
         done by the previous stage.</p>

      <h2>Request Context</h2>
      <p><code>trellisEngine(engine)</code> stores the Trellis engine in the Shelf
         request context, so handlers can call <code>renderPage()</code> and
         <code>renderFragment()</code> without reaching for globals. The helpers
         also merge request-scoped values like the CSRF token into the template
         context automatically.</p>

      <h2>Middleware Ordering</h2>
      <p><code>trellisSecurityHeaders()</code> sits near the outside of the
         pipeline so every response gets the same header policy. The Trellis
         engine middleware runs before <code>trellisCsrf()</code> so response
         helpers invoked by CSRF-aware handlers can still resolve the engine
         from the request context.</p>

      <h2>CSRF Protection</h2>
      <p><code>trellisCsrf()</code> uses the double-submit cookie pattern.
         Safe requests mint a signed token cookie, and HTMX sends that token
         back on mutations via the <code>X-CSRF-Token</code> header. Regular
         forms still include a hidden <code>_csrf</code> field as a fallback.</p>

      <h2>Dev Hot Reload</h2>
      <p>When you run the starter with <code>--dev</code> or set
         <code>DEV=true</code>, <code>devMiddleware()</code> watches the template
         directory and injects a small SSE client into HTML responses. Template
         edits refresh in the browser without restarting the server.</p>
    </div>
  </main>
</body>
</html>
''';
