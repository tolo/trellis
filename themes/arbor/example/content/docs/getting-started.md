---
title: Getting Started
description: Install Arbor and build your first documentation page.
---

Arbor renders natural HTML templates with `tl:*` attributes. This page walks
through the essentials and exercises the in-page table of contents.

## Installation

Add the theme to your site configuration:

```yaml
theme: arbor
theme_params:
  skin: auto
```

## Building the site

Run the Trellis CLI from your site directory:

```bash
trellis build
```

The build compiles the theme SASS and highlights fenced code (build-time
`.hljs-*` spans, ADR-010), then writes the output tree.

### Output layout

The build writes HTML pages plus a `css/` directory. Code is colored server-side,
so no highlighter scripts are shipped.

## Next steps

Continue to the guides for templates and deployment.
