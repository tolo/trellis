---
title: Add and theme Trellis UI
description: Install the component suite, serve its assets, and override the shadcn theme tokens.
weight: 10
---

## Add the package

Run `dart pub add trellis_ui` from your app. Use the suite loader after your
existing template loader so the same engine renders app and suite fragments.

```dart
import 'package:trellis/trellis.dart';
import 'package:trellis_ui/trellis_ui.dart';

final engine = Trellis(loader: CompositeLoader([
  FileSystemLoader('templates'),
  TrellisUiLoader(),
]));
```

Link the same-origin assets in your layout.

```html
<link rel="stylesheet" href="/trellis-ui/trellis-ui.css">
<link rel="stylesheet" href="/trellis-ui/htmx-indicator.css">
<script src="/trellis-ui/trellis-ui.js" defer></script>
```

If the app uses htmx, self-host it and disable `allowEval` and
`includeIndicatorStyles` in the htmx config (`includeIndicatorCSS` on HTMX 4).
The indicator stylesheet handles the loading state.

## Serve the assets

Route `/trellis-ui/…` to the suite responder before the app fallback. Pass the
request's full path and its conditional request header. The responder supplies
the content type, ETag and cache headers.

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
  final contentType = asset.headers['content-type'];
  return Response(asset.statusCode,
    headers: Headers.fromMap(asset.headers.map((k, v) => MapEntry(k, [v]))),
    // Relic takes Content-Type from the body and drops it from the headers.
    body: Body(
      bytes: Uint8List.fromList(asset.body),
      bodyType: contentType == null ? null : BodyType.fromContentType(ContentTypeHeader.parse(contentType)),
    ));
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

If you already serve a static directory, you can materialize the same embedded
assets there at startup. Use the static directory for Shelf or Relic and
`public/trellis-ui` for Dart Frog.

```dart
import 'dart:io';
import 'package:trellis_ui/trellis_ui.dart';

materializeTrellisUi(Directory('static/trellis-ui'));
```

Materialization replaces diverging assets. Keep overrides in a separate file.

## Apply a shadcn theme block

Paste the theme's `:root` and `.dark` token declarations into an unlayered
application stylesheet. Link it before or after the suite stylesheet. The suite
uses cascade layers, so an unlayered declaration wins at either link order.
Add `dark` to an ancestor of the components for dark mode.

```css
:root {
  --primary: #164e63;
  --primary-foreground: #fff;
}

.dark {
  --primary: #a5f3fc;
  --primary-foreground: #083344;
}
```

The suite's default-token contrast checks apply to the shipped colours.
Check your new foreground and background pairs in both modes.

## Port another shadcn style

Map shadcn's `cn-` selector prefix to `trellis-` and keep the part suffix.
For example, map `cn-button` to `trellis-button` and `cn-card` to
`trellis-card`. Check the [component reference](/docs/ui/components/) for the
actual part classes rendered by each fragment. Apply the adjusted selectors
in your own stylesheet.

Shadowing a managed fragment is unsupported. Override tokens and part classes,
pass application extension classes through the caller, or compose the
fragment with native elements and slots.
