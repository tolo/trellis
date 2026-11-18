import '../version.dart';

const staticUiPreview = 'static/trellis-ui';
const publicUiPreview = 'public/trellis-ui';

const uiDependency = '  trellis_ui: ^$cliVersion\n';
const uiNavLink = '<a href="/ui" hx-get="/ui" hx-target="#content" hx-push-url="true">Components</a>';
const uiImport = "import 'package:trellis_ui/trellis_ui.dart';\n";

/// Put the scaffold reset below the suite's component dimensions and spacing.
String scaffoldStyles(String styles, {required bool ui}) =>
    ui ? '@layer scaffold {\n$styles$_accessibleShellStyles}\n' : styles;

const _accessibleShellStyles = '''
/* The suite sizes its own controls; the starter's shell needs the same targets. */
nav, .nav-links, .counter-controls { flex-wrap: wrap; }
.counter-section { padding-inline: clamp(0.75rem, 4vw, 2rem); }
:is(nav, footer) a {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-inline-size: 24px;
  min-block-size: 24px;
}
@media (pointer: coarse) {
  :is(nav, footer) a, .counter-controls button { min-inline-size: 44px; min-block-size: 44px; }
}
@media (prefers-reduced-motion: reduce) {
  .counter-controls button { transition: none; }
}
''';

/// Relative paths make previews work from disk. Trellis rewrites them for HTTP.
String uiAssetTags(String previewPath) =>
    '''
  <link rel="stylesheet" href="$previewPath/trellis-ui.css" tl:href="@{/trellis-ui/trellis-ui.css}">
  <script defer src="$previewPath/trellis-ui.js" tl:src="@{/trellis-ui/trellis-ui.js}"></script>
''';

/// The same page serves all three frameworks and previews by itself from disk.
String uiPageTemplate({required String layout, required String previewPath}) =>
    '''
<!doctype html>
<html lang="en" tl:extends="$layout">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Components</title>
  <link rel="stylesheet" href="$previewPath/../styles.css" tl:href="@{/styles.css}">
${uiAssetTags(previewPath)}</head>
<body>
  <main tl:define="content">
    <div tl:fragment="page-content" tl:replace="~{trellis-ui/stack :: stack('lg')}" class="trellis-stack trellis-stack-gap-lg">
      <h1>Components</h1>
      <div tl:replace="~{trellis-ui/cluster :: cluster('sm')}" class="trellis-cluster trellis-cluster-gap-sm">
        <button tl:replace="~{trellis-ui/button :: button}" type="button"
                class="trellis-button trellis-button-variant-default trellis-button-size-default">Primary</button>
        <button tl:replace="~{trellis-ui/button :: button('secondary')}" type="button"
                class="trellis-button trellis-button-variant-secondary trellis-button-size-default">Secondary</button>
        <button tl:replace="~{trellis-ui/button :: button('outline')}" type="button"
                class="trellis-button trellis-button-variant-outline trellis-button-size-default">Outline</button>
        <span tl:replace="~{trellis-ui/badge :: badge('secondary')}" class="trellis-badge trellis-badge-variant-secondary">Example</span>
      </div>
      <div tl:replace="~{trellis-ui/field :: field('example-name', 'Name')}" placeholder="Your name">
        <div class="trellis-field trellis-field-orientation-vertical">
          <label for="example-name" class="trellis-field-label trellis-label">Name</label>
          <input id="example-name" class="trellis-input" type="text" placeholder="Your name">
        </div>
      </div>
      <div tl:replace="~{trellis-ui/dialog :: dialog('components-dialog', 'Example dialog', 'Close it to return to the Components page.')}">
        <span tl:slot="trigger">
          <button tl:replace="~{trellis-ui/button :: button('outline')}" type="button"
                  class="trellis-button trellis-button-variant-outline trellis-button-size-default">Open dialog</button>
        </span>
      </div>
    </div>
  </main>
</body>
</html>
''';
