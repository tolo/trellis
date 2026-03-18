/// Markdown content template functions for the blog starter project.
library;

/// Generates the content/_index.md content (home page).
String blogHomeContentTemplate(String projectName) {
  final title = projectName.replaceAll('_', ' ');
  return '''---
title: Welcome to $title
---

A personal blog built with [Trellis](https://pub.dev/packages/trellis),
a Dart-native template engine and static site generator.
''';
}

/// Generates the content/about.md content.
String blogAboutContentTemplate(String projectName) {
  final title = projectName.replaceAll('_', ' ');
  return '''---
title: About
---

## About $title

This blog is built with [Trellis](https://pub.dev/packages/trellis) —
a static site generator for Dart.

Trellis uses natural HTML templates, Markdown content with YAML front matter,
and produces fast, clean static HTML.
''';
}

/// Generates the content/posts/_index.md content (posts section).
String blogPostsIndexTemplate() => '''
---
title: Blog
---

All posts, newest first.
''';

/// Generates the content/posts/welcome.md content (first sample post).
String blogWelcomePostTemplate() => '''
---
title: Welcome to My Blog
date: 2026-03-15
tags:
  - blog
  - trellis
summary: A first post introducing this blog built with Trellis.
---

Welcome to your new blog! This site was generated with
[Trellis](https://pub.dev/packages/trellis), a Dart-native
template engine and static site generator.

## What is Trellis?

Trellis uses natural HTML templates — your layouts are valid HTML
that browsers can render as prototypes without a server.

## Getting Started

- Edit `content/` to add your own pages and posts
- Customize `layouts/` to change the look
- Run `trellis build` to generate your site
- Run `trellis serve` to preview it locally
''';

/// Generates the content/posts/getting-started.md content (second sample post).
String blogGettingStartedPostTemplate() => '''
---
title: Getting Started with Trellis
date: 2026-03-14
tags:
  - tutorial
  - dart
summary: Learn how to create content and customize your Trellis blog.
---

This post covers the basics of working with your Trellis blog.

## Content Structure

Pages live in the `content/` directory. Each `.md` file becomes
a page on your site, with a URL derived from its path:

- `content/posts/my-post.md` → `/posts/my-post/`
- `content/about.md` → `/about/`

## Front Matter

Each Markdown file starts with YAML front matter between `---` delimiters:

```yaml
---
title: My Post
date: 2026-01-01
tags:
  - dart
---
```

## Templates

HTML layouts live in the `layouts/` directory. They use Trellis `tl:*`
attributes to render dynamic content — while remaining valid HTML
that browsers can display as prototypes without a server.
''';

/// Generates the blog-specific .gitignore content.
String blogGitignoreTemplate() => '''
# Trellis
output/

# Dart
.dart_tool/
.packages
pubspec.lock
''';
