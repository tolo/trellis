import 'package:dart_frog/dart_frog.dart';
import 'package:http/http.dart' as http;

/// Starts a test server with the given handler, runs [callback], then closes.
Future<T> withServer<T>(Handler handler, Future<T> Function(Uri baseUri) callback) async {
  final server = await serve(handler, 'localhost', 0);
  final baseUri = Uri.parse('http://localhost:${server.port}');
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
