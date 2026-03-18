/// Generates the templates/pages/index.html content for a Dart Frog + Trellis project.
///
/// Uses a raw string to avoid conflicts with Trellis `${}` and `tl:*` expressions.
String dartFrogIndexPageTemplate() => r'''<html tl:extends="layouts/base.html">
<body>
  <main tl:define="content">
    <section class="hero">
      <h2 tl:text="${message}">Welcome message</h2>
    </section>

    <section class="features">
      <h3>Features</h3>
      <ul>
        <li tl:each="feature : ${features}">
          <strong tl:text="${feature.name}">Feature name</strong>
          <span tl:text="${feature.description}">Feature description</span>
        </li>
      </ul>
    </section>

    <!-- Todo app — demonstrates HTMX with Trellis fragments -->
    <section class="todos">
      <h3>Todo List</h3>
      <form hx-post="/todos" hx-target="#todo-list" hx-swap="outerHTML">
        <input type="hidden" name="_csrf" tl:attr="value=${csrfToken}">
        <input type="text" name="text" placeholder="Add a new todo..." required>
        <button type="submit">Add</button>
      </form>
      <div id="todo-list"
           hx-get="/todos"
           hx-trigger="load"
           hx-swap="outerHTML">
        <p class="placeholder">Loading todos...</p>
      </div>
    </section>
  </main>
</body>
</html>
''';
