/// Generates the templates/layouts/base.html content.
///
/// Uses raw string concatenation to avoid conflicts with Trellis `${}` expressions.
/// Includes HTMX CDN with pinned version and SRI integrity hash.
String baseLayoutTemplate(String projectName) =>
    r'''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title tl:text="${title}">''' +
    projectName +
    r'''</title>
  <meta name="csrf-token" tl:attr="content=${csrfToken}" content="">
  <link rel="stylesheet" href="/styles.css">
  <script src="https://unpkg.com/htmx.org@2.0.4"
          integrity="sha384-HGfztofotfshcF7+8n44JQL2oJmowVChPTg48S+jvZoztPfvwD79OC/LTtG6dMp+"
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
    <p>Powered by <a href="https://pub.dev/packages/trellis">Trellis</a></p>
  </footer>
</body>
</html>
''';
