/// Generates the templates/layouts/base.html content for a Dart Frog + Trellis project.
///
/// Uses raw string concatenation to avoid conflicts with Trellis `${}` expressions
/// while injecting [projectName] as a Dart string interpolation.
String dartFrogBaseLayoutTemplate(String projectName) =>
    r'''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title tl:text="${title}">''' +
    projectName +
    r'''</title>
  <meta name="csrf-token" tl:attr="content=${csrfToken}" content="">
  <link rel="stylesheet" href="/styles.css">
  <script src="https://cdn.jsdelivr.net/npm/htmx.org@2.0.8/dist/htmx.min.js"
          integrity="sha384-/TgkGk7p307TH7EXJDuUlgG3Ce1UVolAOFopFekQkkXihi5u/6OCvVKyz1W+idaz"
          crossorigin="anonymous"></script>
  <!-- Set CSRF header on all HTMX requests -->
  <script>
    document.addEventListener('htmx:configRequest', function(evt) {
      var token = document.querySelector('meta[name="csrf-token"]').content;
      if (token) evt.detail.headers['X-CSRF-Token'] = token;
    });
  </script>
</head>
<body>
  <header>
    <h1>''' +
    projectName +
    r'''</h1>
    <nav tl:insert="~{partials/nav.html :: nav}"></nav>
  </header>

  <main tl:define="content">
    <p>Default content — override with tl:define="content".</p>
  </main>

  <footer tl:define="footer">
    <p>Powered by <a href="https://pub.dev/packages/trellis">Trellis</a> +
    <a href="https://dartfrog.vgv.dev/">Dart Frog</a></p>
  </footer>
</body>
</html>
''';
