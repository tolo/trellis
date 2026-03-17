/// Generates the layouts/_default/list.html content for a blog project.
///
/// Demonstrates: `tl:extends`, `tl:define` (slot fill), `tl:each`, `tl:if`,
/// `tl:text`, `tl:href`, and pagination nav via `${pagination.*}`.
String blogListLayoutTemplate() => r'''<!DOCTYPE html>
<html tl:extends="layouts/base.html" lang="en">
<head><title>Posts</title></head>
<body>
  <main tl:define="content">
    <h1 tl:text="${page.title}">Posts</h1>
    <ul class="post-list">
      <li tl:each="p : ${pages}">
        <article>
          <h2><a tl:href="${p.url}" tl:text="${p.title}">Post title</a></h2>
          <time tl:text="${p.date}">2024-01-01</time>
          <p tl:text="${p.summary}">Post summary.</p>
        </article>
      </li>
    </ul>
    <nav class="pagination" tl:if="${pagination}">
      <a href="#" tl:if="${pagination.hasPrev}" tl:href="${pagination.prevUrl}">← Previous</a>
      <span tl:text="'Page ' + ${pagination.page} + ' of ' + ${pagination.totalPages}">
        Page 1 of 3
      </span>
      <a href="#" tl:if="${pagination.hasNext}" tl:href="${pagination.nextUrl}">Next →</a>
    </nav>
  </main>
</body>
</html>
''';
