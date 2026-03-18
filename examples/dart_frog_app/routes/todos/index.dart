import 'package:dart_frog/dart_frog.dart';
import 'package:trellis_dart_frog/trellis_dart_frog.dart';

// In-memory todo store (replace with a database in production).
final _todos = <Map<String, dynamic>>[
  {'id': 1, 'text': 'Learn Trellis templates', 'done': false},
  {'id': 2, 'text': 'Build an HTMX app', 'done': false},
];
var _nextId = 3;

Future<Response> onRequest(RequestContext context) async {
  return switch (context.request.method) {
    HttpMethod.get => _list(context),
    HttpMethod.post => _add(context),
    HttpMethod.put => _toggle(context),
    HttpMethod.delete => _remove(context),
    _ => Future.value(Response(statusCode: 405)),
  };
}

/// GET /todos — renders the full todo list fragment.
Future<Response> _list(RequestContext context) async {
  return renderFragment(context, 'partials/todo_list.html', 'todo-list', {
    'todos': _todos,
  });
}

/// POST /todos — adds a new todo, returns updated list.
Future<Response> _add(RequestContext context) async {
  final body = await context.request.body();
  final params = Uri.splitQueryString(body);
  final text = params['text']?.trim();

  if (text != null && text.isNotEmpty) {
    _todos.add({'id': _nextId++, 'text': text, 'done': false});
  }

  return renderFragment(context, 'partials/todo_list.html', 'todo-list', {
    'todos': _todos,
  });
}

/// PUT /todos — toggles a todo's done state, returns updated list.
Future<Response> _toggle(RequestContext context) async {
  final body = await context.request.body();
  final params = Uri.splitQueryString(body);
  final id = int.tryParse(params['id'] ?? '');

  if (id != null) {
    final todo = _todos.where((t) => t['id'] == id).firstOrNull;
    if (todo != null) {
      todo['done'] = !(todo['done'] as bool);
    }
  }

  return renderFragment(context, 'partials/todo_list.html', 'todo-list', {
    'todos': _todos,
  });
}

/// DELETE /todos — removes a todo, returns updated list.
Future<Response> _remove(RequestContext context) async {
  final body = await context.request.body();
  final params = Uri.splitQueryString(body);
  final id = int.tryParse(params['id'] ?? '');

  if (id != null) {
    _todos.removeWhere((t) => t['id'] == id);
  }

  return renderFragment(context, 'partials/todo_list.html', 'todo-list', {
    'todos': _todos,
  });
}
