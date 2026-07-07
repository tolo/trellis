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
  syntax_highlighting: true
```

## Building the site

Run the Trellis CLI from your site directory:

```bash
trellis build
```

The build compiles the theme SASS, copies the vendored highlighter assets, and
writes the output tree.

### Output layout

The build writes HTML pages plus a `css/` directory and the vendored `prism/`
scripts served from the output root.

## Next steps

Continue to the guides for templates and deployment.
