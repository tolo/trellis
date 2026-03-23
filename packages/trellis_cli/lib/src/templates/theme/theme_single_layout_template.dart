/// Generates layouts/_default/single.html — extends base, fills content block.
///
/// Uses raw string to avoid conflicts with Trellis `${}` expressions.
String themeSingleLayoutTemplate() => r'''<!DOCTYPE html>
<html tl:extends="layouts/base.html" lang="en">
<head><title>Single</title></head>
<body>
  <main tl:define="content">
    <article>
      <h1 tl:text="${page.title}">Title</h1>
      <div tl:utext="${page.content}">Content</div>
    </article>
  </main>
</body>
</html>
''';
