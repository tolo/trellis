import 'package:shelf/shelf.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_shelf/trellis_shelf.dart';

void main() {
  final engine = Trellis(loader: MapLoader({'index.html': r'<h1 tl:text="${title}">Hello</h1>'}));

  final handler = const Pipeline()
      .addMiddleware(trellisSecurityHeaders())
      .addMiddleware(trellisEngine(engine))
      .addMiddleware(trellisCsrf(secret: 'dev-secret'))
      .addHandler((request) => renderPage(request, 'index.html', {'title': 'Hello Shelf'}));

  print(handler);
}
