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
///
/// The [loader] must be created with `devMode: true`. If
/// [FileSystemLoader.changes] is null, a [StateError] is thrown
/// immediately.
///
/// Script injection only applies to buffered `text/html` responses (those
/// with a known `contentLength`). Streamed responses and non-HTML content
/// types pass through unmodified.
///
/// Example:
/// ```dart
/// final loader = FileSystemLoader('templates', devMode: true);
/// final handler = const Pipeline()
///     .addMiddleware(devMiddleware(loader))
///     .addHandler(myAppHandler);
/// ```
Middleware devMiddleware(FileSystemLoader loader, {String ssePath = '/_dev/reload', bool injectScript = true}) {
  final sseHandler = liveReloadHandler(loader);
  final ssePathNormalized = ssePath.startsWith('/') ? ssePath.substring(1) : ssePath;
  final script = liveReloadScript(ssePath: ssePath);

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
