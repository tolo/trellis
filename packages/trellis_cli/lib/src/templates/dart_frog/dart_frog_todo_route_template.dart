/// Generates the routes/todos/index.dart content for a Dart Frog + Trellis project.
///
/// Demonstrates HTMX CRUD endpoints: list, add, toggle, delete.
/// Uses regular string with \$ escaping for Dart interpolation in generated code.
String dartFrogTodoRouteTemplate() =>
    "import 'package:dart_frog/dart_frog.dart';\n"
    "import 'package:trellis_dart_frog/trellis_dart_frog.dart';\n"
    '\n'
    '// In-memory todo store (replace with a database in production).\n'
    'final _todos = <Map<String, dynamic>>[\n'
    "  {'id': 1, 'text': 'Learn Trellis templates', 'done': false},\n"
    "  {'id': 2, 'text': 'Build an HTMX app', 'done': false},\n"
    '];\n'
    'var _nextId = 3;\n'
    '\n'
    'Future<Response> onRequest(RequestContext context) async {\n'
    '  return switch (context.request.method) {\n'
    '    HttpMethod.get => _list(context),\n'
    '    HttpMethod.post => _add(context),\n'
    '    HttpMethod.put => _toggle(context),\n'
    '    HttpMethod.delete => _remove(context),\n'
    '    _ => Future.value(Response(statusCode: 405)),\n'
    '  };\n'
    '}\n'
    '\n'
    '/// GET /todos \u2014 renders the full todo list fragment.\n'
    'Future<Response> _list(RequestContext context) async {\n'
    "  return renderFragment(context, 'partials/todo_list.html', 'todo-list', {\n"
    "    'todos': _todos,\n"
    '  });\n'
    '}\n'
    '\n'
    '/// POST /todos \u2014 adds a new todo, returns updated list.\n'
    'Future<Response> _add(RequestContext context) async {\n'
    '  final body = await context.request.body();\n'
    '  final params = Uri.splitQueryString(body);\n'
    "  final text = params['text']?.trim();\n"
    '\n'
    '  if (text != null && text.isNotEmpty) {\n'
    "    _todos.add({'id': _nextId++, 'text': text, 'done': false});\n"
    '  }\n'
    '\n'
    "  return renderFragment(context, 'partials/todo_list.html', 'todo-list', {\n"
    "    'todos': _todos,\n"
    '  });\n'
    '}\n'
    '\n'
    '/// PUT /todos \u2014 toggles a todo\'s done state, returns updated list.\n'
    'Future<Response> _toggle(RequestContext context) async {\n'
    '  final body = await context.request.body();\n'
    '  final params = Uri.splitQueryString(body);\n'
    "  final id = int.tryParse(params['id'] ?? '');\n"
    '\n'
    '  if (id != null) {\n'
    "    final todo = _todos.where((t) => t['id'] == id).firstOrNull;\n"
    '    if (todo != null) {\n'
    "      todo['done'] = !(todo['done'] as bool);\n"
    '    }\n'
    '  }\n'
    '\n'
    "  return renderFragment(context, 'partials/todo_list.html', 'todo-list', {\n"
    "    'todos': _todos,\n"
    '  });\n'
    '}\n'
    '\n'
    '/// DELETE /todos \u2014 removes a todo, returns updated list.\n'
    'Future<Response> _remove(RequestContext context) async {\n'
    '  final body = await context.request.body();\n'
    '  final params = Uri.splitQueryString(body);\n'
    "  final id = int.tryParse(params['id'] ?? '');\n"
    '\n'
    '  if (id != null) {\n'
    "    _todos.removeWhere((t) => t['id'] == id);\n"
    '  }\n'
    '\n'
    "  return renderFragment(context, 'partials/todo_list.html', 'todo-list', {\n"
    "    'todos': _todos,\n"
    '  });\n'
    '}\n';
