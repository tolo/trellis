/// Generates the layouts/home.html content for a blog project.
///
/// Demonstrates: `tl:extends`, `tl:define` (slot fill), `tl:each`, `tl:if`,
/// `tl:text`, `tl:utext`, `tl:href`.
String blogHomeLayoutTemplate() => r'''<!DOCTYPE html>
<html tl:extends="layouts/base.html" lang="en">
<head><title>Home</title></head>
<body>
  <main tl:define="content">
    <section class="hero">
      <h1 tl:text="${page.title}">Welcome</h1>
      <div tl:utext="${page.content}"><p>Welcome to this blog.</p></div>
    </section>
    <section class="recent-posts">
      <h2>Recent Posts</h2>
      <ul class="post-list">
        <li tl:each="p : ${pages}">
          <article>
            <h3><a tl:href="${p.url}" tl:text="${p.title}">Post title</a></h3>
            <time tl:text="${p.date}">2024-01-01</time>
            <p tl:text="${p.summary}">Post summary.</p>
          </article>
        </li>
      </ul>
      <a href="/posts/">All posts →</a>
    </section>
  </main>
</body>
</html>
''';
