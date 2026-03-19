import 'package:dart_frog/dart_frog.dart';
import 'package:trellis_dart_frog/trellis_dart_frog.dart';

Future<Response> onRequest(RequestContext context) async {
  return renderPage(context, 'pages/about.html', {
    'title': 'About',
    'pageTitle': 'About — Trellis + Dart Frog',
    'appTitle': 'Trellis + Dart Frog',
  }, htmxFragment: 'page-content');
}
