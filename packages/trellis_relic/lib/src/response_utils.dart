import 'package:relic/relic.dart';

/// Returns a Relic [Response] with `content-type: text/html` and the
/// given [html] as the response body.
///
/// ```dart
/// return htmlResponse('<h1>Hello</h1>');
/// return htmlResponse('Not Found', statusCode: 404);
/// ```
Response htmlResponse(String html, {int statusCode = 200}) {
  return Response(
    statusCode,
    body: Body.fromString(html, mimeType: MimeType.html),
  );
}
