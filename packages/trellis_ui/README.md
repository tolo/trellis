# trellis_ui

Embedded Trellis fragments and same-origin CSS/JS derived from shadcn's Base UI vega style. The package joins SDK
lockstep releases. Its assets and templates are compiled into the application, including AOT binaries.

The gallery covers native form controls, data views, layouts and interactive controls. Automated qualification evidence lives
in `dev/ui-gate/` in the SDK checkout. Screen-reader and Safari qualification remain release-prep work.

## Install and render

```yaml
dependencies:
  trellis: ^0.14.0
  trellis_ui: ^0.14.0
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
inline script, inline style or eval. The gallery qualifies HTMX 2.0.10 for interactive swaps, request errors and history
restoration. Self-host it and set the `htmx-config` meta options `allowEval` and `includeIndicatorStyles` to `false`.

Public Dart names include `TrellisUiLoader`, `TrellisUiResponse` (`statusCode`, `headers`, `body`), `trellisUiRespond`,
`materializeTrellisUi` and the read-only `trellisUiAssetPaths` list of root-absolute asset URLs.
The asset responder returns null for unknown suite paths and paths outside `/trellis-ui/`,
letting the application's router decide. Strong ETags contain the embedded SHA-256 digest; matching
`If-None-Match` returns 304 with an empty body. Use `request.uri.path` rather than a path stripped by a mounted router.

## Fragment catalogue

Every signature ends in `...attrs`, forwarded to the native control or component root. Base classes survive a caller
`class`; boolean, `aria-*` and `hx-*` attributes pass through. Omitted arguments select the defaults below. Named
slots take the contents of the caller marker; unmarked caller content fills the anonymous slot.

| Template / fragment | Signature before `...attrs` | Slots | Closed values and defaults |
|---|---|---|---|
| `alert :: alert` | `variant` | anonymous description, `title` | `default`, `destructive`; fallback `default` |
| `alert-dialog :: alertDialog` | `id, title, description, open` | anonymous body, `trigger`, `action` | forwards to the native dialog; starts on Cancel; `data-open` / `data-closed` |
| `badge :: badge` | `variant` | anonymous | `default`, `secondary`, `destructive`, `outline`, `ghost`, `link`; fallback `default` |
| `breadcrumb :: breadcrumb` | `items` | none | server list of `{label, href, current}` |
| `button :: button` | `variant, size` | anonymous | variants: `default`, `outline`, `secondary`, `ghost`, `destructive`, `link`; sizes: `default`, `xs`, `sm`, `lg`, `icon`, `icon-xs`, `icon-sm`, `icon-lg` |
| `card :: card` | none | anonymous content, `title`, `description`, `action`, `footer` | default size; title is an `h2` |
| `checkbox :: checkbox` | none | none | native checkbox; `checked`, `disabled`, `aria-invalid` |
| `cluster :: cluster` | `gap` | anonymous | gap scale below; fallback `md` |
| `combobox :: combobox` | `id, name, placeholder, value, options, displayValue` | none | forwards to the visible input; `name` and `value` identify the hidden submission; `options` is a list of `{value, label}`; `data-open` / `data-closed`, `data-side`, `data-align`, `data-empty`, `data-highlighted` |
| `combobox :: comboboxOptions` | `id, options` | none | forwards to the results container; same ID and option list shape as the combobox |
| `container :: container` | `size` | anonymous | `sm` 40rem, `md` 56rem, `lg` 72rem, `xl` 80rem; fallback `lg` |
| `dialog :: dialog` | `id, title, description, open` | anonymous body, `trigger`, `footer` | forwards to the native dialog; `data-open` / `data-closed` |
| `dropdown-menu :: dropdownMenu` | `id` | anonymous menu items, `trigger` | forwards to the popup; `data-open` / `data-closed`, `data-side`, `data-align` |
| `dropdown-menu :: menuItem` | `variant` | anonymous label | native item button; `default` or `destructive`; `data-highlighted`; native `disabled` |
| `dropdown-menu :: menuCheckboxItem` | `checked` | anonymous label | native item button; `data-checked`, `data-highlighted`; native `disabled` |
| `dropdown-menu :: menuSeparator` | none | none | forwards to the separator |
| `field :: field` | `controlId, label, hint, error` | none | vertical labelled text input; caller attributes land on the input |
| `grid :: grid` | `gap, minimum` | anonymous | gap scale; minimum `sm` 10rem, `md` 15rem, `lg` 20rem; fallback `md` |
| `input :: input` | none | none | native text input; caller `type` overrides text |
| `native-select :: native-select` | `size` | anonymous native `option` / `optgroup` markup | `default`, `sm`; fallback `default` |
| `pagination :: pagination` | `pages, previous, next` | none | pages `{label, href, current, ellipsis}`; nullable previous/next URLs |
| `popover :: popover` | `id, side, align, offset` | `trigger`, `content` | forwards attributes to the panel; sides `top`, `right`, `bottom`, `left`; alignment `start`, `center`, `end`; defaults `bottom`, `start`, 4 px |
| `popover :: popoverHeader` | none | anonymous header content | forwards to the header group |
| `popover :: popoverTitle` | none | anonymous title | an `h2` |
| `popover :: popoverDescription` | none | anonymous description | a `p` |
| `radio :: radio` | `legend` | none | one native radio in a fieldset; repeat with the same `name` to group choices |
| `separator :: separator` | `orientation` | none | `vertical`, otherwise horizontal `hr` |
| `stack :: stack` | `gap` | anonymous | gap scale; fallback `md` |
| `switch :: switch` | `size` | none | `default`, `sm`; fallback `default`; native checkbox with switch role |
| `table :: table` | `caption, columns, rows` | `header`, `row`, `footer` | server lists; row marker reads the `row` map in loop scope |
| `tabs :: tabs` | `id, active, vertical` | anonymous list and panels | forwards to the layout; `active` is the initial tab value; horizontal by default, `data-orientation` |
| `tabs :: tabList` | none | anonymous tab triggers | forwards to the tab list; supply an accessible name |
| `tabs :: tabTrigger` | `value` | anonymous tab label | native tab button; `data-active`; native `disabled` |
| `tabs :: tabPanel` | `value` | anonymous panel | forwards to the panel; `hidden` and `data-hidden` follow selection |
| `textarea :: textarea` | none | anonymous text | native textarea |
| `toast :: toast` | `type, title, description, duration, outOfBand` | none | forwards to the card; `data-type`: `info` (default), `success`, `warning`, `error`; duration in ms defaults to 5000, 0 persists |
| `toast :: toastViewport` | `id` | anonymous toasts | forwards to the live region; default ID and out-of-band target `toaster` |

Template names in the table have the `trellis-ui/` prefix. Gap values are `none` 0, `xs` .25rem, `sm` .5rem,
`md` 1rem, `lg` 1.5rem and `xl` 2rem. Unrecognised layout values fall back and never create an inline style.
`trellis-ui/container :: sidebar(gap, ...attrs)` uses the same gap scale; its first child is the sidebar and its
second child is the main content. It wraps when they no longer fit and keeps DOM order. Grid minimums cap at 100%
on narrower containers. Container padding is 1rem on each inline side.

Field also exports `label(controlId, ...attrs)` with an anonymous label slot, and `fieldset(legend, ...attrs)` with
an anonymous content slot. Always supply a distinct control ID per field; hint/error IDs derive from it. Field errors
have `role="alert"` and set `aria-invalid` / `aria-describedby` on the input. Give each standalone control an accessible name through a visible `label` plus `id`, or a caller `aria-label`.
Alert has no implicit live role. Pass `role="alert"` or `role="status"` where announcement is appropriate; put a live
region in the document before injecting its content.

A table caller keeps HTML table parsing intact. A direct `tbody` marker supplies a row's contents, and the fragment
creates one valid body row group per data item:

```html
<table tl:replace="~{trellis-ui/table :: table('People', columns, people)}">
  <tbody tl:slot="row">
    <tr class="trellis-table-row">
      <td class="trellis-table-cell" tl:text="${row.name}">Name</td>
      <td class="trellis-table-cell" tl:text="${row.email}">Email</td>
    </tr>
  </tbody>
</table>
```

`columns` is a list of heading strings and `people` a list of row maps. To add sort controls, supply a direct
`<thead tl:slot="header">` with a `<tr>` and `<th scope="col">` cells. The slot replaces the generated heading
row, so the caller sets `aria-sort` on the sorted heading.

The wrapper is a labelled, focusable region
that scrolls horizontally. Keep table minimum widths in application CSS (the gallery uses 40rem). Use a natural
`select` host for native-select option content and plain text inside a textarea host.

### Interactive fragments

Use a unique base `id` for each dialog, alert dialog, menu, popover, tabs, combobox and toast viewport on a page. Menu and tab
parts derive their IDs and relationships from the parent scope. Keep tab values unique within their list and
choose an enabled tab's value for `active`. Arrow keys wrap, skip disabled items and tabs, and move focus; tabs
activate on Enter, Space or click. Menu checkbox items stay open, and item clicks also dispatch a bubbling
`tl-select` event with the item in its detail.

A dialog trigger slot contains a native button. The regular dialog provides a close button and dismisses on
backdrop click. Mark footer buttons that should close it with `data-dialog-close`. Alert dialogs provide Cancel
and close when the action slot's button runs. A server-rendered `open` dialog opens modally on connection and
honours native `autofocus`. To name a specific opener on a server response, pass its DOM ID in `data-return-focus`
on the fragment host.

The Popover trigger slot supplies the label of a native button. Click, Enter or Space opens the panel and moves focus
inside. Tabbing out of the panel closes it without moving focus again. Escape or clicking outside returns focus to
the trigger. Use a plain link or native disclosure when an action must stay available without the suite script.

Give the combobox input a separate label using its base ID. Send text through an app-chosen query parameter
(`name="q"`, for example) and use `hx-target="#<id>-results"` with `hx-swap="outerHTML"` to replace suggestions.
`comboboxOptions` can be returned with `renderFileFragment` using the same `id` and the new `options` list in the
context. `displayValue` supplies initial visible text when the stored ID is different. Typing clears the stored ID,
and Home and End remain text editing keys.

Place `toastViewport` once in the layout before any HTMX response can add toasts. A `toast` rendered by bare name
with `outOfBand: true` appends to `#toaster`. A normal in-page render supplies the toast directly to its parent.
Timers pause under hover and keyboard focus, and error toasts carry `role="alert"`.

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

From an app that depends on `trellis_ui`, run:

```sh
dart run trellis_ui:materialize [dir]
```

The default directory is `static/trellis-ui`. For a Dart Frog scaffold, pass `public/trellis-ui`.
The command replaces edited preview assets and exits non-zero with the target path if a write fails.

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

Native controls keep their 24px hit boxes separate from the 16px painted checkbox/radio and 18.4×32px switch.
The `zz-touch.css`, `zz-contrast.css` and `zz-forced-colors.css` files sort after component hand files. They enforce
44px coarse targets, 16px coarse input text, default-token destructive contrast and system-colour focus/checked paint.
Keep geometry out of `transition-property`; a pointer change must not animate through undersized hit boxes.

The bundler orders files by name. It puts `00-base.css` in the earlier `base` layer and other hand CSS in
`trellis-hand`, then wraps ordered JS files in one classic IIFE; module syntax is rejected. The gallery discovers
page files without a registry and starts from any working directory, printing `Serving <base-url>` first.
`generated/report.json` lists hooks, slots, markers and structural literals without hooks. Parity-ignore entries need
reasons; stale entries are reported. Never edit `generated/` or `*.g.dart` directly.

The publishable archive contains embedded Dart rather than development inputs. See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for source licences and the shipped CSS banners.
