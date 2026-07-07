---
title: Themes
description: Author and publish themes for the Trellis static site generator – the theme.yaml manifest, layouts, the SASS bridge, and the standard-params contract.
weight: 40
---

A Trellis theme is a self-contained directory of HTML layouts, SASS stylesheets,
and a YAML manifest. Themes are distributed via git and installed with the
[trellis CLI](/docs/packages/trellis_cli/), and site builders configure them
entirely through YAML – no forking required.

- [**Theme Authoring**](/docs/themes/authoring/) – create, test, and publish a
  theme: the `theme.yaml` manifest, layouts with `tl:extends`/`tl:define`, the
  SASS bridge, and the standard-params contract.

Applying an existing theme to your own site is covered in the
[trellis_site](/docs/packages/trellis_site/) guide.
