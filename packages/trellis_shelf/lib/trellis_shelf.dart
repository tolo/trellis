/// Shelf integration for the Trellis template engine.
///
/// Provides middleware, HTMX helpers, and security defaults for building
/// server-rendered web applications with Trellis and Shelf.
///
/// ```dart
/// import 'package:trellis/trellis.dart';
/// import 'package:trellis_shelf/trellis_shelf.dart';
///
/// final engine = Trellis();
/// final pipeline = const Pipeline()
///     .addMiddleware(trellisSecurityHeaders())
///     .addMiddleware(trellisEngine(engine))
///     .addHandler(myHandler);
/// ```
library;

export 'src/csrf_middleware.dart' show trellisCsrf;
export 'src/engine_middleware.dart' show trellisEngine, getEngine;
export 'src/htmx_helpers.dart' show isHtmxRequest, htmxTarget, htmxTrigger, isHtmxBoosted;
export 'src/request_context.dart' show csrfToken;
export 'src/response_helpers.dart' show renderPage, renderFragment, renderOobFragments;
export 'src/response_utils.dart' show htmlResponse;
export 'src/security_headers_middleware.dart' show trellisSecurityHeaders, CspBuilder;
