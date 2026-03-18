import 'package:dart_frog/dart_frog.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:trellis_shelf/trellis_shelf.dart' as trellis_shelf;

import 'request_context_utils.dart';

/// The Shelf context key used by [trellis_shelf.trellisCsrf] to store the token.
const _shelfCsrfTokenKey = 'trellis_shelf.csrfToken';

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
/// Wraps [trellis_shelf.trellisCsrf] for CSRF validation logic via a custom
/// bridge that makes the CSRF token available via [csrfToken] and automatically
/// merges it into the template context via response helpers.
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
    excludedPaths: excludedPaths,
  );

  return (handler) {
    return (context) async {
      // Reconstruct a Shelf request from the public Dart Frog request
      // properties so we can run it through the Shelf CSRF middleware.
      final dfRequest = context.request;
      final shelfRequest = shelf.Request(
        dfRequest.method.value,
        dfRequest.uri,
        headers: dfRequest.headers,
        body: dfRequest.bytes(),
      );

      // Track the CSRF token and the dart_frog response from the inner handler.
      String? extractedToken;
      Response? dartFrogResponse;

      // Run the Shelf CSRF pipeline. The inner handler is called only when the
      // CSRF check passes (or is a safe method). It captures the token from
      // the modified shelf request context and invokes the Dart Frog handler.
      final shelfResponse = await shelfCsrf((modifiedShelfRequest) async {
        // Extract the CSRF token set by trellis_shelf's CSRF middleware.
        extractedToken = modifiedShelfRequest.context[_shelfCsrfTokenKey] as String?;

        // Provide the token as a typed Dart Frog provider so csrfToken()
        // and mergeRequestContext() can access it.
        var requestContext = context;
        if (extractedToken != null) {
          final token = extractedToken!;
          requestContext = requestContext.provide<CsrfToken>(() => CsrfToken(token));
        }

        final dfResponse = await handler(requestContext);
        dartFrogResponse = dfResponse;

        // Return a placeholder shelf response with the same status code.
        // We do NOT read the dart_frog response body here — the actual body
        // is carried by dartFrogResponse and applied after.
        return shelf.Response(dfResponse.statusCode);
      })(shelfRequest);

      // If the CSRF middleware short-circuited (e.g. 403 on invalid token),
      // dartFrogResponse was never set — build a Dart Frog response from the
      // Shelf rejection response.
      if (dartFrogResponse == null) {
        return Response(statusCode: shelfResponse.statusCode, body: await shelfResponse.readAsString());
      }

      // Apply any headers added by the CSRF middleware (e.g. Set-Cookie for
      // new CSRF cookie) to the Dart Frog response. We merge only headers
      // present in the shelf response but not already in the dart_frog response.
      final csrfHeaders = <String, Object>{};
      final setCookie = shelfResponse.headers['set-cookie'];
      if (setCookie != null) {
        csrfHeaders['set-cookie'] = setCookie;
      }

      if (csrfHeaders.isEmpty) return dartFrogResponse!;
      return dartFrogResponse!.copyWith(headers: csrfHeaders);
    };
  };
}
