/// Generates the layouts/base.html content for a blog project.
///
/// Uses raw string concatenation to avoid conflicts with Trellis `${}` expressions.
String blogBaseLayoutTemplate(String projectName) =>
    r'''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title tl:text="${page.title} + ' — ' + ${site.title}">''' +
    projectName +
    r''' — Blog</title>
  <link rel="stylesheet" href="/styles.css">
  <!-- Extra head content slot -->
  <meta tl:define="head-extra">
</head>
<body>
  <header>
    <a href="/" class="site-title" tl:text="${site.title}">''' +
    projectName +
    r'''</a>
    <nav>
      <a href="/">Home</a>
      <a href="/posts/">Blog</a>
      <a href="/about/">About</a>
    </nav>
  </header>

  <main tl:define="content">
    <p>Override this slot in subtemplate.</p>
  </main>

  <footer tl:define="footer">
    <p>Powered by <a href="https://pub.dev/packages/trellis">Trellis</a></p>
  </footer>
</body>
</html>
''';
