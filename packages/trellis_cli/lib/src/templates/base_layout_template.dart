import 'htmx_asset.dart';

/// Generates the templates/layouts/base.html content.
///
/// Uses raw string concatenation to avoid conflicts with Trellis `${}`
/// expressions. Includes the HTMX CDN script, CSRF meta tag, and SPA-style
/// navigation anchors.
String baseLayoutTemplate(String projectName) =>
    r'''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title tl:text="${pageTitle}">''' +
    projectName +
    r'''</title>
  <meta name="csrf-token" tl:attr="content=${csrfToken}" content="">
  <link rel="stylesheet" href="/styles.css">
  ''' +
    htmxScriptTag(trailingNewline: true) +
    r'''  <!-- Set CSRF header on all HTMX requests (htmx 2 and htmx 4 event shapes) -->
  <script>
    (function () {
      function setCsrfHeader(headers) {
        var token = document.querySelector('meta[name="csrf-token"]').content;
        if (token) headers['X-CSRF-Token'] = token;
      }
      document.addEventListener('htmx:configRequest', function(evt) { setCsrfHeader(evt.detail.headers); });
      document.addEventListener('htmx:config:request', function(evt) { setCsrfHeader(evt.detail.ctx.request.headers); });
    })();
  </script>
</head>
<body>
  <header>
    <nav tl:insert="~{partials/nav.html :: nav}">
      <a href="/" class="brand">''' +
    projectName +
    r'''</a>
    </nav>
  </header>

  <main id="content" tl:define="content">
    <p>Default content — override with tl:define="content".</p>
  </main>

  <footer tl:define="footer">
    <p>Powered by <a href="https://pub.dev/packages/trellis">Trellis</a>
       + <a href="https://pub.dev/packages/shelf">Shelf</a>
       + <a href="https://htmx.org">HTMX</a></p>
  </footer>
</body>
</html>
''';
