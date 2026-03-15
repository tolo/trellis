import 'package:shelf/shelf.dart';

/// Context key for the CSRF token stored by [trellisCsrf] middleware.
const csrfTokenContextKey = 'trellis_shelf.csrfToken';

/// Returns the CSRF token from the request context, or `null` if the
/// [trellisCsrf] middleware has not been applied.
String? csrfToken(Request request) {
  return request.context[csrfTokenContextKey] as String?;
}

/// Merges request-context values (e.g. CSRF token) into a template context map.
///
/// Returns a new map — the original [context] is not modified.
Map<String, dynamic> mergeRequestContext(Request request, Map<String, dynamic> context) {
  final merged = Map<String, dynamic>.of(context);
  final token = request.context[csrfTokenContextKey];
  if (token != null) merged['csrfToken'] = token;
  return merged;
}
