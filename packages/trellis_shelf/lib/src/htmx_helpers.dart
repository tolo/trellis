import 'package:shelf/shelf.dart';

/// Returns `true` if the request was made by HTMX (`HX-Request: true`).
bool isHtmxRequest(Request request) {
  return request.headers['hx-request'] == 'true';
}

/// Returns the value of the `HX-Target` header, or `null` if absent.
String? htmxTarget(Request request) {
  return request.headers['hx-target'];
}

/// Returns the value of the `HX-Trigger` header, or `null` if absent.
String? htmxTrigger(Request request) {
  return request.headers['hx-trigger'];
}

/// Returns `true` if the request is an HTMX-boosted navigation
/// (`HX-Boosted: true`).
bool isHtmxBoosted(Request request) {
  return request.headers['hx-boosted'] == 'true';
}
