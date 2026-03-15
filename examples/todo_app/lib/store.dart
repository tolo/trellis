// In-memory data store for todos and lists.

import 'models.dart';

class TodoStore {
  int _nextListId = 1;
  int _nextTodoId = 1;
  final Map<int, TodoList> _lists = {};
  final Map<int, Todo> _todos = {};

  // --- List CRUD ---

  List<TodoList> allLists() {
    final lists = _lists.values.toList();
    lists.sort((a, b) => a.position.compareTo(b.position));
    return lists;
  }

  TodoList? getList(int id) => _lists[id];

  TodoList createList(String name, {String? color}) {
    final list = TodoList(
      id: _nextListId++,
      name: name,
      color: color ?? '#4a9eff',
      position: _lists.length,
    );
    _lists[list.id] = list;
    return list;
  }

  void updateList(int id, {String? name, String? color}) {
    final list = _lists[id];
    if (list == null) return;
    if (name != null) list.name = name;
    if (color != null) list.color = color;
  }

  void deleteList(int id) {
    _lists.remove(id);
    _todos.removeWhere((_, todo) => todo.listId == id);
  }

  // --- Todo CRUD ---

  List<Todo> todosForList(int listId) {
    final todos = _todos.values.where((t) => t.listId == listId).toList();
    todos.sort((a, b) => a.position.compareTo(b.position));
    return todos;
  }

  Todo? getTodo(int id) => _todos[id];

  Todo createTodo(
    int listId,
    String title, {
    String priority = 'medium',
    DateTime? dueDate,
    String? notes,
  }) {
    final listTodos = todosForList(listId);
    final todo = Todo(
      id: _nextTodoId++,
      listId: listId,
      title: title,
      priority: priority,
      dueDate: dueDate,
      notes: notes,
      position: listTodos.length,
    );
    _todos[todo.id] = todo;
    return todo;
  }

  void toggleTodo(int id) {
    final todo = _todos[id];
    if (todo != null) todo.isCompleted = !todo.isCompleted;
  }

  void updateTodo(
    int id, {
    String? title,
    String? priority,
    String? notes,
    DateTime? dueDate,
    bool updateDueDate = false,
  }) {
    final todo = _todos[id];
    if (todo == null) return;
    if (title != null) todo.title = title;
    if (priority != null) todo.priority = priority;
    if (notes != null) todo.notes = notes;
    if (updateDueDate) todo.dueDate = dueDate;
  }

  void deleteTodo(int id) {
    _todos.remove(id);
  }

  int todoCount(int listId) =>
      _todos.values.where((t) => t.listId == listId).length;

  int completedCount(int listId) =>
      _todos.values.where((t) => t.listId == listId && t.isCompleted).length;

  // Pre-populate with demo data.
  void seed() {
    final work = createList('Work', color: '#4a9eff');
    final personal = createList('Personal', color: '#22c55e');
    createList('Shopping', color: '#f59e0b');

    createTodo(work.id, 'Review pull request', priority: 'high');
    createTodo(work.id, 'Update project documentation');
    createTodo(
      work.id,
      'Prepare sprint demo',
      priority: 'high',
      dueDate: DateTime.now().add(const Duration(days: 2)),
    );
    createTodo(work.id, 'Refactor auth module', priority: 'low');

    createTodo(personal.id, 'Go for a run');
    createTodo(
      personal.id,
      'Read chapter 5',
      dueDate: DateTime.now().add(const Duration(days: 5)),
    );
    createTodo(
      personal.id,
      'Call dentist',
      priority: 'high',
      dueDate: DateTime.now().subtract(const Duration(days: 1)),
    );
  }
}
