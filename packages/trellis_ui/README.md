# trellis_ui

Embedded Trellis fragments and same-origin CSS/JS derived from shadcn's Base UI vega style. The package joins SDK
lockstep releases. Its assets and templates are compiled into the application, including AOT binaries.

The button currently proves delivery and the porting pipeline. Component qualification, touch-target overrides and
support claims follow the qualification gate before release.

## Install and render

```yaml
dependencies:
  trellis: ^0.13.0
  trellis_ui: ^0.13.0
```

```dart
import 'package:trellis/trellis.dart';
import 'package:trellis_ui/trellis_ui.dart';

final engine = Trellis(loader: CompositeLoader([
  FileSystemLoader('templates'),
  TrellisUiLoader(),
]));
```

```html
<button tl:replace="~{trellis-ui/button :: button('destructive', 'sm')}"
  type="submit" hx-post="/save" disabled>Save</button>
```

Use `tl:replace` to forward the host's attributes and anonymous slot. `button(variant, size, ...attrs)` defaults to
`default`/`default`; omit both arguments for those values. Template names accept an optional `.html` suffix. Unknown
templates and fragments throw the engine's existing exceptions. `TrellisUiLoader` adds no template processing layer.

Link `/trellis-ui/trellis-ui.css`, `/trellis-ui/htmx-indicator.css` and the deferred classic script
`/trellis-ui/trellis-ui.js`. Serve these paths before the app's fallback route. All assets are same-origin and need no
inline script, inline style or eval. If using htmx, self-host it and set the `htmx-config` meta options `allowEval` and
`includeIndicatorStyles` to `false`. The gallery shows a complete strict-CSP shell.

Public Dart names: `TrellisUiLoader`, `TrellisUiResponse` (`statusCode`, `headers`, `body`), `trellisUiRespond`, and
`materializeTrellisUi`. The asset responder returns null for unknown suite paths and paths outside `/trellis-ui/`,
letting the application's router decide. Strong ETags contain the embedded SHA-256 digest; matching
`If-None-Match` returns 304 with an empty body. Use `request.uri.path` rather than a path stripped by a mounted router.

## Server wiring

### Shelf

```dart
import 'package:shelf/shelf.dart';
import 'package:trellis_ui/trellis_ui.dart';

Response suiteHandler(Request request) {
  final asset = trellisUiRespond(request.requestedUri.path, ifNoneMatch: request.headers['if-none-match']);
  if (asset == null) return Response.notFound('Not found');
  return Response(asset.statusCode, headers: asset.headers, body: asset.body);
}
```

### Relic

```dart
import 'dart:typed_data';
import 'package:relic/relic.dart';
import 'package:trellis_ui/trellis_ui.dart';

Response suiteHandler(Request request) {
  final asset = trellisUiRespond(request.url.path, ifNoneMatch: request.headers['if-none-match']?.join(','));
  if (asset == null) return Response.notFound();
  return Response(asset.statusCode,
    headers: Headers.fromMap(asset.headers.map((k, v) => MapEntry(k, [v]))),
    body: Body.fromData(Uint8List.fromList(asset.body)));
}
```

### Dart Frog

```dart
import 'package:dart_frog/dart_frog.dart';
import 'package:trellis_ui/trellis_ui.dart';

Response suiteHandler(RequestContext context) {
  final asset = trellisUiRespond(context.request.uri.path, ifNoneMatch: context.request.headers['if-none-match']);
  if (asset == null) return Response(statusCode: 404);
  return Response.bytes(statusCode: asset.statusCode, headers: asset.headers, body: asset.body);
}
```

Each snippet is exercised against its framework in `test/serving_*_test.dart`. In an existing app, replace the
not-found return with its next handler. `trellis_ui` has no runtime dependency on any server framework.

## Theme and materialize

Shadcn token names (`--primary`, `--background`, `--radius`, and their companions), `trellis-*` part classes,
application extension classes and composition are the styling surface. Paste an unlayered `:root`/`.dark` theme
block in an app stylesheet: it wins whether linked before or after the suite. Enable dark mode with `.dark` on an
ancestor. All suite declarations are layered; scoped base resets reach suite elements without resetting the host page.
Shadowing managed fragments is unsupported.

```dart
import 'dart:io';
import 'package:trellis_ui/trellis_ui.dart';

materializeTrellisUi(Directory('static/trellis-ui'));
```

Call at startup when static files are preferable. Missing directories are created; divergent assets are replaced;
equal files retain their mtimes. Filesystem errors propagate with the target path. Keep application overrides in a
separate file; materialized files are managed output.

## Maintaining components

Run from this package:

```sh
dart run tool/port.dart fetch
dart run tool/port.dart build
dart run tool/port.dart parity
dart run tool/port.dart check
dart run tool/embed.dart
dart run tool/embed.dart --check
dart run tool/gallery.dart --port 0
```

`tool/pins.json` pins the shadcn tag/commit, style, base colour, selected components and dependencies. The compiler is
Tailwind standalone v4.3.3, checked against per-platform SHA-256 pins before generation, downloaded on demand to
`.tools/`. Pipeline hosts: macOS arm64/x64 and Linux arm64/x64. Windows applications can consume the package but do not
run the pipeline. No Node, npm or Tailwind compiler runs in tests, consumer builds or runtime.

Add `assets/fragments/<component>.html`, `assets/css/hand/<component>.css`, optional `assets/js/<NN>-<name>.js`, and
`gallery/pages/<component>.html`; add the component to `tool/pins.json`, fetch, build and embed. The template name is
`trellis-ui/<component>`. Fragment roots use `data-slot`, `trellis-*` hooks and any upstream group/peer markers.
`tl:with` applies defaults to omitted parameters. Keep base classes literal and append modifiers with `tl:classappend`
so `tl:attrs` preserves caller classes without reading an optional map member in strict mode. Keep fragments free of
literal ids and asset URLs. Never add inline
styles, scripts or `on*` attributes.

The bundler orders files by name. It puts `00-base.css` in the earlier `base` layer and other hand CSS in
`trellis-hand`, then wraps ordered JS files in one classic IIFE; module syntax is rejected. The gallery discovers
page files without a registry and starts from any working directory, printing `Serving <base-url>` first.
`generated/report.json` lists hooks, slots, markers and structural literals without hooks. Parity-ignore entries need
reasons; stale entries are reported. Never edit `generated/` or `*.g.dart` directly.

The publishable archive contains embedded Dart rather than development inputs. See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for source licences and the shipped CSS banners.
