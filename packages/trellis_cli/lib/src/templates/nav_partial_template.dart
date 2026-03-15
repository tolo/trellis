/// Generates the templates/partials/nav.html content.
///
/// Demonstrates `tl:fragment` for reusable navigation included via `tl:insert`.
/// The fallback content is visible when opening the file directly in a browser
/// (natural template).
String navPartialTemplate() => r'''
<nav tl:fragment="nav">
  <a href="/">Home</a>
</nav>
''';
