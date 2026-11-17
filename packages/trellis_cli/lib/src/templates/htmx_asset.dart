/// Single source of truth for the HTMX version scaffolded projects load.
///
/// Scaffolded projects self-host HTMX; the CDN is opt-in. Keeping
/// the version and its Subresource Integrity hash here means a version bump is
/// one edit instead of one per template.
///
/// Trellis tracks the HTMX `latest` dist-tag (currently the 2.x line), not the
/// 4.x pre-release line. See ADR-011 for the version policy and the conditions
/// under which the 4.x migration gets scheduled.
library;

export 'htmx_source.dart' show htmxSource;

/// HTMX version loaded by scaffolded projects.
const htmxVersion = '2.0.10';

/// Subresource Integrity hash for `htmx.org@$htmxVersion/dist/htmx.min.js`.
///
/// Regenerate the embedded bytes in `htmx_source.dart` and this hash when
/// bumping [htmxVersion]:
/// ```
/// curl -fsSL https://cdn.jsdelivr.net/npm/htmx.org@<version>/dist/htmx.min.js \
///   | openssl dgst -sha384 -binary | openssl base64 -A
/// ```
const htmxSriHash = 'sha384-H5SrcfygHmAuTDZphMHqBJLc3FhssKjG7w/CeCpFReSfwBWDTKpkzPP8c+cLsK+V';

/// CDN URL for the pinned HTMX build.
const htmxCdnUrl = 'https://cdn.jsdelivr.net/npm/htmx.org@$htmxVersion/dist/htmx.min.js';

/// The SRI-pinned CDN `<script>` tag for opt-in scaffold layouts.
///
/// [indent] prefixes the continuation lines so the tag aligns with the
/// surrounding markup in the generated file.
///
/// Set [trailingNewline] when splicing into a raw-string concatenation: Dart
/// strips the newline directly following a multi-line string's opening
/// delimiter, so the following literal cannot supply the line break itself.
String htmxScriptTag({String indent = '  ', bool trailingNewline = false}) =>
    '<script src="$htmxCdnUrl"\n'
    '$indent        integrity="$htmxSriHash"\n'
    '$indent        crossorigin="anonymous"></script>'
    '${trailingNewline ? '\n' : ''}';

/// Origin allowed by the strict preset when CDN loading is requested.
final htmxCdnOrigin = Uri.parse(htmxCdnUrl).origin;

/// Disable htmx's injected style element under the strict style policy.
const htmxConfigMeta = '''<meta name="htmx-config" content='{"includeIndicatorStyles":false}'>''';

/// Indicator rules normally injected by htmx, shipped in the app stylesheet.
const htmxIndicatorCss = '''
.htmx-indicator { opacity: 0; }
.htmx-request .htmx-indicator, .htmx-request.htmx-indicator { opacity: 1; }
''';

/// Same-origin CSRF listener supporting both HTMX event shapes.
const csrfScript = r'''(function () {
  function setCsrfHeader(headers) {
    if (!headers) return;
    var token = document.querySelector('meta[name="csrf-token"]').content;
    if (token) headers['X-CSRF-Token'] = token;
  }
  document.addEventListener('htmx:configRequest', function(evt) { setCsrfHeader(evt.detail.headers); });
  document.addEventListener('htmx:config:request', function(evt) {
    setCsrfHeader(evt.detail.ctx.request.headers);
  });
})();
''';

/// HTMX tag for a scaffold's chosen asset source.
String scaffoldHtmxScriptTag({bool htmxCdn = false}) =>
    htmxCdn ? htmxScriptTag() : '<script src="/js/htmx.min.js"></script>';
