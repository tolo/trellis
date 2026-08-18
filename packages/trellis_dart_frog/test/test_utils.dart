import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:http/http.dart' as http;

/// Starts a test server with the given handler, runs [callback], then closes.
///
/// Binds a concrete loopback address and connects to that same address, never the `localhost` name:
/// `HttpServer.bind('localhost')` listens on the first resolved address only (`::1` on macOS) while
/// `Socket.connect('localhost')` tries IPv4 first, so an unrelated process listening on
/// `127.0.0.1:<same ephemeral port>` receives the request instead – wrong response or a hang.
Future<T> withServer<T>(Handler handler, Future<T> Function(Uri baseUri) callback) async {
  final server = await serve(handler, InternetAddress.loopbackIPv4, 0);
  final baseUri = Uri(scheme: 'http', host: server.address.address, port: server.port);
  try {
    return await callback(baseUri);
  } finally {
    await server.close();
  }
}

/// Performs a GET request against the test server.
Future<http.Response> testGet(Handler handler, {String path = '/', Map<String, String>? headers}) {
  return withServer(handler, (base) {
    return http.get(base.replace(path: path), headers: headers);
  });
}

/// Performs a POST request against the test server.
Future<http.Response> testPost(Handler handler, {String path = '/', Map<String, String>? headers, String? body}) {
  return withServer(handler, (base) {
    return http.post(
      base.replace(path: path),
      headers: headers,
      body: body,
    );
  });
}

/// Parses the cookie value from a set-cookie header string.
String? parseCookieValue(String? setCookieHeader, String name) {
  if (setCookieHeader == null) return null;
  for (final part in setCookieHeader.split(';')) {
    final trimmed = part.trim();
    if (trimmed.startsWith('$name=')) {
      return trimmed.substring(name.length + 1);
    }
  }
  return null;
}
