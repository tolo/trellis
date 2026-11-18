# trellis_cli

CLI tool for the [Trellis](https://pub.dev/packages/trellis) template engine: project scaffolding, static site
building, and local preview. It also manages themes for static sites.

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
VERSION=0.13.0
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
$Version = "0.13.0" # no leading "v"
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

## Quick start

Scaffold and preview a static blog:

```bash
trellis create my_blog --template blog
cd my_blog
trellis dev
```

Or in one line: `cd my_blog && trellis dev`. Then open http://localhost:8080 in your browser; it reloads as you edit.
`trellis build` writes the deployable site to `output/`.

## Features

- `trellis create`: scaffolds a Shelf + HTMX app (`htmx`, the default), a static `blog` site, a `dart_frog` app, a
  `relic` app, or a `theme` project.
- `trellis build`: builds a static site from `trellis_site.yaml` and compiles SASS/SCSS, with `--output`, `--base-url`,
  `--path-prefix`, `--drafts`, and `--verbose`.
- `trellis dev`: builds a root-served preview into a temp directory, serves it, rebuilds when site or theme files
  change, and reloads the browser. A failed rebuild keeps the last good build on screen.
- `trellis serve`: serves an already-built output directory with clean URLs (`/about/` resolves to
  `/about/index.html`).
- `trellis theme add|update|list|info|remove`: installs, pins, updates, and removes themes.

## Documentation

**[Full guide: tolo.github.io/trellis/docs/packages/trellis_cli/](https://tolo.github.io/trellis/docs/packages/trellis_cli/)**
covers every command and option, the files each template generates, theme management, and project name rules.

API reference: <https://pub.dev/documentation/trellis_cli/latest/>
