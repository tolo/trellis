import 'package:relic/relic.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_relic/trellis_relic.dart';

// In-memory counter state. In a real app this would be session-scoped
// or stored in a database.
int _counter = 0;

Map<String, dynamic> _counterContext() => {
  'count': _counter,
  'isZero': _counter == 0,
};

/// GET / — Home page with counter.
///
/// Full page on direct request; page-content fragment only on HTMX navigation.
Future<Response> homePage(Request request, Trellis engine) async {
  final context = {
    'title': 'Home',
    'pageTitle': 'Home — Trellis + Relic',
    'appTitle': 'Trellis + Relic',
    ..._counterContext(),
  };

  if (isHtmxRequest(request)) {
    // HTMX navigation — return page content fragment only.
    return renderFragment(
      request,
      engine,
      'index.html',
      'page-content',
      context,
    );
  }

  return renderPage(request, engine, 'index.html', context);
}

/// GET /about — About page.
Future<Response> aboutPage(Request request, Trellis engine) async {
  final context = {
    'title': 'About',
    'pageTitle': 'About — Trellis + Relic',
    'appTitle': 'Trellis + Relic',
  };

  if (isHtmxRequest(request)) {
    return renderFragment(
      request,
      engine,
      'about.html',
      'page-content',
      context,
    );
  }

  return renderPage(request, engine, 'about.html', context);
}

/// POST /counter/increment — Increment counter, return counter fragment.
Future<Response> incrementCounter(Request request, Trellis engine) async {
  _counter++;
  return renderFragment(
    request,
    engine,
    'index.html',
    'counter',
    _counterContext(),
  );
}

/// POST /counter/decrement — Decrement counter, return counter fragment.
Future<Response> decrementCounter(Request request, Trellis engine) async {
  _counter--;
  return renderFragment(
    request,
    engine,
    'index.html',
    'counter',
    _counterContext(),
  );
}

/// POST /counter/reset — Reset counter to zero, return counter fragment.
Future<Response> resetCounter(Request request, Trellis engine) async {
  _counter = 0;
  return renderFragment(
    request,
    engine,
    'index.html',
    'counter',
    _counterContext(),
  );
}
