/// Generates the templates/partials/nav.html content.
///
/// Demonstrates `tl:fragment` for reusable navigation included via `tl:insert`.
/// Links use HTMX SPA navigation while remaining valid, navigable anchors.
String navPartialTemplate() => r'''
<nav tl:fragment="nav">
  <a href="/" class="brand">Home</a>
  <div class="nav-links">
    <a href="/" hx-get="/" hx-target="#content" hx-push-url="true">Home</a>
    <a href="/about" hx-get="/about" hx-target="#content" hx-push-url="true">About</a>
  </div>
</nav>
''';
