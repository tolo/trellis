import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:relic/relic.dart';

/// Methods that require CSRF validation.
const _stateMethods = {Method.post, Method.put, Method.delete, Method.patch};

final _csrfTokenProperty = ContextProperty<String>('trellis_relic.csrfToken');

/// Returns the CSRF token [trellisCsrf] stored for [request], or `null` when
/// the middleware did not run for it.
///
/// [renderPage], [renderFragment] and [renderOobFragments] already merge it
/// into the template context as `csrfToken`.
String? csrfToken(Request request) => _csrfTokenProperty[request];

/// Returns a copy of [context] with the request's CSRF token as `csrfToken`,
/// when there is one.
Map<String, dynamic> mergeRequestContext(Request request, Map<String, dynamic> context) {
  final token = csrfToken(request);
  if (token == null) return context;
  return {...context, 'csrfToken': token};
}

/// Generates a cryptographically random 64-character hex token.
String _generateToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Parses a named cookie from the raw `Cookie` header.
///
/// Reads the raw header rather than Relic's typed `cookie` accessor, which
/// throws on a malformed cookie the app does not own.
String? _parseCookie(Request request, String name) {
  final header = request.headers['cookie'];
  if (header == null) return null;
  for (final part in header.join(';').split(';')) {
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

Response _mismatch() => Response.forbidden(body: Body.fromString('CSRF token mismatch'));

/// Middleware that implements CSRF protection using a double-submit cookie
/// pattern with HMAC-SHA256 signing, matching `trellisCsrf` in `trellis_shelf`.
///
/// **GET/HEAD/OPTIONS**: Reuses a validly signed cookie's token, or generates
/// one and sets the cookie. The raw token is readable with [csrfToken], and
/// the render helpers pass it to templates as `csrfToken`.
///
/// **POST/PUT/DELETE/PATCH**: Validates the token from the [headerName] header
/// (HTMX) or, failing that, the [fieldName] field of an
/// `application/x-www-form-urlencoded` body against the signed cookie.
/// Returns 403 on a missing or wrong token. The form body is buffered, so the
/// handler can still read it, for example with `request.urlEncodedForm()`. A
/// form body over Relic's default form limit (`FormLimits.defaults`) gets
/// Relic's 413, a malformed one its 400.
///
/// Relic middleware only fires for matched routes, so attach it at `'/'`.
///
/// ```dart
/// final app = RelicApp()
///   ..use('/', trellisCsrf(secret: 'my-secret-key'))
///   ..get('/', myHandler);
/// ```
Middleware trellisCsrf({
  required String secret,
  String cookieName = '__csrf',
  String fieldName = '_csrf',
  String headerName = 'X-CSRF-Token',
  List<String> excludedPaths = const [],
}) {
  final hmacKey = utf8.encode(secret);

  String sign(String token) => Hmac(sha256, hmacKey).convert(utf8.encode(token)).toString();

  /// The raw token of a validly signed cookie, or `null`.
  String? verifiedCookieToken(Request request) {
    final cookieValue = _parseCookie(request, cookieName);
    if (cookieValue == null) return null;
    final dotIndex = cookieValue.indexOf('.');
    if (dotIndex == -1) return null;
    final rawToken = cookieValue.substring(0, dotIndex);
    return _constantTimeEquals(cookieValue.substring(dotIndex + 1), sign(rawToken)) ? rawToken : null;
  }

  return (Handler innerHandler) {
    return (Request request) async {
      if (excludedPaths.contains(request.url.path)) {
        return innerHandler(request);
      }

      final cookieToken = verifiedCookieToken(request);

      if (_stateMethods.contains(request.method)) {
        if (cookieToken == null) return _mismatch();

        var submittedToken = request.headers[headerName]?.firstOrNull;
        var forwarded = request;
        if (submittedToken == null) {
          // Only a urlencoded form can carry the field; anything else, such as
          // a multipart upload, is left unread.
          if (request.mimeType != MimeType.urlEncoded) return _mismatch();
          // A body over the limit throws MaxBodySizeExceeded and a malformed
          // one a FormException; the Relic server answers those with 413/400.
          final bodyType = request.body.bodyType;
          final bytes = BytesBuilder(copy: false);
          await for (final chunk in request.read(maxLength: FormLimits.defaults.maxBodySize)) {
            bytes.add(chunk);
          }
          final data = bytes.takeBytes();
          // The parse consumes its body, so it reads a copy and the handler
          // gets a fresh body over the same bytes.
          final form = await request
              .copyWith(
                body: Body(bytes: data, bodyType: bodyType),
              )
              .urlEncodedForm();
          submittedToken = form.fields.raw[fieldName];
          forwarded = request.copyWith(
            body: Body(bytes: data, bodyType: bodyType),
          );
        }

        if (submittedToken == null || !_constantTimeEquals(submittedToken, cookieToken)) {
          return _mismatch();
        }
        _csrfTokenProperty[forwarded] = cookieToken;
        return innerHandler(forwarded);
      }

      // Safe method: reuse a valid token so later safe requests (CSS, images)
      // do not rotate the token already embedded in the page.
      if (cookieToken != null) {
        _csrfTokenProperty[request] = cookieToken;
        return innerHandler(request);
      }

      final rawToken = _generateToken();
      _csrfTokenProperty[request] = rawToken;
      final result = await innerHandler(request);
      if (result is! Response) return result;
      final cookie = '$cookieName=$rawToken.${sign(rawToken)}; Path=/; HttpOnly; SameSite=Strict';
      return result.copyWith(
        headers: result.headers.transform((h) {
          h['Set-Cookie'] = [...?result.headers['Set-Cookie'], cookie];
        }),
      );
    };
  };
}
