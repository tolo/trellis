# trellis_cli

CLI tool for the [Trellis](https://pub.dev/packages/trellis) template engine — project scaffolding, static site building, and local preview.

Part of the [Trellis SDK](https://github.com/tolo/trellis).

## Installation

`trellis` ships as a self-contained binary (no Dart SDK required) and as a pub.dev
package. Pick whichever fits your workflow.

### Homebrew (macOS / Linux)

```bash
brew install tolo/trellis/trellis
```

### Scoop (Windows)

```powershell
scoop bucket add trellis https://github.com/tolo/scoop-trellis
scoop install trellis
```

### Manual download

Set `VERSION` to the current release number from the
[latest release](https://github.com/tolo/trellis/releases/latest), then grab the
archive for your platform. Do not include the leading `v` in `VERSION`.

| Platform | Asset |
|---|---|
| macOS (Apple Silicon) | `trellis-v<version>-macos-arm64.tar.gz` |
| macOS (Intel) | `trellis-v<version>-macos-x64.tar.gz` |
| Linux (x64) | `trellis-v<version>-linux-x64.tar.gz` |
| Linux (arm64) | `trellis-v<version>-linux-arm64.tar.gz` |
| Windows (x64) | `trellis-v<version>-windows-x64.zip` |

Each archive contains the `trellis` binary plus `README` and `LICENSE`. Download
the archive and `SHA256SUMS.txt`, verify the checksum, then extract the binary
and put it on your `PATH`.

macOS / Linux:

```bash
VERSION=0.10.2
BASE=https://github.com/tolo/trellis/releases/download/v$VERSION
ASSET=trellis-v$VERSION-macos-arm64.tar.gz
curl -LO $BASE/$ASSET
curl -LO $BASE/SHA256SUMS.txt
shasum -a 256 -c SHA256SUMS.txt --ignore-missing
tar -xzf $ASSET trellis
sudo mv trellis /usr/local/bin/
```

Windows (PowerShell):

```powershell
$Version = "0.10.2" # no leading "v"
$Base = "https://github.com/tolo/trellis/releases/download/v$Version"
$Asset = "trellis-v$Version-windows-x64.zip"
Invoke-WebRequest "$Base/$Asset" -OutFile $Asset
Invoke-WebRequest "$Base/SHA256SUMS.txt" -OutFile SHA256SUMS.txt
$Match = Select-String -Path SHA256SUMS.txt -Pattern ([regex]::Escape($Asset) + '$')
if (-not $Match) { throw "No checksum line for $Asset" }
$Expected = ($Match.Line -split '\s+')[0]
$Actual = (Get-FileHash $Asset -Algorithm SHA256).Hash.ToLowerInvariant()
if ($Actual -ne $Expected) { throw "Checksum mismatch for $Asset" }
Expand-Archive $Asset -DestinationPath trellis-bin
# Then move trellis-bin\trellis.exe onto your PATH.
```

### From pub.dev (requires the Dart SDK)

```bash
dart pub global activate trellis_cli
```

Or run directly without installing:

```bash
dart pub global run trellis_cli:trellis create my_app
```

### From source

```bash
git clone https://github.com/tolo/trellis
cd trellis
dart pub get
dart compile exe packages/trellis_cli/bin/trellis.dart -o trellis
```

## Quick Start

### Dynamic server app (Shelf + HTMX)

```bash
trellis create my_app
cd my_app
dart pub get
dart run bin/server.dart
```

Then open http://localhost:8080 in your browser.

### Static blog site

```bash
trellis create my_blog --template blog
cd my_blog
trellis build
trellis serve
```

Then open http://localhost:8080 in your browser.

### Dart Frog app

```bash
trellis create my_frog_app --template dart_frog
cd my_frog_app
dart pub get
dart_frog dev
```

Then open http://localhost:8080 in your browser.

### Relic app

```bash
trellis create my_relic_app --template relic
cd my_relic_app
dart pub get
dart run bin/server.dart
```

Then open http://localhost:8080 in your browser.

### Theme scaffold

```bash
trellis create my-theme --template theme
cd my-theme
# Edit theme.yaml, layouts/, and sass/
cd example && trellis build && trellis serve
```

See the [Theme Authoring Guide](../../docs/guides/theme-authoring.md) for a complete walkthrough.

## Commands

### `trellis create <project-name>`

Generates a new Trellis project from a starter template.

Options:
- `--template` (`-t`): Project template to use

Available templates:

| Template | Description |
|---|---|
| `htmx` (default) | Shelf + HTMX counter app with Home/About pages, CSRF, security headers, and hot reload |
| `blog` | Static blog site built with trellis_site (Markdown content, layouts, taxonomies) |
| `dart_frog` | Dart Frog + HTMX counter app with file-based routing, CSRF, security headers, and hot reload |
| `relic` | Relic + HTMX counter app with explicit-engine wiring and security headers |
| `theme` | Trellis theme scaffold with `theme.yaml`, layouts, SASS architecture, and example preview site |

**`htmx` template** generates:
- `bin/server.dart` — Shelf server with logging, security headers, Trellis engine injection, CSRF, and optional live reload
- `lib/handlers.dart` — Home/about handlers plus counter mutation endpoints using `renderPage()` and `renderFragment()`
- `templates/layouts/base.html` — Base layout with HTMX, CSRF meta tag, and shared page shell
- `templates/pages/index.html` — Home page with counter fragment and feature list
- `templates/pages/about.html` — About page covering Shelf middleware ordering, request context, CSRF, and hot reload
- `templates/partials/nav.html` — HTMX SPA navigation partial (`hx-get` + `hx-target="#content"` + `hx-push-url="true"`)
- `static/styles.css` — Starter stylesheet
- `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`

**`blog` template** generates:
- `trellis_site.yaml` — Site configuration (title, baseUrl, taxonomies)
- `content/` — Markdown content with front matter (`_index.md`, posts, about page)
- `layouts/` — Trellis HTML layouts (base, home, single, list, post)
- `static/styles.css` — Starter stylesheet
- `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`

**`dart_frog` template** generates:
- `routes/_middleware.dart` — Trellis provider, security headers, CSRF middleware, and optional hot reload bridge
- `routes/index.dart` and `routes/about.dart` — file-based routes for Home/About page rendering
- `lib/counter_state.dart` — shared in-memory counter state and page context
- `routes/counter/increment.dart`, `decrement.dart`, `reset.dart` — HTMX mutation endpoints returning the counter fragment
- `templates/layouts/base.html` — base layout with HTMX, CSRF meta tag, and shared shell
- `templates/pages/index.html` — home page using template inheritance with a counter fragment
- `templates/pages/about.html` — About page covering providers, routing, middleware, CSRF, and hot reload
- `templates/partials/nav.html` — HTMX SPA navigation partial
- `public/styles.css` — starter stylesheet served by Dart Frog
- `dart_frog.yaml`, `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`

**`relic` template** generates:
- `bin/server.dart` — Relic server setup with security headers, explicit Trellis engine wiring, routes, and static CSS serving
- `lib/handlers.dart` — Home/about handlers plus counter mutation endpoints using `trellis_relic` response helpers
- `templates/base.html` — Base layout with HTMX-powered Home/About navigation
- `templates/index.html` — Home page with the counter fragment and shared feature list
- `templates/about.html` — About page covering Relic's no-DI pattern, middleware scoping, and fragment rendering
- `static/styles.css` — starter stylesheet
- `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`

### `trellis build`

Builds a static site from the current directory. Reads `trellis_site.yaml` for configuration, runs the full trellis_site pipeline, and compiles any SASS/SCSS files in the static directory.

Options:
- `--output` (`-o`): Output directory (default: from config, or `output`)
- `--drafts`: Include draft content (default: `false`)
- `--verbose` (`-v`): Show detailed build log

```bash
trellis build
trellis build --output dist --drafts --verbose
```

### `trellis serve`

Starts a local static file server to preview a built site. Serves from the output directory with clean URL support (`/about/` resolves to `/about/index.html`).

Options:
- `--port` (`-p`): Port to listen on (default: `8080`)
- `--output` (`-o`): Output directory to serve (default: from config, or `output`)

```bash
trellis serve
trellis serve --port 3000
```

### `trellis --version`

Prints the CLI version.

### `trellis --help`

Prints usage information.

## Theme Management

The `trellis theme` subcommands manage themes for static sites built with `trellis_site`.

See the [Theme Usage Guide](../../docs/guides/theme-usage.md) for full documentation, and the [Theme Authoring Guide](../../docs/guides/theme-authoring.md) for creating themes.

### `trellis theme add <url>`

Installs a theme from a git URL or local path.

Options:
- `--theme`: Install one theme out of a multi-theme source, from its `themes/<name>/` directory
- `--ref`: Pin to a git tag or branch (recommended for production). Becomes
  `git clone --branch`, so the ref must already exist on the remote — pick a
  published tag from [releases](https://github.com/tolo/trellis/releases). An
  unpushed tag fails with `Remote branch <tag> not found`

```bash
# Install a built-in theme out of the Trellis repository
trellis theme add https://github.com/tolo/trellis --theme lattice

# Install a single-theme repository (name derived from the repository)
trellis theme add https://github.com/yourname/trellis-theme-orchard

# Pin to a published release tag
trellis theme add https://github.com/tolo/trellis --theme lattice --ref <tag>

# Install from a local path (theme development)
trellis theme add ./path/to/my-theme
```

After installing, set `theme: <name>` in `trellis_site.yaml`.

### `trellis theme update [<name>]`

Pulls the latest version of an installed theme (or all themes if no name given).

```bash
trellis theme update
trellis theme update orchard
```

`theme update` runs `git pull` in the installed theme, so it applies to themes
installed from a single-theme repository. A theme installed with `--theme`
carries no git metadata — remove and re-add it instead.

### `trellis theme list`

Lists all installed themes with their names, versions, and source URLs.

```bash
trellis theme list
```

### `trellis theme info <name>`

Displays the full manifest for an installed theme: name, version, author, description, features, and all params with their defaults.

```bash
trellis theme info verdant
```

### `trellis theme remove <name>`

Removes an installed theme from `themes/` and clears `theme:` from `trellis_site.yaml`.

```bash
trellis theme remove verdant
```

## Maintainer Validation

Before publishing CLI or starter changes from the monorepo, run the E2E suite:

```bash
cd packages/trellis_cli
dart test -t e2e \
  test/generated_app_e2e_test.dart \
  test/dart_frog_e2e_test.dart \
  test/relic_e2e_test.dart \
  test/examples_smoke_test.dart
```

That verifies generated Shelf, Dart Frog, and Relic starters plus the checked-in
example apps under `examples/`.

## Project Name Rules

Project names must follow Dart package naming conventions:
- Lowercase letters, digits, and underscores only
- Must start with a letter
- Cannot be a Dart reserved word

## API Documentation

- https://pub.dev/documentation/trellis_cli/latest/
