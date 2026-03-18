import 'package:dart_frog/dart_frog.dart';

/// Internal holder class for the CSRF token, registered as a Dart Frog provider.
///
/// Using a wrapper class avoids conflicts with other `String` providers.
class CsrfToken {
  /// Creates a CSRF token holder.
  const CsrfToken(this.value);

  /// The raw CSRF token string.
  final String value;
}

/// Returns the CSRF token from the request context, or `null` if the
/// [trellisCsrf] middleware has not been applied.
String? csrfToken(RequestContext context) {
  try {
    return context.read<CsrfToken>().value;
  } on StateError {
    return null;
  }
}

/// Merges request-context values (e.g. CSRF token) into a template context map.
///
/// Returns a new map — the original [templateContext] is not modified.
Map<String, dynamic> mergeRequestContext(RequestContext context, Map<String, dynamic> templateContext) {
  final merged = Map<String, dynamic>.of(templateContext);
  final token = csrfToken(context);
  if (token != null) merged['csrfToken'] = token;
  return merged;
}
