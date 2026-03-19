import 'package:dart_frog/dart_frog.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_dart_frog/trellis_dart_frog.dart';

final _engine = Trellis(loader: MapLoader({'index.html': r'<h1 tl:text="${title}">Hello</h1>'}));

Handler middleware(Handler handler) {
  return handler.use(trellisProvider(_engine)).use(trellisSecurityHeaders()).use(trellisCsrf(secret: 'dev-secret'));
}

Future<Response> onRequest(RequestContext context) async {
  return renderPage(context, 'index.html', {'title': 'Hello Dart Frog'});
}

void main() {
  print(middleware(onRequest));
}
