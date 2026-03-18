/// Generates the layouts/_default/single.html content for a blog project.
///
/// Demonstrates: `tl:extends`, `tl:define` (slot fill), `tl:text`, `tl:utext`.
String blogSingleLayoutTemplate() => r'''<!DOCTYPE html>
<html tl:extends="layouts/base.html" lang="en">
<head><title>Page</title></head>
<body>
  <main tl:define="content">
    <article>
      <h1 tl:text="${page.title}">Page Title</h1>
      <div class="content" tl:utext="${page.content}">
        <p>Page content renders here.</p>
      </div>
    </article>
  </main>
</body>
</html>
''';
