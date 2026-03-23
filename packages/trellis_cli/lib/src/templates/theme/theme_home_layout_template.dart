/// Generates layouts/home.html — extends base, fills content block with hero and page list.
///
/// Uses raw string to avoid conflicts with Trellis `${}` expressions.
String themeHomeLayoutTemplate() => r'''<!DOCTYPE html>
<html tl:extends="layouts/base.html" lang="en">
<head><title>Home</title></head>
<body>
  <main tl:define="content">
    <section style="padding: 2rem 0;">
      <h1 tl:text="${site.title}">Site Title</h1>
      <p tl:if="${site.description}" tl:text="${site.description}">Description</p>
    </section>

    <section>
      <ul>
        <li tl:each="item : ${page.pages}">
          <a tl:href="@{${item.url}}" tl:text="${item.title}">Page title</a>
        </li>
      </ul>
    </section>
  </main>
</body>
</html>
''';
