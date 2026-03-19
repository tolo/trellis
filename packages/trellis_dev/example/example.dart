import 'package:shelf/shelf.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_dev/trellis_dev.dart';

void main() {
  final loader = FileSystemLoader('templates', devMode: true);

  final handler = const Pipeline()
      .addMiddleware(devMiddleware(loader))
      .addHandler(
        (_) => Response.ok('<html><body>Hello</body></html>', headers: {'content-type': 'text/html; charset=utf-8'}),
      );

  print(handler);
}
