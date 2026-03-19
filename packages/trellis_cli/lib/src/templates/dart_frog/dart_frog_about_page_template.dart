/// Generates the templates/pages/about.html content for a Dart Frog + Trellis project.
///
/// Explains the Dart Frog-specific patterns used in the starter: providers,
/// file-based routing, middleware chaining, CSRF protection, and hot reload.
String dartFrogAboutPageTemplate() => r'''
<html tl:extends="layouts/base.html">
<body>
  <main tl:define="content">
    <div tl:fragment="page-content">
      <h1>About This App</h1>

      <h2>Provider-Based Dependency Injection</h2>
      <p>Dart Frog uses providers for dependency injection. The Trellis engine is
         registered once in <code>routes/_middleware.dart</code> with
         <code>trellisProvider(_engine)</code> and then read automatically by
         <code>renderPage()</code> and <code>renderFragment()</code> in each
         route handler.</p>

      <h2>File-Based Routing</h2>
      <p>Routes map directly to files in the <code>routes/</code> directory.
         <code>routes/index.dart</code> serves <code>/</code>,
         <code>routes/about.dart</code> serves <code>/about</code>, and the
         counter mutations live under <code>routes/counter/</code>. Shared
         in-memory state lives in <code>lib/counter_state.dart</code>, outside
         route discovery, so Dart Frog only generates the intended handlers.</p>

      <h2>Middleware Chain</h2>
      <p>The app-level middleware composes Trellis provider injection, security
         headers, CSRF validation, request logging, and optional hot reload.
         Order still matters: the provider has to run before helpers read the
         engine from the request context, and CSRF must run before POST handlers
         mutate state.</p>

      <h2>CSRF Protection</h2>
      <p><code>trellisCsrf()</code> bridges the Shelf CSRF middleware into Dart
         Frog. The token is exposed as <code>csrfToken</code> in the template
         context, stored in a meta tag, and sent back on HTMX mutations via the
         <code>X-CSRF-Token</code> header. Hidden fields still work as a fallback.</p>

      <h2>Dev Hot Reload</h2>
      <p>When <code>DEV=true</code> is set, the starter adapts
         <code>devMiddleware()</code> from <code>trellis_dev</code> through
         <code>fromShelfMiddleware()</code>. Template edits trigger a browser
         refresh without interfering with Dart Frog's regular dev workflow.</p>
    </div>
  </main>
</body>
</html>
''';
