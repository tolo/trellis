/// Generates example/layouts/home.html — simple self-contained preview layout.
///
/// Uses raw string to avoid conflicts with Trellis `${}` expressions.
String themeExampleLayoutTemplate() => r'''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title tl:text="${page.title}">Theme Preview</title>
</head>
<body>
  <h1 tl:text="${page.title}">Title</h1>
  <div tl:utext="${page.content}">Content</div>
</body>
</html>
''';
