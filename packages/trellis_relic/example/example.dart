import 'package:relic/relic.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_relic/trellis_relic.dart';

Future<Response> home(Request request, Trellis engine) async {
  return renderPage(request, engine, 'index.html', {'title': 'Hello Relic'});
}

void main() {
  final engine = Trellis(loader: MapLoader({'index.html': r'<h1 tl:text="${title}">Hello</h1>'}));

  final app = RelicApp()
    ..use('/', trellisSecurityHeaders())
    ..get('/', (request) => home(request, engine));

  print(app.runtimeType);
}
