<p align="center">
  <img src="https://raw.githubusercontent.com/tolo/trellis/main/assets/logo-with-text.png" alt="Trellis" width="400">
</p>

<p align="center">
  <a href="https://pub.dev/packages/trellis"><img src="https://img.shields.io/pub/v/trellis.svg" alt="pub package"></a>
  <a href="https://pub.dev/packages/trellis/publisher"><img src="https://img.shields.io/pub/publisher/trellis.svg" alt="package publisher"></a>
</p>

**Trellis is a pure-Dart SDK for building server-rendered web applications and static sites** — without Node.js, JavaScript frameworks, or a build toolchain.

> Modern web apps in pure Dart. Natural HTML templates + [HTMX](https://htmx.org/) for interactivity + static site generation + CSS processing — one language, one toolchain, one `dart compile exe` binary.

Trellis starts with a [Thymeleaf](https://www.thymeleaf.org/)-inspired template engine whose templates are *valid HTML* — browsers render them as prototypes without a server — and grows into a composable set of packages for server integration, static site generation, CSS, hot reload, and project scaffolding. Use just the engine, or the whole SDK. Each package is independently usable and published on pub.dev.

## Why Trellis

- **Natural HTML templates** — templates are valid HTML; designers and browsers can open them directly, no server required.
- **Fragment-first / HTMX-native** — `tl:fragment` + `renderFragment()` map directly to HTMX partial responses and out-of-band swaps.
- **Hybrid static + dynamic** — the *same* templates render SSG pages at build time and dynamic HTMX fragments at runtime. No duplication.
- **Pure Dart, no npm** — HTML (`package:html`), Markdown (`package:markdown`), and SASS (`package:sass`) are all Dart. No Node.js, no webpack, no external binaries.
- **Single-binary deployment** — `dart compile exe` produces one file with instant startup and tiny containers.
- **Type-safe & secure by default** — sound null safety, strict mode, expression validation, HTML escaping, path-traversal protection, and CSRF/CSP helpers for servers.

## Requirements

- Dart SDK `^3.10.0`

## Two ways to use Trellis

Trellis works equally well as a focused library *and* as a full project toolkit. Pick the entry point that fits.

### A. As a template engine (library)

Add the engine to an existing Dart project and render HTML:

```bash
dart pub add trellis
```

```dart
import 'package:trellis/trellis.dart';

final engine = Trellis();

final html = engine.render(
  '<h1 tl:text="${title}">Default Title</h1>',
  {'title': 'Hello, Trellis!'},
);
// <h1>Hello, Trellis!</h1>
```

Full template syntax, expression language, fragments, loaders, and API reference live on the engine's page: **[`packages/trellis`](packages/trellis/README.md)**.

### B. As a full SDK (CLI)

Install the `trellis` CLI, then scaffold a complete, runnable project. The CLI
ships as a self-contained binary (no Dart SDK required) and on pub.dev:

```bash
# Homebrew (macOS / Linux)
brew install tolo/trellis/trellis

# Scoop (Windows)
scoop bucket add trellis https://github.com/tolo/scoop-trellis
scoop install trellis

# Manual (macOS / Linux): set VERSION to the current release number from
# https://github.com/tolo/trellis/releases/latest, then download the archive +
# checksums, verify, and extract the binary onto your PATH.
# Do not include the leading "v" in VERSION.
#   Assets: trellis-v<version>-{macos-arm64,macos-x64,linux-x64,linux-arm64}.tar.gz
#           trellis-v<version>-windows-x64.zip  (+ aggregate SHA256SUMS.txt)
VERSION=0.10.2
BASE=https://github.com/tolo/trellis/releases/download/v$VERSION
ASSET=trellis-v$VERSION-macos-arm64.tar.gz
curl -LO $BASE/$ASSET
curl -LO $BASE/SHA256SUMS.txt
shasum -a 256 -c SHA256SUMS.txt --ignore-missing   # verify before extracting
tar -xzf $ASSET trellis && sudo mv trellis /usr/local/bin/
# Windows (PowerShell): Invoke-WebRequest the .zip + SHA256SUMS.txt, check with
# Get-FileHash -Algorithm SHA256, then Expand-Archive. See packages/trellis_cli.

# pub.dev (requires the Dart SDK)
dart pub global activate trellis_cli

# From source
dart compile exe packages/trellis_cli/bin/trellis.dart -o trellis
```

See [`packages/trellis_cli`](packages/trellis_cli) for the full install matrix.

```bash
# Dynamic server app (Shelf + HTMX) — the default template
trellis create my_app
cd my_app && dart pub get && dart run bin/server.dart   # http://localhost:8080

# Static site (Markdown + SSG)
trellis create my_blog --template blog
cd my_blog && trellis build && trellis serve
```

Available `trellis create` templates: `htmx` (default — Shelf + HTMX), `blog` (static site), `dart_frog`, `relic`, and `theme` (authoring an SSG theme).

Other CLI commands: `trellis build` (run the static-site pipeline), `trellis serve` (preview built output), and `trellis theme` (`add`/`update`/`list`/`info`/`remove`) for managing SSG themes.

## SDK packages

Every package is independently usable and publishable. Add only what you need.

| Package | Role | Description |
|---|---|---|
| [`trellis`](packages/trellis) | Engine | Natural HTML template engine — `tl:*` attributes, fragments, expression language, inheritance, validation. Single dependency (`package:html`). |
| [`trellis_shelf`](packages/trellis_shelf) | Server | Shelf middleware, response helpers, HTMX helpers, security headers, CSRF protection. |
| [`trellis_dart_frog`](packages/trellis_dart_frog) | Server | Dart Frog integration — `trellisProvider()` middleware, response/HTMX helpers, CSRF. |
| [`trellis_relic`](packages/trellis_relic) | Server | Serverpod Relic integration — response helpers, HTMX helpers, security headers. |
| [`trellis_site`](packages/trellis_site) | SSG | Static site generator — Markdown, front matter, taxonomies, pagination, RSS/Atom feeds, JSON search index, themes. |
| [`trellis_css`](packages/trellis_css) | CSS | SASS/SCSS compilation (Dart-native) and `tl:scope` fragment-scoped CSS via CSS `@scope`. |
| [`trellis_dev`](packages/trellis_dev) | DX | Browser hot reload via SSE — auto-refresh on template changes. |
| [`trellis_cli`](packages/trellis_cli) | DX | `trellis` command — project scaffolding (`create`), static-site `build`/`serve`, and theme management. |

## Examples & guides

- **Examples** — runnable apps in [`examples/`](examples): `shelf_app`, `dart_frog_app`, `relic_app`, `todo_app`.
- **Framework Integration Guide** — [`docs/guides/framework-integration.md`](docs/guides/framework-integration.md): Shelf, Dart Frog, and Relic; HTMX fragment and OOB patterns; security and testing.
- **Theme authoring & usage** — [`docs/guides/theme-authoring.md`](docs/guides/theme-authoring.md), [`docs/guides/theme-usage.md`](docs/guides/theme-usage.md), [`docs/reference/standard-params.md`](docs/reference/standard-params.md).
- **API documentation** — https://pub.dev/documentation/trellis/latest/

## Project status

Trellis is in active early development. The template engine is published on [pub.dev](https://pub.dev/packages/trellis); the surrounding SDK packages are maturing toward a coordinated release. APIs may still change between minor versions.

## Development

The repository is a [Dart workspace](https://dart.dev/tools/pub/workspaces) using [Melos](https://melos.invertase.dev/) for multi-package scripts.

**One-time setup** — activate Melos globally so `melos run <script>` works:

```bash
dart pub global activate melos
dart pub get          # resolves all workspace packages
```

**Common commands** (with global Melos):

```bash
melos run analyze       # static analysis across all packages
melos run test          # run tests in all packages (ordered by dependency)
melos run format:check  # check formatting
```

**Documentation site preview** (from the repository root):

```bash
tool/serve_docs.sh       # builds and serves http://localhost:8765
tool/serve_docs.sh 9000  # optional custom port
```

This creates a root-served snapshot rather than watching source files. Stop it
with Ctrl-C and rerun the command after changes. See the
[docs-site README](site/README.md#preview-locally) for the production sub-path
and link-checking workflow.

**CI-safe alternatives** (no global Melos required):

```bash
dart run melos exec --dir-exists lib -- dart analyze --fatal-infos
dart run melos exec --dir-exists test --fail-fast --order-dependents -- dart test
```

### Pre-publication validation

Before publishing packages, validate the generated starter app works with the local packages:

```bash
# 1. Generate a test project
dart run packages/trellis_cli/bin/trellis.dart create smoke_test

# 2. Add dependency_overrides so it uses local packages (not pub.dev)
cat >> smoke_test/pubspec.yaml << 'EOF'
dependency_overrides:
  trellis:
    path: ../packages/trellis
  trellis_shelf:
    path: ../packages/trellis_shelf
  trellis_dev:
    path: ../packages/trellis_dev
EOF

# 3. Resolve, analyze, and run
cd smoke_test
dart pub get
dart analyze --fatal-infos
dart run bin/server.dart   # visit http://localhost:8080
```

**Release validation**:

```bash
# Verify generated starters and materialized examples before publishing
cd packages/trellis_cli
dart test -t e2e \
  test/generated_app_e2e_test.dart \
  test/dart_frog_e2e_test.dart \
  test/relic_e2e_test.dart \
  test/examples_smoke_test.dart
```

This covers starter generation plus the checked-in `examples/shelf_app`, `examples/dart_frog_app`, `examples/relic_app`, and `examples/todo_app`.

**Publishing order** — publish in dependency order: `trellis` first, then `trellis_shelf`, `trellis_dev`, and `trellis_css` (all depend on `trellis`), then `trellis_dart_frog` and `trellis_relic` (depend on `trellis_shelf`), then `trellis_site` and `trellis_cli` last.

## Contributing

Trellis is in early development and we're not accepting pull requests at this time. That said, we'd love to hear from you — bug reports, feature ideas, and general feedback are all very welcome! Please feel free to [open an issue](https://github.com/tolo/trellis/issues).

## License

MIT
