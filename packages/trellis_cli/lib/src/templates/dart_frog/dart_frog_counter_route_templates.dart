/// Generates the routes/counter/increment.dart content for a Dart Frog + Trellis project.
String dartFrogIncrementRouteTemplate(String projectName) =>
    "import 'package:dart_frog/dart_frog.dart';\n"
    "import 'package:$projectName/counter_state.dart';\n"
    "import 'package:trellis_dart_frog/trellis_dart_frog.dart';\n"
    '\n'
    'Future<Response> onRequest(RequestContext context) async {\n'
    '  if (context.request.method != HttpMethod.post) {\n'
    '    return Response(statusCode: 405);\n'
    '  }\n'
    '\n'
    '  incrementCounter();\n'
    "  return renderFragment(context, 'pages/index.html', 'counter', counterContext());\n"
    '}\n';

/// Generates the routes/counter/decrement.dart content for a Dart Frog + Trellis project.
String dartFrogDecrementRouteTemplate(String projectName) =>
    "import 'package:dart_frog/dart_frog.dart';\n"
    "import 'package:$projectName/counter_state.dart';\n"
    "import 'package:trellis_dart_frog/trellis_dart_frog.dart';\n"
    '\n'
    'Future<Response> onRequest(RequestContext context) async {\n'
    '  if (context.request.method != HttpMethod.post) {\n'
    '    return Response(statusCode: 405);\n'
    '  }\n'
    '\n'
    '  decrementCounter();\n'
    "  return renderFragment(context, 'pages/index.html', 'counter', counterContext());\n"
    '}\n';

/// Generates the routes/counter/reset.dart content for a Dart Frog + Trellis project.
String dartFrogResetRouteTemplate(String projectName) =>
    "import 'package:dart_frog/dart_frog.dart';\n"
    "import 'package:$projectName/counter_state.dart';\n"
    "import 'package:trellis_dart_frog/trellis_dart_frog.dart';\n"
    '\n'
    'Future<Response> onRequest(RequestContext context) async {\n'
    '  if (context.request.method != HttpMethod.post) {\n'
    '    return Response(statusCode: 405);\n'
    '  }\n'
    '\n'
    '  resetCounter();\n'
    "  return renderFragment(context, 'pages/index.html', 'counter', counterContext());\n"
    '}\n';
