---
title: Deployment
description: Ship the built output tree to any static host.
---

The build produces a self-contained static tree — HTML, compiled CSS, and the
highlighter scripts. Deploy it to any static host.

## Build for production

```bash
trellis build
```

## Serve the output

Any static file server works, because every asset is same-origin:

```bash
python3 -m http.server --directory output 8080
```

## Path prefix

When serving from a subpath, set the path prefix so hand-written asset links
resolve correctly.

```yaml
pathPrefix: /docs/
```
