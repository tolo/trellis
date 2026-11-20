import 'dart:convert';
import 'dart:io';

import 'package:trellis/trellis.dart';

import 'embedded_assets.g.dart';

const _assetPrefix = '/trellis-ui/';

/// Root-absolute URL paths of the embedded assets served by [trellisUiRespond].
final List<String> trellisUiAssetPaths = List.unmodifiable([for (final name in assetBase64.keys) '$_assetPrefix$name']);

/// Loads embedded suite templates through the application's own engine.
///
/// Use `tl:replace` so the host's attributes and anonymous slot reach the root.
/// Shadowing managed fragments is unsupported; use tokens and part classes.
final class TrellisUiLoader implements TemplateLoader {
  @override
  Future<String> load(String name) async => loadSync(name);

  @override
  String loadSync(String name) {
    final key = name.endsWith('.html') ? name.substring(0, name.length - 5) : name;
    final encoded = fragmentBase64[key];
    if (encoded == null) throw TemplateNotFoundException(name);
    return utf8.decode(base64Decode(encoded));
  }
}

/// A framework-neutral asset response with immutable bytes and headers.
final class TrellisUiResponse {
  const TrellisUiResponse._(this.statusCode, this.headers, this.body);

  /// HTTP status, either 200 or 304.
  final int statusCode;

  /// Content type, strong ETag and revalidation cache policy.
  final Map<String, String> headers;

  /// Empty for a conditional response.
  final List<int> body;
}

/// Serves known suite paths under `/trellis-ui/`, or returns null for app routing.
///
/// A matching quoted digest in [ifNoneMatch] returns 304. Lists and the wildcard
/// use the HTTP If-None-Match semantics, including weak validators on GET.
TrellisUiResponse? trellisUiRespond(String path, {String? ifNoneMatch}) {
  if (!path.startsWith(_assetPrefix)) return null;
  final name = path.substring(_assetPrefix.length);
  final encoded = assetBase64[name];
  if (encoded == null) return null;
  final etag = '"${assetDigests[name]}"';
  final matches =
      ifNoneMatch?.split(',').map((s) => s.trim().replaceFirst(RegExp(r'^W/'), '')).any((s) => s == etag || s == '*') ??
      false;
  return TrellisUiResponse._(
    matches ? 304 : 200,
    Map.unmodifiable({
      'content-type': name.endsWith('.css') ? 'text/css; charset=utf-8' : 'text/javascript; charset=utf-8',
      'etag': etag,
      'cache-control': 'public, max-age=0, must-revalidate',
    }),
    matches ? const [] : List.unmodifiable(base64Decode(encoded)),
  );
}

/// Writes the embedded assets, replacing divergent files and keeping equal files.
///
/// App overrides belong in a separate stylesheet; generated preview assets are
/// overwritten. Filesystem failures name the target path and propagate.
void materializeTrellisUi(Directory target) {
  target.createSync(recursive: true);
  for (final name in assetBase64.keys) {
    final file = File('${target.path}/$name');
    final bytes = base64Decode(assetBase64[name]!);
    if (file.existsSync()) {
      final current = file.readAsBytesSync();
      if (current.length == bytes.length && Iterable<int>.generate(bytes.length).every((i) => bytes[i] == current[i])) {
        continue;
      }
    }
    file.writeAsBytesSync(bytes);
  }
}
