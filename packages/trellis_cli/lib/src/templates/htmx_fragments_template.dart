/// Generates the templates/partials/htmx.html content.
///
/// Contains fragments used by HTMX endpoints. Kept in a separate partial
/// (not a page with `tl:extends`) so fragments are available to
/// `renderFragment()` without inheritance resolution.
String htmxFragmentsTemplate() => r'''
<div>
  <p tl:fragment="greeting">Hello, <strong tl:text="${name}">Name</strong>!</p>
  <p tl:fragment="status">Server is running. Time: <span tl:text="${uptime}">now</span></p>
</div>
''';
