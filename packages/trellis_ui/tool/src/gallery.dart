import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_ui/trellis_ui.dart';

import 'bundle.dart';

const galleryPolicy =
    "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; font-src 'self' data:; connect-src 'self'; base-uri 'none'; object-src 'none'; frame-ancestors 'none'";

/// Discovers pages from disk and renders them using the same embedded fragments as apps.
Handler galleryHandler(Directory root, {Directory? pages}) {
  final directory = pages ?? Directory('${root.path}/gallery/pages');
  final engine = Trellis(loader: TrellisUiLoader());
  String shell(String body, String title) => File('${root.path}/gallery/shell.html')
      .readAsStringSync()
      .replaceFirst('<!-- title -->', const HtmlEscape().convert(title))
      .replaceFirst('<!-- page -->', body);
  Response policy(Response response) => response.change(headers: {'content-security-policy': galleryPolicy});
  return (request) async {
    final path = request.requestedUri.path;
    final asset = trellisUiRespond(path, ifNoneMatch: request.headers['if-none-match']);
    if (asset != null) return policy(Response(asset.statusCode, body: asset.body, headers: asset.headers));
    if (path.startsWith('/static/')) {
      final name = path.substring('/static/'.length);
      if (name.contains('/') || name == '..' || name == '.') return policy(Response.notFound('Not found'));
      final file = File('${root.path}/gallery/static/$name');
      if (!file.existsSync()) return policy(Response.notFound('Not found'));
      return policy(
        Response.ok(
          file.readAsBytesSync(),
          headers: {
            'content-type': name.endsWith('.css') ? 'text/css; charset=utf-8' : 'text/javascript; charset=utf-8',
          },
        ),
      );
    }
    final pageFiles = sourceFiles(directory, '.html');
    if (path == '/') {
      final links = pageFiles.map((f) {
        final name = f.uri.pathSegments.last.replaceFirst('.html', '');
        return '<li><a href="/components/$name">${const HtmlEscape().convert(name)}</a></li>';
      }).join();
      return policy(
        Response.ok(
          shell('<h1>Trellis UI</h1><ul>$links</ul>', 'Trellis UI'),
          headers: {'content-type': 'text/html; charset=utf-8'},
        ),
      );
    }
    for (final file in pageFiles) {
      final name = file.uri.pathSegments.last.replaceFirst('.html', '');
      if (path == '/components/$name') {
        final page = engine.render(file.readAsStringSync(), const {});
        return policy(Response.ok(shell(page, name), headers: {'content-type': 'text/html; charset=utf-8'}));
      }
    }
    return policy(Response.notFound('Not found'));
  };
}
