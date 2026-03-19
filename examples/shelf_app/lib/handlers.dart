import 'package:shelf/shelf.dart';
import 'package:trellis_shelf/trellis_shelf.dart';

int _counter = 0;

Map<String, dynamic> _counterContext() => {'count': _counter, 'isZero': _counter == 0};

Map<String, dynamic> _homeContext() => {
  'title': 'Home',
  'pageTitle': 'Home — Trellis + Shelf',
  'appTitle': 'Trellis + Shelf',
  ..._counterContext(),
  'features': [
    {
      'name': 'Shelf pipeline',
      'description': 'Middleware composes logging, security headers, engine access, CSRF, and hot reload.',
    },
    {
      'name': 'HTMX fragments',
      'description': 'Navigation swaps page-content, while mutations replace only the counter fragment.',
    },
    {
      'name': 'Template inheritance',
      'description': 'Base layout + child pages use tl:extends and tl:define for shared structure.',
    },
    {
      'name': 'Security defaults',
      'description': 'trellisSecurityHeaders() and trellisCsrf() protect the app without extra boilerplate.',
    },
  ],
};

Future<Response> indexPage(Request request) async {
  return renderPage(request, 'pages/index.html', _homeContext(), htmxFragment: 'page-content');
}

Future<Response> aboutPage(Request request) async {
  return renderPage(request, 'pages/about.html', {
    'title': 'About',
    'pageTitle': 'About — Trellis + Shelf',
    'appTitle': 'Trellis + Shelf',
  }, htmxFragment: 'page-content');
}

Future<Response> incrementCounter(Request request) async {
  _counter++;
  return renderFragment(request, 'pages/index.html', 'counter', _counterContext());
}

Future<Response> decrementCounter(Request request) async {
  _counter--;
  return renderFragment(request, 'pages/index.html', 'counter', _counterContext());
}

Future<Response> resetCounter(Request request) async {
  _counter = 0;
  return renderFragment(request, 'pages/index.html', 'counter', _counterContext());
}
