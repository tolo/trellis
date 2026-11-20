import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_ui/trellis_ui.dart';

import 'bundle.dart';

const _fruitOptions = [
  {'value': 'apple', 'label': 'Apple'},
  {'value': 'apricot', 'label': 'Apricot'},
  {'value': 'banana', 'label': 'Banana'},
];

const galleryPolicy =
    "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; font-src 'self' data:; connect-src 'self'; base-uri 'none'; object-src 'none'; frame-ancestors 'none'";

/// Discovers pages from disk and renders them using the same embedded fragments as apps.
Handler galleryHandler(Directory root, {Directory? pages}) {
  final directory = pages ?? Directory('${root.path}/gallery/pages');
  final engine = Trellis(loader: TrellisUiLoader());
  var accordionRender = 0;
  String shell(String body, String title) => File('${root.path}/gallery/shell.html')
      .readAsStringSync()
      .replaceFirst('<!-- title -->', const HtmlEscape().convert(title))
      .replaceFirst('<!-- page -->', body);
  Response policy(Response response) => response.change(headers: {'content-security-policy': galleryPolicy});
  return (request) async {
    final requestPath = request.requestedUri.path;
    final navPrefix = requestPath.startsWith('/preview/components/') ? '/preview' : '';
    final path = requestPath.substring(navPrefix.length);
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
    if (path.startsWith('/demo/')) return policy(await _demo(request, engine, root));
    final pageFiles = sourceFiles(directory, '.html');
    if (path == '/') {
      final links = pageFiles.map((f) {
        final name = f.uri.pathSegments.last.replaceFirst('.html', '');
        return '<li><a href="/components/$name">${const HtmlEscape().convert(name)}</a></li>';
      }).join();
      return policy(_html(shell('<h1>Trellis UI</h1><ul>$links</ul>', 'Trellis UI')));
    }
    for (final file in pageFiles) {
      final name = file.uri.pathSegments.last.replaceFirst('.html', '');
      if (path == '/components/$name') {
        final page = engine.render(file.readAsStringSync(), {
          'dialogOpen': request.requestedUri.queryParameters['open'] == '1',
          'fruitOptions': _fruitOptions,
          // HTMX inserts new details before removing the old named group.
          if (name == 'accordion') 'accordionRender': ++accordionRender,
          if (name == 'navigation-menu') ...{
            'navPrefix': navPrefix,
            'navCurrent': request.requestedUri.queryParameters.containsKey('unlisted') ? null : requestPath,
          },
          'sheetSides': ['right', 'top', 'bottom', 'left'],
          'sheetUpdated': request.requestedUri.queryParameters['updated'] == '1',
          'columns': ['Name', 'Email address', 'Status'],
          'rows': [
            {'name': 'Ada Lovelace', 'email': 'ada@example.test', 'status': 'Paid'},
            {'name': 'Grace Hopper', 'email': 'grace@example.test', 'status': 'Pending'},
            {'name': 'Katherine Johnson', 'email': 'katherine@example.test', 'status': 'Paid'},
          ],
          'pages': [
            {'label': '1', 'href': '/components/pagination?page=1', 'current': false, 'ellipsis': false},
            {'label': '2', 'href': '/components/pagination?page=2', 'current': false, 'ellipsis': false},
            {'label': '3', 'href': '/components/pagination?page=3', 'current': true, 'ellipsis': false},
            {'label': '', 'href': '', 'current': false, 'ellipsis': true},
            {'label': '8', 'href': '/components/pagination?page=8', 'current': false, 'ellipsis': false},
          ],
          'items': [
            {'label': 'Home', 'href': '/', 'current': false},
            {'label': 'Components', 'href': '/components/button', 'current': false},
            {'label': 'Breadcrumb', 'href': '', 'current': true},
          ],
        });
        return policy(_html(shell(page, name)));
      }
    }
    return policy(Response.notFound('Not found'));
  };
}

Future<Response> _demo(Request request, Trellis engine, Directory root) async {
  final path = request.requestedUri.path;
  if (path == '/demo/options') return _options(request, engine);
  final query = request.requestedUri.queryParameters;
  final body = switch (path) {
    '/demo/dialog' =>
      query['close'] == '1'
          ? ''
          : engine.render(File('${root.path}/gallery/responses/dialog.html').readAsStringSync(), const {}),
    '/demo/alert-dialog' => await engine.renderFileFragment(
      'trellis-ui/alert-dialog',
      fragment: 'alertDialog',
      context: {
        'id': 'menu-alert-dialog',
        'title': 'Delete project?',
        'description': 'This permanently removes the project and its settings.',
        'open': true,
      },
    ),
    '/demo/toast' => await engine.renderFileFragment(
      'trellis-ui/toast',
      fragment: 'toast',
      context: {
        'type': 'success',
        'title': 'Changes saved',
        'description': 'Your changes are ready.',
        'duration': int.tryParse(query['duration'] ?? '') ?? 0,
        'outOfBand': true,
      },
    ),
    _ => null,
  };
  return body == null ? Response.notFound('Not found') : _html(body);
}

Future<Response> _options(Request request, Trellis engine) async {
  final query = request.requestedUri.queryParameters;
  if (query['mode'] == 'error') return Response.internalServerError(body: 'Options unavailable');
  if (query['mode'] == 'abort') {
    // Close the HTTP connection to exercise htmx's real network-error path.
    request.hijack((channel) => unawaited(channel.sink.close()));
  }
  final term = (query['q'] ?? '').trim().toLowerCase();
  final matches = query['mode'] == 'empty'
      ? const <Map<String, String>>[]
      : _fruitOptions.where((option) => option['label']!.toLowerCase().startsWith(term)).toList();
  return _html(
    await engine.renderFileFragment(
      'trellis-ui/combobox',
      fragment: 'comboboxOptions',
      context: {'id': query['id'] ?? 'fruit', 'options': matches},
    ),
  );
}

Response _html(String body) => Response.ok(body, headers: {'content-type': 'text/html; charset=utf-8'});
