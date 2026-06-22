import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:trellis/trellis.dart';

import 'live_reload_handler.dart';

/// Creates a Shelf [Middleware] that provides live reload functionality.
///
/// The middleware:
/// - Routes requests to [ssePath] to an SSE handler that streams reload
///   events from [loader]'s file watcher.
/// - Optionally injects the live reload `<script>` into HTML responses
///   when [injectScript] is `true` (the default).
/// - Optionally validates templates and reports issues to stderr when
///   [validate] is `true` (the default). Validation runs once at startup and
///   again whenever a watched template changes, so authoring mistakes surface
///   automatically instead of only via `dart run trellis:validate`.
///
/// The [loader] must be created with `devMode: true`. If
/// [FileSystemLoader.changes] is null, a [StateError] is thrown
/// immediately.
///
/// Script injection only applies to buffered `text/html` responses (those
/// with a known `contentLength`). Streamed responses and non-HTML content
/// types pass through unmodified.
///
/// Template validation uses [validator] (defaulting to a standard
/// [TemplateValidator]); pass a configured validator to match a custom prefix
/// or dialect set. Issues are written to [validationSink] (defaulting to
/// stderr) in the same `path:line: severity: message (attribute)` format as
/// the validate CLI, and cached so an unchanged template is reported only once.
///
/// Validation is scoped to templates the loader can enumerate and watch: it
/// runs at startup and on each [FileSystemLoader.changes] event. It is not a
/// per-render hook, so loaders without a change stream are validated only at
/// startup. Create one [devMiddleware] per loader — the change subscription
/// lives for the loader's lifetime and is cancelled by [FileSystemLoader.close].
///
/// Example:
/// ```dart
/// final loader = FileSystemLoader('templates', devMode: true);
/// final handler = const Pipeline()
///     .addMiddleware(devMiddleware(loader))
///     .addHandler(myAppHandler);
/// ```
Middleware devMiddleware(
  FileSystemLoader loader, {
  String ssePath = '/_dev/reload',
  bool injectScript = true,
  bool validate = true,
  TemplateValidator? validator,
  StringSink? validationSink,
}) {
  final sseHandler = liveReloadHandler(loader);
  final ssePathNormalized = ssePath.startsWith('/') ? ssePath.substring(1) : ssePath;
  final script = liveReloadScript(ssePath: ssePath);

  if (validate) {
    final effectiveValidator = validator ?? TemplateValidator();
    final sink = validationSink ?? stderr;
    // Reuse one cache across the startup scan and every change-event re-scan so
    // unchanged templates are validated (and reported) only once, not on every
    // file-change event.
    final cache = <String, List<ValidationError>>{};
    validateLoadedTemplates(loader, effectiveValidator, cache, sink);
    // The watcher emits void events, so re-scan all templates on each change;
    // the cache short-circuits everything that has not actually changed.
    loader.changes?.listen((_) => validateLoadedTemplates(loader, effectiveValidator, cache, sink));
  }

  return (Handler innerHandler) {
    return (Request request) async {
      // Route SSE path to the live reload handler.
      if (request.url.path == ssePathNormalized) {
        return sseHandler(request);
      }

      final response = await innerHandler(request);

      if (!injectScript) return response;

      // Only inject into buffered text/html responses.
      final contentType = response.headers['content-type'];
      if (contentType == null || !contentType.contains('text/html')) {
        return response;
      }
      if (response.contentLength == null) {
        return response;
      }

      final body = await response.readAsString();
      final injected = body.replaceFirst('</body>', '$script\n</body>');
      return response.change(body: injected);
    };
  };
}

/// Validates every template under [loader] and writes any issues to [sink].
///
/// Each issue is formatted as `path:line: severity: message (attribute)`,
/// matching `dart run trellis:validate`. Results are cached in [cache] keyed by
/// template name and source, so a template is validated and reported only once
/// – even across repeated calls (e.g. successive file-change events) – until
/// its content changes. The cache is bounded to [_maxValidationCacheEntries],
/// evicting oldest-first like the engine's parsed-DOM cache.
///
/// Best-effort: a template that fails to load (deleted mid-scan, unreadable, or
/// rejected by the loader) is skipped. Unexpected errors are not swallowed.
void validateLoadedTemplates(
  FileSystemLoader loader,
  TemplateValidator validator,
  Map<String, List<ValidationError>> cache,
  StringSink sink,
) {
  final List<String> names;
  try {
    names = loader.listTemplates();
  } on FileSystemException {
    return; // Template directory removed; nothing to validate.
  }

  for (final name in names) {
    final String source;
    try {
      final loaded = loader.loadSync(name);
      if (loaded == null) continue;
      source = loaded;
    } on TemplateException {
      continue; // Missing or rejected between listing and loading.
    } on FileSystemException {
      continue; // Unreadable between listing and loading.
    }

    // Key on name + source (NUL-delimited, since names never contain NUL) so
    // identical-content templates are each reported under their own path, while
    // an unchanged template is still skipped.
    final key = '$name\u0000$source';
    if (cache.containsKey(key)) continue;
    final issues = validator.validate(source);
    cache[key] = issues;
    if (cache.length > _maxValidationCacheEntries) {
      cache.remove(cache.keys.first); // Bound memory; oldest-first like the engine.
    }
    if (issues.isEmpty) continue;
    // Reconstruct the on-disk path the loader reads so the `path:line:` prefix
    // resolves to a file, matching `dart run trellis:validate` output.
    final path = '${loader.basePath}/$name${loader.extension}';
    for (final issue in issues) {
      sink.writeln(
        '$path:${issue.line ?? 0}: ${issue.severity.name}: ${issue.message}'
        '${issue.attribute != null ? ' (${issue.attribute})' : ''}',
      );
    }
  }
}

/// Upper bound on cached validation results, mirroring the engine's default
/// parsed-DOM cache size. Oldest entries are evicted first.
const _maxValidationCacheEntries = 256;
