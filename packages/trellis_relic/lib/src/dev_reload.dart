import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:relic/relic.dart';
import 'package:trellis/trellis.dart';

const _reloadPath = '/_dev/reload';
const _scriptPath = '/_dev/reload.js';
const _client =
    '''
(() => {
  const source = new EventSource('$_reloadPath');
  source.addEventListener('reload', () => location.reload());
})();
''';

/// Mounts live reload on a Relic app in development.
///
/// The loader must use `devMode: true`. Template changes and, when given,
/// recursive CSS and JavaScript changes under [staticDirectory] notify every
/// open browser. Closing [loader] ends the event streams and static watches.
///
/// Match reload routes with `GET /_dev/reload` and `GET /_dev/reload.js`
/// under the app's existing security headers. The middleware adds the
/// same-origin script only to buffered HTML with a closing body tag. Call
/// this function only when the app starts in development.
void trellisDevReload(RelicApp app, FileSystemLoader loader, {String? staticDirectory}) {
  final templates = loader.changes;
  if (templates == null) {
    throw StateError('Create the loader with devMode: true to enable live reload.');
  }
  final changes = _reloadChanges(templates, staticDirectory);
  app
    ..use('/', _injectReloadClient)
    ..get(_reloadPath, (_) => _eventStream(changes))
    ..get(_scriptPath, (_) => Response.ok(body: Body.fromString(_client, mimeType: MimeType.javascript)));
}

Handler _injectReloadClient(Handler next) => (request) async {
  final response = await next(request);
  if (response is! Response || response.headers.contains(HeaderName.contentEncoding)) return response;
  final bytes = response.body.bytes;
  final type = response.body.bodyType;
  if (bytes == null || type?.mimeType != MimeType.html) return response;
  // The charset may be declared in the document. Latin-1 maps bytes one to one
  // so the ASCII insertion preserves the original encoding without guessing it.
  final encoding = type?.encoding ?? latin1;
  final html = encoding.decode(bytes);
  final closingBody = html.lastIndexOf('</body>');
  if (closingBody == -1) return response;
  final injected = html.replaceRange(closingBody, closingBody, '<script src="$_scriptPath"></script>\n');
  return response.copyWith(
    body: Body(bytes: Uint8List.fromList(encoding.encode(injected)), bodyType: type),
  );
};

Response _eventStream(Stream<void> changes) {
  return Response.ok(
    headers: Headers.fromMap({
      'cache-control': ['no-cache'],
    }),
    body: Body.fromDataStream(
      Stream<Uint8List>.multi((frames) {
        frames.add(_connected);
        final subscription = changes.listen((_) => frames.add(_reload), onError: frames.addError, onDone: frames.close);
        frames.onCancel = subscription.cancel;
      }),
      mimeType: const MimeType('text', 'event-stream'),
    ),
  );
}

final _connected = _frame(': connected\n');
final _reload = _frame('event: reload\ndata: reload\n');

Uint8List _frame(String lines) {
  // relic_io 2.0 flushes after body.read() ends. Push each frame through the
  // dart:io response buffer with an ignored SSE comment until the adapter can
  // flush individual writes and the socket proof passes without padding.
  return utf8.encode('$lines:${' ' * 8192}\n\n');
}

Stream<void> _reloadChanges(Stream<void> templates, String? staticDirectory) {
  final staticLoaders = [
    if (staticDirectory != null && Directory(staticDirectory).existsSync())
      for (final extension in ['.css', '.js']) FileSystemLoader(staticDirectory, extension: extension, devMode: true),
  ];
  final changes = StreamController<void>.broadcast();
  Timer? pending;

  void scheduleReload(void _) {
    // Saving one file can emit several OS watch notifications.
    pending?.cancel();
    pending = Timer(const Duration(milliseconds: 50), () => changes.add(null));
  }

  final staticSubscriptions = [
    for (final loader in staticLoaders) loader.changes!.listen(scheduleReload, onError: changes.addError),
  ];
  templates.listen(
    scheduleReload,
    onError: changes.addError,
    onDone: () async {
      await Future.wait(staticSubscriptions.map((subscription) => subscription.cancel()));
      pending?.cancel();
      await Future.wait(staticLoaders.map((loader) => loader.close()));
      await changes.close();
    },
  );
  return changes.stream;
}
