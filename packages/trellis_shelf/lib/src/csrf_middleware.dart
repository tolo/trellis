import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';

import 'request_context.dart';

/// Methods that require CSRF validation.
const _stateMethods = {'POST', 'PUT', 'DELETE', 'PATCH'};

/// Generates a cryptographically random 64-character hex token.
String _generateToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Parses a named cookie value from the `Cookie` request header.
String? _parseCookie(Request request, String name) {
  final header = request.headers['cookie'];
  if (header == null) return null;
  for (final part in header.split(';')) {
    final trimmed = part.trim();
    final eq = trimmed.indexOf('=');
    if (eq == -1) continue;
    if (trimmed.substring(0, eq).trim() == name) {
      return trimmed.substring(eq + 1).trim();
    }
  }
  return null;
}

/// Constant-time string comparison to prevent timing attacks.
bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var result = 0;
  for (var i = 0; i < a.length; i++) {
    result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return result == 0;
}

/// Middleware that implements CSRF protection using a double-submit cookie
/// pattern with HMAC-SHA256 signing.
///
/// **GET/HEAD/OPTIONS**: Generates a signed token, sets a cookie, and stores
/// the raw token in the request context for template rendering.
///
/// **POST/PUT/DELETE/PATCH**: Validates the submitted token against the
/// signed cookie. Returns 403 on mismatch or missing token.
///
/// The [secret] is used for HMAC-SHA256 signing and must be kept private.
///
/// ```dart
/// final pipeline = const Pipeline()
///     .addMiddleware(trellisEngine(engine))
///     .addMiddleware(trellisCsrf(secret: 'my-secret-key'))
///     .addHandler(myHandler);
/// ```
Middleware trellisCsrf({
  required String secret,
  String cookieName = '__csrf',
  String fieldName = '_csrf',
  String headerName = 'X-CSRF-Token',
  List<String> excludedPaths = const [],
}) {
  final hmacKey = utf8.encode(secret);

  String sign(String token) {
    final hmac = Hmac(sha256, hmacKey);
    return hmac.convert(utf8.encode(token)).toString();
  }

  return (Handler innerHandler) {
    return (Request request) async {
      // Check excluded paths
      final requestPath = '/${request.url.path}';
      if (excludedPaths.contains(requestPath)) {
        return innerHandler(request);
      }

      if (_stateMethods.contains(request.method)) {
        // Validate CSRF token
        final cookieValue = _parseCookie(request, cookieName);
        if (cookieValue == null) {
          return Response.forbidden('CSRF token mismatch');
        }

        final dotIndex = cookieValue.indexOf('.');
        if (dotIndex == -1) {
          return Response.forbidden('CSRF token mismatch');
        }

        final rawToken = cookieValue.substring(0, dotIndex);
        final cookieHmac = cookieValue.substring(dotIndex + 1);

        // Verify HMAC signature on cookie
        final expectedHmac = sign(rawToken);
        if (!_constantTimeEquals(cookieHmac, expectedHmac)) {
          return Response.forbidden('CSRF token mismatch');
        }

        // Extract submitted token from header or form body
        var submittedToken = request.headers[headerName.toLowerCase()];
        var updatedRequest = request;

        if (submittedToken == null) {
          // Try form body
          final body = await request.readAsString();
          updatedRequest = request.change(body: body);

          final params = Uri.splitQueryString(body);
          submittedToken = params[fieldName];
        }

        if (submittedToken == null || !_constantTimeEquals(submittedToken, rawToken)) {
          return Response.forbidden('CSRF token mismatch');
        }

        // Valid — store token in context and pass through
        return innerHandler(updatedRequest.change(context: {csrfTokenContextKey: rawToken}));
      } else {
        // Safe method — reuse existing valid token or generate a new one.
        // Reusing prevents token rotation when subsequent safe requests
        // (e.g. CSS/image loads) would invalidate tokens already embedded
        // in the page.
        final existingCookieValue = _parseCookie(request, cookieName);
        if (existingCookieValue != null) {
          final dotIndex = existingCookieValue.indexOf('.');
          if (dotIndex != -1) {
            final existingToken = existingCookieValue.substring(0, dotIndex);
            final existingHmac = existingCookieValue.substring(dotIndex + 1);
            if (_constantTimeEquals(existingHmac, sign(existingToken))) {
              // Valid existing token — reuse without setting a new cookie.
              return innerHandler(request.change(context: {csrfTokenContextKey: existingToken}));
            }
          }
        }

        // No valid cookie — generate new token.
        final rawToken = _generateToken();
        final signed = '$rawToken.${sign(rawToken)}';
        final cookie = '$cookieName=$signed; Path=/; HttpOnly; SameSite=Strict';

        final response = await innerHandler(request.change(context: {csrfTokenContextKey: rawToken}));

        // Preserve existing Set-Cookie headers from inner handlers.
        final existingSetCookie = response.headers['set-cookie'];
        if (existingSetCookie != null) {
          return response.change(headers: {'set-cookie': <String>[existingSetCookie, cookie]});
        }
        return response.change(headers: {'set-cookie': cookie});
      }
    };
  };
}
