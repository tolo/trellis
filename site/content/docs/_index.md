---
title: Documentation
description: Learn Trellis – install the engine, render your first template, and look up every tl:* attribute and expression form.
weight: 10
---

Welcome to the Trellis documentation. Trellis is a pure-Dart SDK for building
server-rendered web applications and static sites – its heart is a
[Thymeleaf](https://www.thymeleaf.org/)-inspired template engine whose templates
are *valid HTML*. You add behaviour with `tl:*` attributes, and browsers still
render the raw templates as prototypes without a server.

These docs cover the template engine: installing it, rendering your first
template, and the complete `tl:*` syntax reference.

## Start here

- [**Getting Started**](/docs/getting-started/) – install Trellis, render your
  first template, and learn the core principles behind natural templates.
- [**Syntax Reference**](/docs/syntax/) – every `tl:*` attribute and every
  expression form the engine supports, each with a worked example.
- [**Packages**](/docs/packages/) – a guide to every package in the SDK: the
  core engine, server integrations, the static site generator, CSS tooling, hot
  reload, and the CLI.
- [**Themes**](/docs/themes/) – author and publish a theme for the static site
  generator.

## What is Trellis

- **Natural HTML templates** – a template is valid HTML with `tl:*` attributes.
  Designers and browsers can open it directly, no server required.
- **Fragment-first / HTMX-native** – `tl:fragment` + `renderFragment()` map
  directly to HTMX partial responses and out-of-band swaps.
- **Pure Dart, no npm** – HTML, Markdown, and SASS are all Dart packages. No
  Node.js, no webpack, no external binaries.
- **Sync-first, AOT-safe** – `render()` is synchronous, the context is a plain
  `Map<String, dynamic>`, and there is no reflection.

Ready to build? Head to [Getting Started](/docs/getting-started/).
