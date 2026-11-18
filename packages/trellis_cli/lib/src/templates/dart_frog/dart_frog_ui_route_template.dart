import '../htmx_asset.dart';
import '../ui_scaffold_template.dart';

String dartFrogUiRouteTemplate(String projectName) =>
    '''
import 'package:dart_frog/dart_frog.dart';
import 'package:trellis_dart_frog/trellis_dart_frog.dart';

Future<Response> onRequest(RequestContext context) => renderPage(
  context,
  'pages/ui.html',
  {'pageTitle': 'Components — $projectName'},
  htmxFragment: 'page-content',
);
''';

String dartFrogUiEntrypointTemplate({required bool htmxCdn}) =>
    '''
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:trellis_dart_frog/trellis_dart_frog.dart';
import 'package:trellis_ui/trellis_ui.dart';

const _csp = ${scaffoldStrictCsp(htmxCdn: htmxCdn, ui: true)};

Future<void> init(InternetAddress _, int _) async {
  if (Platform.environment['DEV'] == 'true') {
    materializeTrellisUi(Directory('$publicUiPreview'));
  }
}

Future<HttpServer> run(Handler handler, InternetAddress address, int port) {
  // Dart Frog's cascade checks public/ before routes. Reserve the suite prefix
  // here so previews on disk cannot shadow the binary's assets. A framework
  // hook before static serving would let this use route middleware directly.
  return serve(_withUiAssets(handler).use(trellisSecurityHeaders(csp: _csp)), address, port);
}

Handler _withUiAssets(Handler next) => (context) {
  final request = context.request;
  final path = request.uri.path;
  if (!path.startsWith('/trellis-ui/')) return next(context);
  if (request.method != HttpMethod.get && request.method != HttpMethod.head) {
    return Response(statusCode: 404);
  }
  final asset = trellisUiRespond(path, ifNoneMatch: request.headers['if-none-match']);
  if (asset == null) return Response(statusCode: 404);
  return Response.bytes(statusCode: asset.statusCode, headers: asset.headers, body: asset.body);
};
''';
