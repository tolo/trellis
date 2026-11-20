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

`trellis` ships as a self-contained binary (no Dart SDK required) and as a
pub.dev package.

Homebrew (macOS and Linux):

```bash
brew install tolo/trellis/trellis
```

Scoop (Windows):

```powershell
scoop bucket add trellis https://github.com/tolo/scoop-trellis
scoop install trellis
```

Manual download: each
[release](https://github.com/tolo/trellis/releases/latest) carries
`trellis-v<version>-<platform>` archives for macOS (arm64), Linux (x64,
arm64), and Windows (x64), plus `SHA256SUMS.txt`. Verify the checksum, extract
the `trellis` binary, and put it on your `PATH`. The
[package README](https://github.com/tolo/trellis/blob/main/packages/trellis_cli/README.md)
has the full download and verify commands.

From pub.dev (requires the Dart SDK):

```bash
dart pub global activate trellis_cli
```

Or run it directly without installing:

```bash
dart pub global run trellis_cli:trellis create my_app
```

From source:

```bash
git clone https://github.com/tolo/trellis
cd trellis
dart pub get
dart compile exe packages/trellis_cli/bin/trellis.dart -o trellis
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
trellis dev
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
trellis create my_theme --template theme
cd my_theme
# Edit theme.yaml, layouts/, and sass/
cd example && trellis dev
```

See the [Theme Authoring](/docs/themes/authoring/) guide for a complete
walkthrough.

## Commands

### `trellis create <project-name>`

Generates a new Trellis project from a starter template.

Options:

- `--template` (`-t`): the project template to use.
- `--ui`: add Trellis UI and a Components page to an app scaffold.

Available templates:

| Template | Description |
|---|---|
| `htmx` (default) | Shelf + HTMX counter app with Home/About pages, CSRF, security headers, and hot reload |
| `blog` | Static blog site built with trellis_site (Markdown content, layouts, taxonomies) |
| `dart_frog` | Dart Frog + HTMX counter app with file-based routing, CSRF, security headers, and hot reload |
| `relic` | Relic + HTMX counter app with explicit-engine wiring, CSRF, and security headers |
| `theme` | Trellis theme scaffold with `theme.yaml`, layouts, SASS architecture, and example preview site |

App templates (`htmx`, `relic`, `dart_frog`) self-host the pinned HTMX build under `/js/htmx.min.js`
and use `CspBuilder.strict()`. All three also write `/js/csrf.js`. The layout disables
HTMX's injected indicator styles; the rules ship in `styles.css`. Generated markup has no inline
scripts or styles. Shelf and Dart Frog dev mode also reloads on CSS/JS edits in `static/` or `public/`.

Use `trellis create my_app --template htmx --htmx-cdn` to opt into the SRI-pinned CDN build.
The generated `script-src` allows only `'self'` plus the pinned CDN origin; no local htmx file is
written. `--htmx-cdn` is also accepted by `relic` and `dart_frog`, and rejected by `blog` and `theme`.

Run `trellis create my_app --ui` to generate a Components page at `/ui`. The
option works with the `htmx`, `relic`, and `dart_frog` templates and combines
with `--htmx-cdn`. Follow the printed `dart pub get` and run commands, then open
Components in the app's navigation.

For previews from disk, run `dart run trellis_ui:materialize` from the project
root. Shelf and Relic use `static/trellis-ui`. In a Dart Frog project, run
`dart run trellis_ui:materialize public/trellis-ui`. Shelf started with `--dev` and
Dart Frog started with `DEV=true` refresh these gitignored files at startup.
Relic writes previews on demand.

**`htmx` template** generates:

- `bin/server.dart` – Shelf server with logging, security headers, Trellis
  engine injection, CSRF, and optional live reload.
- `lib/handlers.dart` – Home/about handlers plus counter mutation endpoints
  using `renderPage()` and `renderFragment()`.
- `templates/layouts/base.html` – base layout with HTMX, CSRF meta tag, and
  shared page shell.
- `templates/pages/index.html` – home page with counter fragment and feature
  list.
- `templates/pages/about.html` – About page covering Shelf middleware ordering,
  request context, CSRF, and hot reload.
- `templates/partials/nav.html` – HTMX SPA navigation partial (`hx-get` +
  `hx-target="#content"` + `hx-push-url="true"`).
- `static/styles.css` – starter stylesheet.
- `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`.

**`blog` template** generates:

- `trellis_site.yaml` – site configuration (title, baseUrl, taxonomies).
- `content/` – Markdown content with front matter (`_index.md`, posts, about
  page).
- `layouts/` – Trellis HTML layouts (base, home, single, list, post).
- `static/styles.css` – starter stylesheet.
- `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`.

**`dart_frog` template** generates:

- `routes/_middleware.dart` – Trellis provider, security headers, CSRF
  middleware, and optional hot reload bridge.
- `routes/index.dart` and `routes/about.dart` – file-based routes for Home/About
  page rendering.
- `lib/counter_state.dart` – shared in-memory counter state and page context.
- `routes/counter/increment.dart`, `decrement.dart`, `reset.dart` – HTMX
  mutation endpoints returning the counter fragment.
- `templates/layouts/base.html` – base layout with HTMX, CSRF meta tag, and
  shared shell.
- `templates/pages/index.html` – home page using template inheritance with a
  counter fragment.
- `templates/pages/about.html` – About page covering providers, routing,
  middleware, CSRF, and hot reload.
- `templates/partials/nav.html` – HTMX SPA navigation partial.
- `public/styles.css` – starter stylesheet served by Dart Frog.
- `dart_frog.yaml`, `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`.

**`relic` template** generates:

- `bin/server.dart` – Relic server setup with security headers, explicit Trellis
  engine wiring, routes, and static CSS serving.
- `lib/handlers.dart` – Home/about handlers plus counter mutation endpoints
  using `trellis_relic` response helpers.
- `templates/base.html` – base layout with HTMX-powered Home/About navigation.
- `templates/index.html` – home page with the counter fragment and shared
  feature list.
- `templates/about.html` – About page covering Relic's no-DI pattern, middleware
  scoping, and fragment rendering.
- `static/styles.css` – starter stylesheet.
- `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`.

**`theme` template** generates `theme.yaml`, `layouts/`, `sass/`, and an `example/` preview site, with no
`pubspec.yaml`.

### `trellis build`

Builds a static site from the current directory. Reads `trellis_site.yaml` for
configuration, runs the full [trellis_site](/docs/packages/trellis_site/)
pipeline, and compiles any SASS/SCSS files in the static directory.

The CLI embeds the [Trellis UI suite](/docs/ui/) for builds that specify
`uses: [trellis_ui]` in the site config or theme manifest. Those builds can
render the embedded fragments and publish their same-origin assets under
`trellis-ui/`. Layouts link the assets wherever they use the components.

Options:

- `--output` (`-o`): output directory (default: from config, or `output`).
- `--base-url`: override `baseUrl` from `trellis_site.yaml`.
- `--path-prefix`: override `pathPrefix` from `trellis_site.yaml`; `''` builds
  a root-served variant.
- `--drafts`: include draft content (default: `false`).
- `--verbose` (`-v`): show a detailed build log.

```bash
trellis build
trellis build --output dist --drafts --verbose
trellis build --path-prefix '' --output output-root
```

### `trellis dev`

Previews a site while you edit it. Builds the site, serves it with clean URLs,
rebuilds when a file under the site directory or its theme changes, and reloads
open browser tabs after each successful rebuild.

The preview build differs from `trellis build` so it works locally and cannot
be deployed by mistake:

- It is served from `/`: `pathPrefix` is cleared, and `baseUrl` becomes
  `http://localhost:<port>`.
- It goes to a temporary directory, removed when the server stops (Ctrl-C or SIGTERM), never to `output/`.
- A failed rebuild prints the error and keeps the last good build on screen;
  the next save tries again.

Edits to `.`-prefixed directories (`.git`, `.dart_tool`) and to the output
directory do not trigger a rebuild. The reload script is served same-origin at
`/_dev/reload.js`, so it works under `script-src 'self'`.

Options:

- `--port` (`-p`): port to listen on (default: `8080`).
- `--drafts`: include draft content (default: `false`).
- `--verbose` (`-v`): show a detailed build log.

```bash
trellis dev
trellis dev --port 3000 --drafts
```

### `trellis serve`

Serves an already-built output directory with clean-URL support (`/about/`
resolves to `/about/index.html`). It does not build or watch; use `trellis dev`
while editing, and `serve` to look at the exact output of `trellis build`.

Options:

- `--port` (`-p`): port to listen on (default: `8080`).
- `--output` (`-o`): output directory to serve (default: from config, or
  `output`).

```bash
trellis serve
trellis serve --port 3000
```

`serve` serves the output directory at `/` and ignores `pathPrefix`, so a
prefixed build's links return 404 locally. Use `trellis dev`, or serve a
root-served build; see [Sites: Deploy](/docs/sites/deploy/#preview-a-sub-path-site).

### `trellis --version` / `trellis --help`

Print the CLI version and usage information, respectively.

## Theme management

The `trellis theme` subcommands manage themes for static sites built with
[trellis_site](/docs/packages/trellis_site/). To create your own theme, see
[Theme Authoring](/docs/themes/authoring/).

### `trellis theme add <url>`

Installs a theme from a git URL or local path.

Options:

- `--theme`: install one theme out of a multi-theme source, from its
  `themes/<name>/` directory.
- `--ref`: pin to a git tag or branch (recommended for production). Becomes
  `git clone --branch`, so the ref must already exist on the remote — pick a
  published tag from [releases](https://github.com/tolo/trellis/releases). An
  unpushed tag fails with `Remote branch <tag> not found`.

```bash
# Install a built-in theme out of the Trellis repository
trellis theme add https://github.com/tolo/trellis --theme lattice --ref v0.13.0

# Install a single-theme repository (name derived from the repository)
trellis theme add https://github.com/yourname/trellis-theme-orchard

# Pin to a published release tag
trellis theme add https://github.com/tolo/trellis --theme lattice --ref v0.13.0

# Install from a local path (theme development)
trellis theme add ./path/to/my-theme
```

Run it from the site directory (it needs `trellis_site.yaml`). It sets
`theme: <name>` in `trellis_site.yaml`, plus `theme_ref: <ref>` when `--ref` is
given.

### `trellis theme update [<name>]`

Updates an installed theme, or the active `theme:` from `trellis_site.yaml` if
no name is given.

```bash
trellis theme update
trellis theme update orchard
```

`theme update` runs `git pull` in the installed theme, or `git fetch` and
`git checkout <ref>` when `theme_ref` is set, so it applies to themes installed
from a single-theme repository. A theme installed with `--theme` carries no git
metadata – remove and re-add it instead.

### `trellis theme list`

Lists all installed themes with their names and versions, marking the active
theme with `*`.

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
