---
title: Deploy
description: Deploy a Trellis site at a domain root or sub-path and validate its built links.
weight: 60
---

A Trellis build is a static output directory that can be published by any static host.

## Domain root or sub-path

`baseUrl` is the canonical origin used by the sitemap and feeds. `pathPrefix`
is the mount point for a project site or another sub-path:

```yaml
baseUrl: https://user.github.io
pathPrefix: /my-site/
```

The prefix appears in emitted URLs, but not in the output tree's disk paths.
Publish the whole `output/` directory as the host's artifact root. For a custom
domain served at `/`, omit `pathPrefix` or set it to an empty string.

Hand-written root-absolute Markdown links such as `/docs/` are rewritten during
the build. Relative links and anchors are left alone. Do not author the deploy
prefix into content; the same source should build for either target.

## Check every link

A successful build cannot detect a valid HTML link that points at the wrong
mount point. From the repository containing `tool/link_check.dart`, verify both
variants:

```bash
trellis build
dart run tool/link_check.dart output --base-path /my-site/

trellis build --path-prefix '' --output output-root
dart run tool/link_check.dart output-root
```

The checker resolves internal `href`, `src`, `srcset`, and theme image-switch
attributes against the built filesystem. It ignores external URLs and pure
in-page anchors.

## GitHub Pages

The Trellis documentation site's
[`deploy-docs-site.yml`](https://github.com/tolo/trellis/blob/main/.github/workflows/deploy-docs-site.yml)
is a complete worked example. Its build job:

1. checks out the repository and installs Dart dependencies;
2. activates the checkout's `trellis_cli`;
3. builds the configured sub-path site;
4. runs `tool/link_check.dart` with the matching base path;
5. builds and checks a root-served variant; and
6. uploads the production output as the Pages artifact.

The deploy job depends on that entire gate, so GitHub Pages never receives a
partially built or internally broken tree. Adapt the paths and `pathPrefix` to
your repository while keeping the build and link check together.
