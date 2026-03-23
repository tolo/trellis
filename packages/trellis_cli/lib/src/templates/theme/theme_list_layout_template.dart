/// Generates layouts/_default/list.html — extends base, fills content block with page list.
///
/// Uses raw string to avoid conflicts with Trellis `${}` expressions.
String themeListLayoutTemplate() => r'''<!DOCTYPE html>
<html tl:extends="layouts/base.html" lang="en">
<head><title>List</title></head>
<body>
  <main tl:define="content">
    <h1 tl:text="${page.title}">Title</h1>
    <ul>
      <li tl:each="item : ${page.pages}">
        <a tl:href="@{${item.url}}" tl:text="${item.title}">Page title</a>
        <time tl:text="${item.date}">Date</time>
      </li>
    </ul>
  </main>
</body>
</html>
''';
