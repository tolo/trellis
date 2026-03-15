import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:trellis/trellis.dart';

/// Creates a Shelf [Handler] that serves Server-Sent Events (SSE) for
/// live reload.
///
/// Each incoming request creates a long-lived SSE connection. When the
/// [loader]'s file watcher detects a change, all connected clients receive
/// a `reload` event.
///
/// The [loader] must be created with `devMode: true` so that
/// [FileSystemLoader.changes] is non-null. If `changes` is null, a
/// [StateError] is thrown immediately.
///
/// Example:
/// ```dart
/// final loader = FileSystemLoader('templates', devMode: true);
/// final handler = liveReloadHandler(loader);
/// ```
Handler liveReloadHandler(FileSystemLoader loader) {
  final changes = loader.changes;
  if (changes == null) {
    throw StateError(
      'FileSystemLoader.changes is null — '
      'create the loader with devMode: true to enable live reload.',
    );
  }
  return (Request request) {
    final controller = StreamController<List<int>>();
    final subscription = changes.listen((_) {
      if (!controller.isClosed) {
        controller.add(utf8.encode('event: reload\ndata: reload\n\n'));
      }
    });
    controller.onCancel = subscription.cancel;
    return Response.ok(
      controller.stream,
      headers: {'content-type': 'text/event-stream'},
      context: {'shelf.io.buffer_output': false},
    );
  };
}

/// Returns a self-contained `<script>` block that connects to the SSE
/// endpoint at [ssePath] and reloads the page on `reload` events.
///
/// The script uses an IIFE to avoid polluting the global scope. It listens
/// for the named `reload` event (matching the `event: reload` SSE frame)
/// and calls `location.reload()`.
///
/// Example:
/// ```dart
/// final script = liveReloadScript(); // defaults to '/_dev/reload'
/// ```
String liveReloadScript({String ssePath = '/_dev/reload'}) {
  return '''
<script>
(function() {
  var source = new EventSource('$ssePath');
  source.addEventListener('reload', function(e) {
    console.log('[trellis_dev] Reloading...');
    location.reload();
  });
  source.onerror = function(e) {
    console.warn('[trellis_dev] SSE connection error:', e);
  };
})();
</script>''';
}
