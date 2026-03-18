import 'package:dart_frog/dart_frog.dart';
import 'package:trellis_dart_frog/trellis_dart_frog.dart';

Future<Response> onRequest(RequestContext context) async {
  return renderPage(context, 'pages/index.html', {
    'title': 'Home',
    'message': 'Welcome to dart_frog_app!',
    'features': [
      {'name': 'File-based routing', 'description': 'Routes map to files in routes/'},
      {'name': 'Natural HTML templates', 'description': 'Templates are valid HTML'},
      {'name': 'HTMX integration', 'description': 'Dynamic updates without JavaScript frameworks'},
      {'name': 'Hot reload', 'description': 'See template changes instantly'},
    ],
  });
}
