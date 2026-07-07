---
title: Packages
description: A guide to every package in the Trellis SDK – the core engine, server integrations, static site generator, CSS tooling, hot reload, and the CLI.
weight: 30
---

Trellis ships as a multi-package SDK. The [core engine](/docs/packages/trellis/)
renders templates; the rest of the packages add server integrations, static
site generation, CSS tooling, hot reload, and a scaffolding CLI. Each package is
published independently on pub.dev and you add only the ones you need.

If you have not rendered a template yet, start with
[Getting Started](/docs/getting-started/) and the
[Syntax Reference](/docs/syntax/) – these package guides assume you know the
`tl:*` basics and focus on what each package adds.

## The core

- [**trellis**](/docs/packages/trellis/) – the template engine. Configuration,
  loaders, fragments, validation, custom processors, and the public API.

## Server integrations

Pick the one that matches your HTTP framework. All three expose the same shape:
a way to reach the engine, response helpers, HTMX detection, and security
headers.

- [**trellis_shelf**](/docs/packages/trellis_shelf/) – Shelf middleware, HTMX
  helpers, CSRF, and security defaults.
- [**trellis_dart_frog**](/docs/packages/trellis_dart_frog/) – Dart Frog
  provider middleware, response helpers, and security middleware.
- [**trellis_relic**](/docs/packages/trellis_relic/) – Serverpod Relic response
  helpers, HTMX detection, and security headers.

## Sites, CSS, and tooling

- [**trellis_site**](/docs/packages/trellis_site/) – static site generator:
  Markdown content, layouts, taxonomies, feeds, and navigation.
- [**trellis_css**](/docs/packages/trellis_css/) – Dart-native SASS compilation
  and fragment-scoped CSS via `tl:scope`.
- [**trellis_dev**](/docs/packages/trellis_dev/) – SSE-based browser hot reload
  for template development.
- [**trellis_cli**](/docs/packages/trellis_cli/) – the `trellis` command:
  project scaffolding, static-site builds, local preview, and theme management.

Authoring a theme for `trellis_site`? See the
[Theme Authoring](/docs/themes/authoring/) guide.
