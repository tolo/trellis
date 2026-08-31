---
title: Built-in Themes
description: Browse every theme installed with Trellis and choose a starting point for your site.
layout: gallery
weight: 20
---

Every theme here ships in the Trellis repository under `themes/<name>/` and is ready to configure without
changing its reusable source: Arbor, Folio and Lattice for documentation; Bloom and Meadow for product
landing pages; Verdant for blogs. Compare the designs below, then follow a theme's README for a complete
example.

Install one by naming it:

```bash
trellis theme add https://github.com/tolo/trellis --theme lattice --ref v0.11.0
```

The `--theme` selector requires Trellis CLI 0.11.0 or later.

That copies `themes/lattice/` into your site's `themes/` and sets `theme: lattice` in `trellis_site.yaml` –
the line each card shows below. See [`trellis theme add`](/docs/packages/trellis_cli/) for pinning with
`--ref` and for installing a theme from your own repository.
