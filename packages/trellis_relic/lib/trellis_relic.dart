/// Serverpod Relic integration for the Trellis template engine.
///
/// Provides response helpers, HTMX detection, and security headers
/// for building server-rendered web applications with Trellis and Relic.
///
/// ```dart
/// import 'package:relic/relic.dart';
/// import 'package:trellis/trellis.dart';
/// import 'package:trellis_relic/trellis_relic.dart';
///
/// final engine = Trellis();
///
/// void main() async {
///   final app = RelicApp()
///     ..use('/', trellisSecurityHeaders())
///     ..get('/', (request) async {
///       return renderPage(request, engine, 'pages/index', {
///         'title': 'Home',
///       });
///     });
///
///   await app.serve(port: 8080);
/// }
/// ```
library;

export 'src/htmx_helpers.dart' show isHtmxRequest, htmxTarget, htmxTrigger, isHtmxBoosted;
export 'src/response_helpers.dart' show renderPage, renderFragment, renderOobFragments;
export 'src/response_utils.dart' show htmlResponse;
export 'src/security_headers_middleware.dart' show trellisSecurityHeaders, CspBuilder;
