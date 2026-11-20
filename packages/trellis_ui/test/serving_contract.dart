import 'package:crypto/crypto.dart';
import 'package:test/test.dart';
import 'package:trellis_ui/trellis_ui.dart';

typedef Served = ({int status, Map<String, String> headers, List<int> body});

Future<void> servingContract(Future<Served> Function(String, Map<String, String>) get) async {
  for (final name in ['trellis-ui.css', 'trellis-ui.js', 'htmx-indicator.css']) {
    final path = '/trellis-ui/$name';
    final response = await get(path, {});
    expect(response.status, 200, reason: path);
    expect(response.body, trellisUiRespond(path)!.body);
    expect(
      response.headers['content-type'],
      name.endsWith('.css') ? 'text/css; charset=utf-8' : 'text/javascript; charset=utf-8',
    );
    final etag = '"${sha256.convert(response.body)}"';
    expect(response.headers['etag'], etag);
    final cached = await get(path, {'if-none-match': etag});
    expect(cached.status, 304);
    expect(cached.body, isEmpty);
  }
  for (final path in ['/trellis-ui/nope.css', '/other.css']) {
    expect((await get(path, {})).status, 404, reason: path);
  }
}
