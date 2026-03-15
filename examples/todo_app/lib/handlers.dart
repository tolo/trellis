// Route handlers for the todo app.
//
// ## Fragment rendering strategy
//
// This app uses two different partial-render strategies depending on what changed:
//
//   • Todo CRUD (create/toggle/update/delete): renders `todo-list` + OOB `sidebar`.
//     The header and quick-add form don't need updating, so we avoid re-rendering them.
//
//   • List navigation/mutation (select/create/update/delete): renders `main-content` +
//     OOB `sidebar`. This replaces the entire main area — including the header, color
//     indicator, search bar and quick-add form — because the active list has changed.
//
// The sidebar is always included as an OOB fragment (hx-swap-oob="true") so that
// todo counts and the active-list highlight stay in sync after every mutation.

import 'package:shelf/shelf.dart';
import 'package:trellis/trellis.dart';

import 'models.dart';
import 'store.dart';

// Build context map with common data for all renders.
//
// The context is a plain Map<String, dynamic> — Trellis uses no reflection, so
// all data passed to templates must be explicitly included here.
//
// A few things worth noting:
//   • `isActive` is added to each list map so the template can apply an 'active'
//     CSS class without doing any ID comparison inside the template expression.
//   • `todoCount` is an integer, not a reference to the `todos` list. Trellis
//     treats empty lists as truthy (unlike Thymeleaf), so `tl:if="${todos}"` would
//     never hide the todo list even when empty. Using `tl:if="${todoCount}"` (where
//     0 is falsy) is the correct pattern for empty-collection guards in Trellis.
Map<String, dynamic> _buildContext(TodoStore store, {int? activeListId}) {
  final lists = store.allLists();
  final activeList = activeListId != null
      ? store.getList(activeListId)
      : (lists.isNotEmpty ? lists.first : null);

  final todos = activeList != null
      ? store.todosForList(activeList.id)
      : <Todo>[];

  return {
    'title': activeList != null
        ? '${activeList.name} — Trellis Todo'
        : 'Trellis Todo',
    'lists': lists
        .map(
          (l) => {
            ...l.toMap(),
            'todoCount': store.todoCount(l.id),
            'completedCount': store.completedCount(l.id),
            'isActive': activeList?.id == l.id,
          },
        )
        .toList(),
    'activeList': activeList?.toMap(),
    'todos': todos.map((t) => t.toMap()).toList(),
    'todoCount': todos.length,
    'completedCount': todos.where((t) => t.isCompleted).length,
  };
}

// Returns true when the request originated from HTMX (sent via hx-get/post/etc.).
// Used to decide between a full-page render and a fragment-only response.
bool _isHtmx(Request request) => request.headers['hx-request'] == 'true';

Response _html(String body, {int statusCode = 200}) => Response(
  statusCode,
  body: body,
  headers: {'content-type': 'text/html; charset=utf-8'},
);

// Renders the `todo-list` fragment plus the `sidebar` as an OOB fragment.
// Used for todo CRUD operations where only the list content and sidebar counts change.
Future<String> _renderTodoListFragments(
  Trellis engine,
  Map<String, dynamic> context,
) async {
  final source = await engine.loader.load('app.html');
  return engine.renderFragments(
    source,
    fragments: ['todo-list', 'sidebar'],
    context: context,
  );
}

// Renders the `main-content` fragment plus the `sidebar` as an OOB fragment.
// Used when the active list changes so the header, color bar and forms are refreshed.
Future<String> _renderMainContentFragments(
  Trellis engine,
  Map<String, dynamic> context,
) async {
  final source = await engine.loader.load('app.html');
  return engine.renderFragments(
    source,
    fragments: ['main-content', 'sidebar'],
    context: context,
  );
}

// Renders only the `todo-list` fragment (no sidebar OOB).
// Used for search results — the sidebar counts don't change during a search.
Future<String> _renderTodoListFragment(
  Trellis engine,
  Map<String, dynamic> context,
) async {
  final source = await engine.loader.load('app.html');
  return engine.renderFragment(source, fragment: 'todo-list', context: context);
}

// GET / -- Full page render.
//
// When accessed directly (no HX-Request header) the full page is rendered.
// When HTMX navigates here (e.g. after a redirect), only the main-content +
// sidebar fragments are returned for an in-place swap.
Future<Response> appPage(
  Request request,
  Trellis engine,
  TodoStore store,
) async {
  final listIdParam = request.url.queryParameters['list'];
  final listId = listIdParam != null ? int.tryParse(listIdParam) : null;
  final context = _buildContext(store, activeListId: listId);

  if (_isHtmx(request)) {
    final html = await _renderMainContentFragments(engine, context);
    return _html(html);
  }

  final html = await engine.renderFile('app.html', context);
  return _html(html);
}

// GET /lists/:id -- Select a list (HTMX partial swap).
Future<Response> selectList(
  Request request,
  Trellis engine,
  TodoStore store,
  String id,
) async {
  final listId = int.tryParse(id);
  if (listId == null) return Response(400, body: 'Invalid list ID');

  final context = _buildContext(store, activeListId: listId);
  final html = await _renderMainContentFragments(engine, context);
  return _html(html);
}

// POST /todos -- Create a new todo.
Future<Response> createTodo(
  Request request,
  Trellis engine,
  TodoStore store,
) async {
  final body = await request.readAsString();
  final params = Uri.splitQueryString(body);

  final listId = int.tryParse(params['listId'] ?? '');
  final title = params['title']?.trim();

  if (listId == null || title == null || title.isEmpty) {
    return Response(400, body: 'Missing listId or title');
  }

  final priority = params['priority'] ?? 'medium';
  store.createTodo(listId, title, priority: priority);

  final context = _buildContext(store, activeListId: listId);
  final html = await _renderTodoListFragments(engine, context);
  return _html(html);
}

// PUT /todos/:id/toggle -- Toggle a todo's completed state.
Future<Response> toggleTodo(
  Request request,
  Trellis engine,
  TodoStore store,
  String id,
) async {
  final todoId = int.tryParse(id);
  if (todoId == null) return Response(400, body: 'Invalid todo ID');

  final todo = store.getTodo(todoId);
  if (todo == null) return Response.notFound('Todo not found');

  store.toggleTodo(todoId);

  final context = _buildContext(store, activeListId: todo.listId);
  final html = await _renderTodoListFragments(engine, context);
  return _html(html);
}

// DELETE /todos/:id -- Delete a todo.
Future<Response> deleteTodo(
  Request request,
  Trellis engine,
  TodoStore store,
  String id,
) async {
  final todoId = int.tryParse(id);
  if (todoId == null) return Response(400, body: 'Invalid todo ID');

  final todo = store.getTodo(todoId);
  if (todo == null) return Response.notFound('Todo not found');

  final listId = todo.listId;
  store.deleteTodo(todoId);

  final context = _buildContext(store, activeListId: listId);
  final html = await _renderTodoListFragments(engine, context);
  return _html(html);
}

// POST /lists -- Create a new list.
Future<Response> createList(
  Request request,
  Trellis engine,
  TodoStore store,
) async {
  final body = await request.readAsString();
  final params = Uri.splitQueryString(body);

  final name = params['name']?.trim();
  if (name == null || name.isEmpty) {
    return Response(400, body: 'Missing list name');
  }

  final color = params['color'] ?? '#4a9eff';
  final newList = store.createList(name, color: color);

  final context = _buildContext(store, activeListId: newList.id);
  final html = await _renderMainContentFragments(engine, context);
  return _html(html);
}

// DELETE /lists/:id -- Delete a list and all its todos.
Future<Response> deleteList(
  Request request,
  Trellis engine,
  TodoStore store,
  String id,
) async {
  final listId = int.tryParse(id);
  if (listId == null) return Response(400, body: 'Invalid list ID');

  store.deleteList(listId);

  // No activeListId — context defaults to the first remaining list (or no list).
  final context = _buildContext(store);
  final html = await _renderMainContentFragments(engine, context);
  return _html(html);
}

// PUT /todos/:id -- Update a todo's title, priority and due date.
Future<Response> updateTodo(
  Request request,
  Trellis engine,
  TodoStore store,
  String id,
) async {
  final todoId = int.tryParse(id);
  if (todoId == null) return Response(400, body: 'Invalid todo ID');

  final todo = store.getTodo(todoId);
  if (todo == null) return Response.notFound('Todo not found');

  final body = await request.readAsString();
  final params = Uri.splitQueryString(body);

  final title = params['title']?.trim();
  if (title == null || title.isEmpty) {
    return Response(400, body: 'Missing title');
  }

  final priority = params['priority'] ?? 'medium';
  final dueDateStr = params['dueDate']?.trim();
  // An empty dueDate string means "clear the due date"; null means not provided.
  // updateDueDate: true tells the store to always apply the value (even null).
  final dueDate = (dueDateStr != null && dueDateStr.isNotEmpty)
      ? DateTime.tryParse(dueDateStr)
      : null;

  store.updateTodo(
    todoId,
    title: title,
    priority: priority,
    dueDate: dueDate,
    updateDueDate: true,
  );

  final context = _buildContext(store, activeListId: todo.listId);
  final html = await _renderTodoListFragments(engine, context);
  return _html(html);
}

// PUT /lists/:id -- Update a list's name and color.
Future<Response> updateList(
  Request request,
  Trellis engine,
  TodoStore store,
  String id,
) async {
  final listId = int.tryParse(id);
  if (listId == null) return Response(400, body: 'Invalid list ID');

  final body = await request.readAsString();
  final params = Uri.splitQueryString(body);

  final name = params['name']?.trim();
  if (name == null || name.isEmpty) {
    return Response(400, body: 'Missing list name');
  }

  final color = params['color'] ?? '#4a9eff';
  store.updateList(listId, name: name, color: color);

  final context = _buildContext(store, activeListId: listId);
  final html = await _renderMainContentFragments(engine, context);
  return _html(html);
}

// GET /search -- Search todos by title.
//
// Filtering is applied to the already-built context rather than in the store,
// keeping the store query-free. Note that `todoCount` must be updated alongside
// `todos` so the empty-state condition (`tl:unless="${todoCount}"`) stays correct.
Future<Response> searchTodos(
  Request request,
  Trellis engine,
  TodoStore store,
) async {
  final query = (request.url.queryParameters['q'] ?? '').trim().toLowerCase();
  final listIdParam = request.url.queryParameters['list'];
  final listId = listIdParam != null ? int.tryParse(listIdParam) : null;

  final context = _buildContext(store, activeListId: listId);

  if (query.isNotEmpty) {
    final todos = context['todos'] as List;
    final filtered = todos
        .where((t) => (t['title'] as String).toLowerCase().contains(query))
        .toList();
    context['todos'] = filtered;
    context['todoCount'] = filtered.length;
    context['searchQuery'] = query;
  }

  final html = await _renderTodoListFragment(engine, context);
  return _html(html);
}
