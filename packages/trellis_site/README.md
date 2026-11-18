# trellis_site

Static site generator for [Trellis](https://pub.dev/packages/trellis): Markdown content, Trellis templates,
Hugo-inspired conventions. `trellis build` (from [trellis_cli](https://pub.dev/packages/trellis_cli)) runs it and
compiles SASS; `TrellisSite.build()` runs the content pipeline from Dart.

Part of the [Trellis SDK](https://github.com/tolo/trellis).

## Installation

```yaml
dependencies:
  trellis_site: ^0.13.0
```

## Quick start

Create a `trellis_site.yaml` in your project root:

```yaml
title: My Site
baseUrl: https://example.com
taxonomies:
  - tags
paginate: 10
```

Build the site programmatically:

```dart
import 'package:trellis_site/trellis_site.dart';

final config = SiteConfig.load('trellis_site.yaml');
final site = TrellisSite(config);
final result = await site.build();
print('Built ${result.pageCount} pages in ${result.elapsed.inMilliseconds}ms');
```

Or use the CLI:

```bash
trellis build
trellis serve
```

## Features

- Content discovery: recursive `.md` scanning, Hugo-style URLs, page bundles with co-located assets.
- YAML front matter and GitHub-flavored Markdown via `package:markdown` (tables, task lists, footnotes, alerts, emoji).
- Priority-ordered layout lookup: front matter `layout`, type, section, `_default`.
- Data cascade: site params, `data/*.yaml`, section front matter, page front matter.
- Taxonomies with generated listing and term pages, and pagination of section, home, and term lists.
- Navigation data: `${site.menu}` tree, `${page.breadcrumbs}`, `${page.prev}` and `${page.next}`.
- Shortcodes, both `{{% name %}}` (pre-Markdown) and `<!-- tl:name -->` (post-Markdown).
- `sitemap.xml`, Atom and RSS feeds (site-wide and per section), and a JSON search index.
- Build-time syntax highlighting with no client-side JavaScript.
- `pathPrefix` for sites served below a domain root, with automatic rewriting of root-absolute links.
- Installable themes configured through `theme_params`, with no fork needed.
- Configurable content, layouts, static, data, and output directories; `draft: true` pages excluded by default.

## Documentation

**[Full guide: tolo.github.io/trellis/docs/packages/trellis_site/](https://tolo.github.io/trellis/docs/packages/trellis_site/)**
covers configuration, the project layout, path prefixes, front matter, the template context, navigation data, layout
resolution, and syntax highlighting. For the guided workflow, start with the
[Sites guide](https://tolo.github.io/trellis/docs/sites/).

API reference: <https://pub.dev/documentation/trellis_site/latest/>

## License

See the [Trellis repository](https://github.com/tolo/trellis) for license information.
