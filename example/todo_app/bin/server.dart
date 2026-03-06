// Trellis + Shelf + HTMX Todo App
//
// Run: dart run bin/server.dart
// Then open http://localhost:8080 in your browser.

import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:trellis/trellis.dart';

import 'package:trellis_todo_example/handlers.dart';
import 'package:trellis_todo_example/store.dart';

String _formatDate(dynamic v) {
  if (v == null) return '';
  if (v is DateTime) {
    final now = DateTime.now();
    final diff = v.difference(now).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
  }
  return v.toString();
}

void main() async {
  final store = TodoStore()..seed();

  // Resolve directories relative to the script location.
  final scriptDir = File(Platform.script.toFilePath()).parent.parent.path;
  final templatesDir = '$scriptDir/templates';
  final staticDir = '$scriptDir/static';

  // FileSystemLoader resolves template names (e.g. 'app.html') relative to
  // templatesDir. cache: false means templates are re-read on every request,
  // which is convenient during development. Set cache: true in production for
  // a significant performance gain (parsed DOM trees are reused across requests).
  //
  // filters: custom filter functions callable from template expressions via the
  // pipe syntax — e.g. ${todo.dueDate | date} or ${todo.priority | capitalize}.
  // Filters receive the raw context value and return a display string.
  final engine = Trellis(
    loader: FileSystemLoader(templatesDir),
    cache: false,
    filters: {
      'date': _formatDate,
      'capitalize': (dynamic v) {
        final s = v?.toString() ?? '';
        return s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
      },
    },
  );

  final router = Router()
    ..get('/', (Request req) => appPage(req, engine, store))
    ..get('/lists/<id>', (Request req, String id) => selectList(req, engine, store, id))
    ..post('/todos', (Request req) => createTodo(req, engine, store))
    ..put('/todos/<id>/toggle', (Request req, String id) => toggleTodo(req, engine, store, id))
    ..put('/todos/<id>', (Request req, String id) => updateTodo(req, engine, store, id))
    ..delete('/todos/<id>', (Request req, String id) => deleteTodo(req, engine, store, id))
    ..post('/lists', (Request req) => createList(req, engine, store))
    ..put('/lists/<id>', (Request req, String id) => updateList(req, engine, store, id))
    ..delete('/lists/<id>', (Request req, String id) => deleteList(req, engine, store, id))
    ..get('/search', (Request req) => searchTodos(req, engine, store));

  // Cascade tries each handler in order: static files first (CSS, images, etc.),
  // then the app router. This means requests for /styles.css are served directly
  // from disk without passing through the router.
  final staticHandler = createStaticHandler(staticDir, defaultDocument: 'index.html');
  final cascade = Cascade().add(staticHandler).add(router.call);

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(cascade.handler);

  final server = await shelf_io.serve(handler, 'localhost', 8080);
  print('Todo app running at http://localhost:${server.port}');
}
