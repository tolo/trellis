---
title: Welcome to Verdant
date: 2024-01-15
author: Your Name
tags:
  - trellis
  - dart
  - web
description: An introduction to the Verdant theme for Trellis SSG.
---

Welcome to Verdant — a minimal, accessible blog theme for [Trellis](https://pub.dev/packages/trellis).

## Getting Started

Verdant works with zero configuration. Add it to your `trellis_site.yaml`:

```yaml
theme: verdant
```

That's it. Your site renders with Verdant's clean design, responsive layout, and full keyboard
navigation out of the box.

## Customization

Override any param in `theme_params:`:

```yaml
theme_params:
  skin: dark
  primary_color: "#7c3aed"
  show_reading_time: false
```

## Features

- Three color skins: `light`, `dark`, and `auto` (follows OS preference)
- WCAG 2.1 AA accessible — 14.7:1 contrast on light, 15.4:1 on dark
- Responsive from 320px to 1920px
- Keyboard navigation with visible focus rings
- Skip-to-content link
- RSS/Atom feed link in `<head>`
- Reading time, date, author, and tag display — all toggleable

## Writing Posts

Posts are standard Markdown files with YAML front matter. Verdant uses:

- `title` — post title in `<h1>`
- `date` — formatted using your `date_format` param
- `author` — displayed in the metadata bar
- `tags` — rendered as linked pills
- `description` — used for SEO meta tags

Happy writing!
