import 'package:dart_frog/dart_frog.dart';

/// Returns `true` if the request was made by HTMX (`HX-Request: true`).
bool isHtmxRequest(RequestContext context) {
  return context.request.headers['hx-request'] == 'true';
}

/// Returns the value of the `HX-Target` header, or `null` if absent.
String? htmxTarget(RequestContext context) {
  return context.request.headers['hx-target'];
}

/// Returns the value of the `HX-Trigger` header, or `null` if absent.
String? htmxTrigger(RequestContext context) {
  return context.request.headers['hx-trigger'];
}

/// Returns `true` if the request is an HTMX-boosted navigation (`HX-Boosted: true`).
bool isHtmxBoosted(RequestContext context) {
  return context.request.headers['hx-boosted'] == 'true';
}
