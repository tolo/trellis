/// Generates the layouts/posts/single.html content for a blog project.
///
/// Demonstrates: `tl:extends`, `tl:define` (slot fill), `tl:text` for title/date,
/// `tl:each` for tags loop, `tl:if` for conditional tags display,
/// `tl:href` for tag links, `tl:utext` for rendered Markdown content.
String blogPostLayoutTemplate() => r'''<!DOCTYPE html>
<html tl:extends="layouts/base.html" lang="en">
<head><title>Post</title></head>
<body>
  <main tl:define="content">
    <article class="post">
      <header>
        <h1 tl:text="${page.title}">Post Title</h1>
        <time tl:text="${page.date}">2024-01-01</time>
        <ul class="tags" tl:if="${page.tags}">
          <li tl:each="tag : ${page.tags}">
            <a tl:href="'/tags/' + ${tag} + '/'" tl:text="${tag}">tag</a>
          </li>
        </ul>
      </header>
      <div class="content" tl:utext="${page.content}">
        <p>Post content renders here.</p>
      </div>
    </article>
    <a href="/posts/">← All posts</a>
  </main>
</body>
</html>
''';
