import '../htmx_asset.dart';
import '../ui_scaffold_template.dart';

/// Generates the templates/layouts/base.html content for a Dart Frog + Trellis project.
///
/// Uses raw string concatenation to avoid conflicts with Trellis `${}`
/// expressions while injecting [projectName] as a Dart string interpolation.
String dartFrogBaseLayoutTemplate(String projectName, {bool htmxCdn = false, bool ui = false}) =>
    r'''<!DOCTYPE html>
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
    '$htmxConfigMeta\n  ${scaffoldHtmxScriptTag(htmxCdn: htmxCdn)}\n' +
    r'''
  <script src="/js/csrf.js"></script>
''' +
    (ui ? uiAssetTags('../../$publicUiPreview') : '') +
    r'''</head>
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
    <p>Powered by <a href="https://pub.dev/packages/trellis">Trellis</a> +
    <a href="https://dartfrog.vgv.dev/">Dart Frog</a></p>
  </footer>
</body>
</html>
''';
