import 'dart:async';
import 'dart:io';

import 'package:relic/relic.dart';

/// Runs [body] with a real [Request] carrying [headers] and returns its result,
/// or rethrows its error.
///
/// Relic builds a Request only through an adapter, and a mock cannot stand in
/// for code that reads request context properties (the render helpers read the
/// CSRF token from one), so this serves one GET over loopback.
Future<T> withRequest<T>(FutureOr<T> Function(Request request) body, {Map<String, String> headers = const {}}) async {
  final outcome = Completer<T>();
  // The error is awaited only after the response; mark it handled until then.
  outcome.future.ignore();
  final app = RelicApp()
    ..get('/', (request) async {
      try {
        outcome.complete(await body(request));
      } catch (error, stackTrace) {
        outcome.completeError(error, stackTrace);
      }
      return Response.ok();
    });
  final server = await app.serve(port: 0);
  final client = HttpClient();
  try {
    final request = await client.get(InternetAddress.loopbackIPv4.address, server.port, '/');
    headers.forEach(request.headers.set);
    await (await request.close()).drain<void>();
    return await outcome.future;
  } finally {
    client.close(force: true);
    await app.close(force: true);
  }
}
