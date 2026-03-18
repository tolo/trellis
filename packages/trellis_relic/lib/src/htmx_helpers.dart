import 'package:relic/relic.dart';

/// Returns `true` if the request was made by HTMX (`HX-Request: true`).
///
/// Reads the `HX-Request` header from Relic's [Request.headers].
/// Note: Relic headers are case-insensitive and return `Iterable<String>?`.
bool isHtmxRequest(Request request) {
  return request.headers['HX-Request']?.first == 'true';
}

/// Returns the value of the `HX-Target` header, or `null` if absent.
String? htmxTarget(Request request) {
  return request.headers['HX-Target']?.first;
}

/// Returns the value of the `HX-Trigger` header, or `null` if absent.
String? htmxTrigger(Request request) {
  return request.headers['HX-Trigger']?.first;
}

/// Returns `true` if the request is an HTMX-boosted navigation
/// (`HX-Boosted: true`).
bool isHtmxBoosted(Request request) {
  return request.headers['HX-Boosted']?.first == 'true';
}
