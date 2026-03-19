/// Generates the templates/partials/nav.html content for a Dart Frog + Trellis project.
String dartFrogNavPartialTemplate() => '''
<nav tl:fragment="nav">
  <a href="/" class="brand">Home</a>
  <div class="nav-links">
    <a href="/" hx-get="/" hx-target="#content" hx-push-url="true">Home</a>
    <a href="/about" hx-get="/about" hx-target="#content" hx-push-url="true">About</a>
  </div>
</nav>
''';
