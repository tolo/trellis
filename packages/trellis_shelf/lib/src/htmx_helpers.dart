import 'package:shelf/shelf.dart';

/// Returns `true` if the request was made by HTMX (`HX-Request: true`).
bool isHtmxRequest(Request request) {
  return request.headers['hx-request'] == 'true';
}

/// Returns the `id` of the element HTMX will swap the response into, or `null`
/// if the request carries no `HX-Target` header or the target has no id.
///
/// HTMX 2 sends the bare id; HTMX 4 sends `tag#id`. Both yield the id here.
String? htmxTarget(Request request) {
  return _elementId(request.headers, 'hx-target');
}

/// Returns the `id` of the element that triggered the request, or `null`.
///
/// Reads `HX-Source` (HTMX 4) and falls back to the `HX-Trigger` request header
/// (HTMX 2).
String? htmxSource(Request request) {
  return _elementId(request.headers, 'hx-source') ?? request.headers['hx-trigger'];
}

/// Returns the `id` of the element that triggered the request, or `null`.
@Deprecated('Use htmxSource(). HTMX 4 sends HX-Source and reserves HX-Trigger for responses.')
String? htmxTrigger(Request request) => htmxSource(request);

/// Returns `true` if the request is an HTMX-boosted navigation
/// (`HX-Boosted: true`).
bool isHtmxBoosted(Request request) {
  return request.headers['hx-boosted'] == 'true';
}

/// HTMX 4 identifies elements as `tag#id` (id `encodeURI`-encoded, `#id` omitted
/// when absent) and always sends `HX-Source`, which tells its format apart from
/// HTMX 2's bare id.
String? _elementId(Map<String, String> headers, String name) {
  final value = headers[name];
  if (value == null || !headers.containsKey('hx-source')) return value;
  final hash = value.indexOf('#');
  if (hash < 0) return null;
  final id = value.substring(hash + 1);
  // Client-controlled: fall back to the raw id rather than throw on malformed encoding.
  try {
    return Uri.decodeFull(id);
  } on FormatException {
    return id;
  } on ArgumentError {
    return id;
  }
}
