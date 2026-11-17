import 'package:dart_frog/dart_frog.dart';
import 'package:trellis_shelf/trellis_shelf.dart' as trellis_shelf;

import 'request_context_utils.dart';

/// Middleware that adds security headers to all responses.
///
/// Wraps [trellis_shelf.trellisSecurityHeaders] via [fromShelfMiddleware].
/// Accepts the same configuration options.
///
/// ```dart
/// Handler middleware(Handler handler) {
///   return handler
///       .use(trellisProvider(engine))
///       .use(trellisSecurityHeaders());
/// }
/// ```
Middleware trellisSecurityHeaders({
  String xContentTypeOptions = 'nosniff',
  String xFrameOptions = 'DENY',
  String referrerPolicy = 'strict-origin-when-cross-origin',
  String xXssProtection = '0',
  trellis_shelf.CspBuilder? csp,
  bool enableCsp = true,
}) {
  return fromShelfMiddleware(
    trellis_shelf.trellisSecurityHeaders(
      xContentTypeOptions: xContentTypeOptions,
      xFrameOptions: xFrameOptions,
      referrerPolicy: referrerPolicy,
      xXssProtection: xXssProtection,
      csp: csp,
      enableCsp: enableCsp,
    ),
  );
}

/// Middleware that implements CSRF protection.
///
/// Wraps [trellis_shelf.trellisCsrf] for CSRF validation logic and makes the
/// CSRF token available via [csrfToken]. The token is accepted from the
/// [headerName] header or the [fieldName] form field; either way the handler
/// can still read the request body.
///
/// ```dart
/// Handler middleware(Handler handler) {
///   return handler
///       .use(trellisProvider(engine))
///       .use(trellisCsrf(secret: 'my-secret-key'));
/// }
/// ```
///
/// The CSRF token is automatically merged into the template context by
/// [renderPage], [renderFragment], and [renderOobFragments].
Middleware trellisCsrf({
  required String secret,
  String cookieName = '__csrf',
  String fieldName = '_csrf',
  String headerName = 'X-CSRF-Token',
  List<String> excludedPaths = const [],
}) {
  final shelfCsrf = trellis_shelf.trellisCsrf(
    secret: secret,
    cookieName: cookieName,
    fieldName: fieldName,
    headerName: headerName,
  );

  return (handler) {
    return (context) {
      // Matched against the full request path here rather than by trellis_shelf, which sees
      // only the part of the path below a Dart Frog mount point.
      if (excludedPaths.contains(context.request.uri.path)) return handler(context);

      // fromShelfMiddleware runs the check on Dart Frog's own underlying shelf.Request, so the
      // body trellis_shelf re-wraps after reading a form-field token reaches the handler, and the
      // CSRF cookie is added to the handler's real response. Built per request because the token
      // travels from the shelf context to the Dart Frog provider through this closure: Dart Frog
      // has no public way to read a shelf context key from a RequestContext.
      String? token;
      final bridge = fromShelfMiddleware(
        (shelfHandler) => shelfCsrf((request) {
          token = trellis_shelf.csrfToken(request);
          return shelfHandler(request);
        }),
      );
      return bridge((checked) {
        final value = token;
        return handler(value == null ? checked : checked.provide<CsrfToken>(() => CsrfToken(value)));
      })(context);
    };
  };
}
