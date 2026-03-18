/// Generates the templates/partials/todo_list.html content for a Dart Frog + Trellis project.
///
/// Uses a raw string to avoid conflicts with Trellis `${}` and `tl:*` expressions.
/// Uses `tl:unless="${todos}"` for the empty-state check (Trellis evaluates empty
/// lists as falsy, so this shows when the list is empty).
String dartFrogTodoPartialTemplate() => r'''<div>
  <div id="todo-list" tl:fragment="todo-list">
    <ul class="todo-items">
      <li tl:each="todo : ${todos}" tl:class="${todo.done} ? 'done' : ''">
        <span tl:text="${todo.text}">Todo item</span>
        <span class="actions">
          <button hx-put="/todos"
                  hx-target="#todo-list"
                  hx-swap="outerHTML"
                  tl:attr="hx-vals={'id': '${todo.id}', '_csrf': '${csrfToken}'}"
                  tl:text="${todo.done} ? 'Undo' : 'Done'">Done</button>
          <button hx-delete="/todos"
                  hx-target="#todo-list"
                  hx-swap="outerHTML"
                  tl:attr="hx-vals={'id': '${todo.id}', '_csrf': '${csrfToken}'}">Delete</button>
        </span>
      </li>
    </ul>
    <p tl:unless="${todos}" class="placeholder">No todos yet. Add one above!</p>
  </div>
</div>
''';
