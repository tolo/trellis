/// Single source of truth for the HTMX version scaffolded projects load.
///
/// Scaffolded projects pull HTMX from a CDN rather than vendoring it. Keeping
/// the version and its Subresource Integrity hash here means a version bump is
/// one edit instead of one per template.
///
/// Trellis tracks the HTMX `latest` dist-tag (currently the 2.x line), not the
/// 4.x pre-release line. See ADR-011 for the version policy and the conditions
/// under which the 4.x migration gets scheduled.
library;

/// HTMX version loaded by scaffolded projects.
const htmxVersion = '2.0.10';

/// Subresource Integrity hash for `htmx.org@$htmxVersion/dist/htmx.min.js`.
///
/// Regenerate when bumping [htmxVersion]:
/// ```
/// curl -fsSL https://cdn.jsdelivr.net/npm/htmx.org@<version>/dist/htmx.min.js \
///   | openssl dgst -sha384 -binary | openssl base64 -A
/// ```
const htmxSriHash = 'sha384-H5SrcfygHmAuTDZphMHqBJLc3FhssKjG7w/CeCpFReSfwBWDTKpkzPP8c+cLsK+V';

/// CDN URL for the pinned HTMX build.
const htmxCdnUrl = 'https://cdn.jsdelivr.net/npm/htmx.org@$htmxVersion/dist/htmx.min.js';

/// The `<script>` tag scaffolded layouts use to load HTMX, SRI-pinned.
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
