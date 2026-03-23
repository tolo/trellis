/// Generates the base layout with tl:define override points.
///
/// Uses raw string concatenation to avoid conflicts with Trellis `${}` expressions.
String themeBaseLayoutTemplate(String themeName) =>
    r'''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title tl:text="${page.title} + ' — ' + ${site.title}">''' +
    themeName +
    r'''</title>

  <!-- Theme CSS custom properties (auto-generated from params) -->
  <link rel="stylesheet" href="/theme.css">

  <!-- Head extension point -->
  <meta tl:define="head-extra">
</head>
<body>

  <!-- Header / Navigation -->
  <header tl:define="site-header">
    <nav style="max-width: var(--trellis-max-width, 800px); margin: 0 auto; padding: 1rem;">
      <a href="/" tl:text="${site.title}">Site Title</a>
      <span tl:each="link : ${theme.nav_links}">
        <a tl:href="@{${link.url}}" tl:text="${link.label}">Link</a>
      </span>
    </nav>
  </header>

  <!-- Main content area -->
  <main tl:define="content" style="max-width: var(--trellis-max-width, 800px); margin: 0 auto; padding: 1rem;">
    <p>Override this block in child templates.</p>
  </main>

  <!-- Footer -->
  <footer tl:define="site-footer" style="max-width: var(--trellis-max-width, 800px); margin: 0 auto; padding: 1rem; text-align: center;">
    <p tl:if="${theme.footer_text}" tl:text="${theme.footer_text}">Footer text</p>
    <p tl:if="${theme.show_powered_by}">
      Powered by <a href="https://pub.dev/packages/trellis">Trellis</a>
    </p>
  </footer>

</body>
</html>
''';
