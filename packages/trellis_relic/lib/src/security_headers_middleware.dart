import 'package:relic/relic.dart';

/// Builder for Content-Security-Policy header directives.
///
/// Provides sensible defaults that can be overridden per-directive.
/// Null directives are omitted from the output.
///
/// ```dart
/// final csp = CspBuilder(
///   scriptSrc: "'self' 'unsafe-inline'",
///   connectSrc: "'self' ws:",
/// );
/// ```
class CspBuilder {
  /// Default: `'self'`
  final String? defaultSrc;

  /// Default: `'self'`
  final String? scriptSrc;

  /// Default: `'self' 'unsafe-inline'`
  final String? styleSrc;

  /// Default: `'self' data:`
  final String? imgSrc;

  /// Default: `'none'`
  final String? objectSrc;

  /// Default: `'none'`
  final String? frameAncestors;

  /// Default: `'self'`
  final String? baseUri;

  /// Default: `'self'`
  final String? formAction;

  /// Optional — omitted if null.
  final String? connectSrc;

  /// Optional — omitted if null.
  final String? fontSrc;

  /// Additional custom directives (e.g. `{'report-uri': '/csp-report'}`).
  final Map<String, String>? custom;

  /// Creates a CSP builder with sensible defaults for server-rendered apps.
  const CspBuilder({
    this.defaultSrc = "'self'",
    this.scriptSrc = "'self'",
    this.styleSrc = "'self' 'unsafe-inline'",
    this.imgSrc = "'self' data:",
    this.objectSrc = "'none'",
    this.frameAncestors = "'none'",
    this.baseUri = "'self'",
    this.formAction = "'self'",
    this.connectSrc,
    this.fontSrc,
    this.custom,
  });

  /// Builds the CSP header value as a semicolon-separated directive string.
  String build() {
    final directives = <String>[];

    void add(String name, String? value) {
      if (value != null) directives.add('$name $value');
    }

    add('default-src', defaultSrc);
    add('script-src', scriptSrc);
    add('style-src', styleSrc);
    add('img-src', imgSrc);
    add('object-src', objectSrc);
    add('frame-ancestors', frameAncestors);
    add('base-uri', baseUri);
    add('form-action', formAction);
    add('connect-src', connectSrc);
    add('font-src', fontSrc);

    if (custom != null) {
      for (final entry in custom!.entries) {
        directives.add('${entry.key} ${entry.value}');
      }
    }

    return directives.join('; ');
  }
}

/// Middleware that adds security headers to all responses.
///
/// Adds the following headers with configurable defaults:
/// - `X-Content-Type-Options` (default: `nosniff`)
/// - `X-Frame-Options` (default: `DENY`)
/// - `Referrer-Policy` (default: `strict-origin-when-cross-origin`)
/// - `X-XSS-Protection` (default: `0`)
/// - `Content-Security-Policy` (default: sensible CSP via [CspBuilder])
///
/// **Important**: Relic middleware only fires for matched routes. Security
/// headers will NOT be added to 404/405 responses. This is a behavioral
/// difference from Shelf's `Pipeline` where middleware always runs.
///
/// ```dart
/// final app = RelicApp()
///   ..use('/', trellisSecurityHeaders())
///   ..get('/', myHandler);
/// ```
Middleware trellisSecurityHeaders({
  String xContentTypeOptions = 'nosniff',
  String xFrameOptions = 'DENY',
  String referrerPolicy = 'strict-origin-when-cross-origin',
  String xXssProtection = '0',
  CspBuilder? csp,
  bool enableCsp = true,
}) {
  final cspValue = enableCsp ? (csp ?? const CspBuilder()).build() : null;

  return (Handler innerHandler) {
    return (Request request) async {
      final result = await innerHandler(request);
      if (result is! Response) return result;

      return result.copyWith(
        headers: result.headers.transform((h) {
          h['X-Content-Type-Options'] = [xContentTypeOptions];
          h['X-Frame-Options'] = [xFrameOptions];
          h['Referrer-Policy'] = [referrerPolicy];
          h['X-XSS-Protection'] = [xXssProtection];
          if (cspValue != null) {
            h['Content-Security-Policy'] = [cspValue];
          }
        }),
      );
    };
  };
}
