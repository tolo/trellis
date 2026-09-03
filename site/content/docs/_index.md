---
title: Documentation
description: Build server-rendered web applications and static sites with Trellis.
weight: 10
---

Welcome to the Trellis documentation. Trellis is a pure-Dart SDK with two
paths: render natural HTML in a server application, or turn Markdown and HTML
layouts into a static site. Both use the same template engine and need no
Node.js build step.

## Build a web app

Start with the template engine when a Dart server renders requests and HTMX
fragments:

- [**Getting Started**](/docs/getting-started/) – install the engine, render a
  natural HTML template, and learn the core model.
- [**Syntax Reference**](/docs/syntax/) – every `tl:*` attribute and expression
  form with worked examples.
- [**Server packages**](/docs/packages/) – connect Trellis to Shelf, Dart Frog,
  or Relic, then add hot reload and CSS tooling as needed.

## Build a site

Start with the static-site track when Markdown content should become a themed,
deployable output directory:

- [**Sites Getting Started**](/docs/sites/getting-started/) – create a site,
  add content, build, preview, and deploy it.
- [**Sites guide**](/docs/sites/) – content conventions, layouts, navigation,
  themes, search, feeds, and deployment.
- [**Themes**](/docs/sites/themes/) – install, configure, and customize a
  reusable design without forking it.

## Packages

The [package guides](/docs/packages/) cover the API surface behind both tracks:
the core engine, server adapters, the static site generator, CSS processing,
development tooling, and the CLI. Add only the packages your application or
site needs.

This documentation site is itself generated from Markdown, Trellis layouts,
and the Lattice theme. Its
[source lives in the repository](https://github.com/tolo/trellis/tree/main/site).
