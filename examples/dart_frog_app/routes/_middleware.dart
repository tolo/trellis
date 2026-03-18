import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_dart_frog/trellis_dart_frog.dart';
import 'package:trellis_dev/trellis_dev.dart';

// Dev mode: set DEV=true environment variable.
// Enables file watching for live template reload.
final _devMode = Platform.environment['DEV'] == 'true';

final _loader = FileSystemLoader('templates/', devMode: _devMode);
final _engine = Trellis(loader: _loader, devMode: _devMode);
const _csp = CspBuilder(scriptSrc: "'self' 'unsafe-inline' https://cdn.jsdelivr.net");

// CSRF secret: use an environment variable in production.
// WARNING: Change this default before deploying!
final _csrfSecret = Platform.environment['CSRF_SECRET'] ?? 'dart_frog_app-dev-secret';

Handler middleware(Handler handler) {
  return handler
      .use(trellisProvider(_engine))
      .use(trellisSecurityHeaders(csp: _csp))
      .use(trellisCsrf(secret: _csrfSecret))
      .use(requestLogger())
      .use(_devMode ? fromShelfMiddleware(devMiddleware(_loader)) : (h) => h);
}
