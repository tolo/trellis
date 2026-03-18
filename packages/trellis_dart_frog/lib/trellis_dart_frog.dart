/// Dart Frog integration for the Trellis template engine.
///
/// Provides a provider middleware, response helpers, HTMX detection utilities,
/// and security middleware (headers + CSRF) for building server-rendered web
/// applications with Trellis and Dart Frog.
///
/// ```dart
/// import 'package:trellis/trellis.dart';
/// import 'package:trellis_dart_frog/trellis_dart_frog.dart';
///
/// final _engine = Trellis(loader: FileSystemLoader('templates'));
///
/// // routes/_middleware.dart
/// Handler middleware(Handler handler) {
///   return handler
///       .use(trellisProvider(_engine))
///       .use(trellisSecurityHeaders())
///       .use(trellisCsrf(secret: 'my-secret-key'));
/// }
///
/// // routes/index.dart
/// Future<Response> onRequest(RequestContext context) async {
///   return renderPage(context, 'index', {'title': 'Home'});
/// }
/// ```
library;

export 'src/htmx_helpers.dart' show isHtmxRequest, htmxTarget, htmxTrigger, isHtmxBoosted;
export 'src/provider.dart' show trellisProvider;
export 'src/request_context_utils.dart' show csrfToken, CsrfToken;
export 'src/response_helpers.dart' show renderPage, renderFragment, renderOobFragments;
export 'src/security_middleware.dart' show trellisSecurityHeaders, trellisCsrf;

// Re-export CspBuilder from trellis_shelf so users can configure CSP without
// a direct trellis_shelf dependency.
export 'package:trellis_shelf/trellis_shelf.dart' show CspBuilder;
