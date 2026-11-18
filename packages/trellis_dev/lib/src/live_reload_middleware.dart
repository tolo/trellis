import 'package:shelf/shelf.dart';

import 'live_reload_handler.dart';

/// Creates a Shelf [Middleware] that reloads connected browser tabs on every
/// event from [changes].
///
/// Use it when something other than a template loader decides when the page is
/// stale, such as a static site rebuild that has just finished. For a
/// [FileSystemLoader]-driven app, `devMiddleware` wires this up from the
/// loader's watcher and adds template validation.
///
/// [changes] must be a broadcast stream, because each SSE connection listens to
/// it. Closing it ends every open SSE connection.
///
/// The middleware:
/// - Routes requests to [ssePath] to an SSE handler that sends a `reload`
///   event for each event on [changes].
/// - Serves the reload client at [scriptPath] as JavaScript, so it works under
///   a `script-src 'self'` policy.
/// - When [injectScript] is `true` (the default), adds a `<script src>` tag for
///   [scriptPath] before `</body>` in buffered `text/html` responses (those with
///   a known `contentLength`). Streamed responses and other content types pass
///   through unmodified.
///
/// Example:
/// ```dart
/// final rebuilt = StreamController<void>.broadcast();
/// final handler = const Pipeline()
///     .addMiddleware(liveReloadMiddleware(rebuilt.stream))
///     .addHandler(staticHandler);
/// // After each successful rebuild:
/// rebuilt.add(null);
/// ```
Middleware liveReloadMiddleware(
  Stream<void> changes, {
  String ssePath = '/_dev/reload',
  String scriptPath = '/_dev/reload.js',
  bool injectScript = true,
}) {
  final sseHandler = liveReloadChangesHandler(changes);
  final ssePathNormalized = ssePath.startsWith('/') ? ssePath.substring(1) : ssePath;
  final scriptPathNormalized = scriptPath.startsWith('/') ? scriptPath.substring(1) : scriptPath;
  final script = '<script src="${Uri(path: '/$scriptPathNormalized')}"></script>';

  return (Handler innerHandler) {
    return (Request request) async {
      if (request.url.path == ssePathNormalized) {
        return sseHandler(request);
      }

      if (request.url.path == scriptPathNormalized) {
        return Response.ok(
          liveReloadClientScript(ssePath: ssePath),
          headers: {'content-type': 'application/javascript'},
        );
      }

      final response = await innerHandler(request);

      if (!injectScript) return response;

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
