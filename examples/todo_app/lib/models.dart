// Data models for the todo app.

class TodoList {
  final int id;
  String name;
  String color;
  int position;

  TodoList({
    required this.id,
    required this.name,
    this.color = '#4a9eff',
    this.position = 0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'color': color,
    'position': position,
  };
}

class Todo {
  final int id;
  int listId;
  String title;
  String? notes;
  DateTime? dueDate;
  String priority; // 'low', 'medium', 'high'
  bool isCompleted;
  int position;

  Todo({
    required this.id,
    required this.listId,
    required this.title,
    this.notes,
    this.dueDate,
    this.priority = 'medium',
    this.isCompleted = false,
    this.position = 0,
  });

  bool get isOverdue =>
      dueDate != null && !isCompleted && dueDate!.isBefore(DateTime.now());

  Map<String, dynamic> toMap() => {
    'id': id,
    'listId': listId,
    'title': title,
    'notes': notes,
    'dueDate': dueDate,
    'dueDateFormatted': dueDate != null
        ? '${dueDate!.year}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}'
        : null,
    'priority': priority,
    'isCompleted': isCompleted,
    'isOverdue': isOverdue,
    'position': position,
    'dueDateInput': dueDate != null
        ? '${dueDate!.year}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}'
        : '',
  };
}
