/// Generates the templates/about.html content for a Relic + Trellis project.
///
/// Explains the Relic-specific patterns: no-DI, middleware scoping, and HTMX
/// fragment rendering.
String relicAboutPageTemplate() => r'''
<html tl:extends="base.html">
<body>
  <main tl:define="content">
    <div tl:fragment="page-content">
      <h1>About This App</h1>

      <h2>Relic's No-DI Pattern</h2>
      <p>Unlike Shelf (which uses request context maps) or Dart Frog (which uses
         providers), Relic has no dependency injection mechanism. The Trellis engine
         is created as an application-level variable and passed explicitly to route
         handlers via closures. This is the idiomatic Relic pattern.</p>

      <h2>Middleware Scoping</h2>
      <p>Relic middleware attached via <code>app.use('/', ...)</code> only fires
         for routes that match. This means security headers are applied to
         successful responses but <strong>not</strong> to 404 or 405 responses.
         This is a behavioral difference from Shelf, where middleware wraps the
         entire handler chain.</p>

      <h2>HTMX Fragment Rendering</h2>
      <p>HTMX requests are detected via the <code>HX-Request</code> header.
         When detected, handlers return only the relevant HTML fragment instead
         of the full page. This enables fast, partial page updates without
         writing any client-side JavaScript.</p>

      <h2>Template Inheritance</h2>
      <p>Templates use <code>tl:extends</code> to inherit from a base layout and
         <code>tl:define</code> to override content blocks. The base template
         defines the page shell (header, nav, footer) and child templates fill in
         the <code>content</code> block.</p>
    </div>
  </main>
</body>
</html>
''';
