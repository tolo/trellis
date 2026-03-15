import 'package:shelf/shelf.dart';

/// Returns a Shelf [Response] with `content-type: text/html; charset=utf-8`.
///
/// ```dart
/// return htmlResponse('<h1>Hello</h1>');
/// return htmlResponse('Not Found', statusCode: 404);
/// ```
Response htmlResponse(String html, {int statusCode = 200}) {
  return Response(statusCode, body: html, headers: {'content-type': 'text/html; charset=utf-8'});
}
