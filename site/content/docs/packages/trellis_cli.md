---
title: trellis_cli
description: The trellis command-line tool – project scaffolding, static-site building, local preview, and theme management.
weight: 80
---

`trellis_cli` provides the `trellis` command: project scaffolding, static-site
building, local preview, and theme management. It ties the SDK together – the
[engine](/docs/packages/trellis/), the
[static site generator](/docs/packages/trellis_site/), and the theme system.

## Installation

```bash
dart pub global activate trellis_cli
```

Or run it directly without installing:

```bash
dart pub global run trellis_cli:trellis create my_app
```

## Quick start

### Dynamic server app (Shelf + HTMX)

```bash
trellis create my_app
cd my_app
dart pub get
dart run bin/server.dart
```

Then open `http://localhost:8080`.

### Static blog site

```bash
trellis create my_blog --template blog
cd my_blog
dart pub get
trellis build
trellis serve
```

### Dart Frog app

```bash
trellis create my_frog_app --template dart_frog
cd my_frog_app
dart pub get
dart_frog dev
```

### Relic app

```bash
trellis create my_relic_app --template relic
cd my_relic_app
dart pub get
dart run bin/server.dart
```

### Theme scaffold

```bash
trellis create my-theme --template theme
cd my-theme
# Edit theme.yaml, layouts/, and sass/
cd example && trellis build && trellis serve
```

See the [Theme Authoring](/docs/themes/authoring/) guide for a complete
walkthrough.

## Commands

### `trellis create <project-name>`

Generates a new Trellis project from a starter template.

Options:

- `--template` (`-t`): the project template to use.

Available templates:

| Template | Description |
|---|---|
| `htmx` (default) | Shelf + HTMX counter app with Home/About pages, CSRF, security headers, and hot reload |
| `blog` | Static blog site built with trellis_site (Markdown content, layouts, taxonomies) |
| `dart_frog` | Dart Frog + HTMX counter app with file-based routing, CSRF, security headers, and hot reload |
| `relic` | Relic + HTMX counter app with explicit-engine wiring and security headers |
| `theme` | Trellis theme scaffold with `theme.yaml`, layouts, SASS architecture, and example preview site |

Each template generates a ready-to-run project: server or route wiring, base and
page layouts, an HTMX navigation partial, a starter stylesheet, and the standard
Dart project files (`pubspec.yaml`, `analysis_options.yaml`, `.gitignore`). The
`blog` and `theme` templates instead scaffold a static site and a theme
skeleton, respectively.

### `trellis build`

Builds a static site from the current directory. Reads `trellis_site.yaml` for
configuration, runs the full [trellis_site](/docs/packages/trellis_site/)
pipeline, and compiles any SASS/SCSS files in the static directory.

Options:

- `--output` (`-o`): output directory (default: from config, or `output`).
- `--drafts`: include draft content (default: `false`).
- `--verbose` (`-v`): show a detailed build log.

```bash
trellis build
trellis build --output dist --drafts --verbose
```

### `trellis serve`

Starts a local static file server to preview a built site. Serves from the
output directory with clean-URL support (`/about/` resolves to
`/about/index.html`).

Options:

- `--port` (`-p`): port to listen on (default: `8080`).
- `--output` (`-o`): output directory to serve (default: from config, or
  `output`).

```bash
trellis serve
trellis serve --port 3000
```

### `trellis --version` / `trellis --help`

Print the CLI version and usage information, respectively.

## Theme management

The `trellis theme` subcommands manage themes for static sites built with
[trellis_site](/docs/packages/trellis_site/). To create your own theme, see
[Theme Authoring](/docs/themes/authoring/).

### `trellis theme add <url>`

Installs a theme from a git URL or local path.

Options:

- `--ref`: pin to a git tag, branch, or commit SHA (recommended for production).

```bash
# Install from git
trellis theme add https://github.com/tolo/trellis-theme-verdant

# Pin to a specific release
trellis theme add https://github.com/tolo/trellis-theme-verdant --ref v1.0.0

# Install from a local path (theme development)
trellis theme add ./path/to/my-theme
```

After installing, set `theme: <name>` in `trellis_site.yaml`.

### `trellis theme update [<name>]`

Pulls the latest version of an installed theme (or all themes if no name is
given).

```bash
trellis theme update
trellis theme update verdant
```

### `trellis theme list`

Lists all installed themes with their names, versions, and source URLs.

### `trellis theme info <name>`

Displays the full manifest for an installed theme: name, version, author,
description, features, and all params with their defaults.

### `trellis theme remove <name>`

Removes an installed theme from `themes/` and clears `theme:` from
`trellis_site.yaml`.

## Project name rules

Project names must follow Dart package naming conventions:

- Lowercase letters, digits, and underscores only.
- Must start with a letter.
- Cannot be a Dart reserved word.
