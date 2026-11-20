# ADR-015: Block Script-Capable URL Schemes in Dynamic URL Attributes

## Status
Accepted (owner, 2026-11-18). Breaking change, shipped in 0.14.0 under the pre-1.0 lockstep rule (ADR-009).

## Context

Every attribute a directive writes ends in one function, `_setAttribute` in
[`attr_processor.dart`](../../packages/trellis/lib/src/processors/attr_processor.dart): the shorthands (`tl:href`,
`tl:src`), `tl:attr`, `tl:attrs`, and the host pass that builds a fragment's `...rest` map. It only HTML-escapes the
value on serialisation. So `<a tl:href="${u}">` with `u = 'javascript:alert(1)'` renders a working `javascript:` link,
and the docs told callers to scheme-check every untrusted URL in Dart. TD-026 recorded the same sink in the folio and
meadow themes, where front matter reaches `tl:href`.

HTML-escaping cannot help: the browser decodes the attribute before it parses the URL. Thymeleaf does no scheme check
either. Go's `html/template` replaces an unsafe URL with `#ZgotmplZ`; Google Closure/Soy with `about:invalid#zSoyz`.

No other code writes a data-chosen attribute value. Inline `[[...]]` rewrites only template text nodes
(`inline_processor.dart`), never attributes. A `@{...}` URL expression's path is raw template text and its parameters
are percent-encoded, so it cannot carry a data-chosen scheme. The other attribute writers in the SDK set `class`
(`trellis_css` scope processor) or copy attributes verbatim (`fragment_processor.dart`).

## Decision

1. **Checked writes.** A value an expression produces and a directive writes to `href`, `src`, `action`, `formaction`,
   `data` or `xlink:href` is checked, on any element, matching the name ignoring ASCII case and `xlink:href` by its
   qualified name. An attribute written literally in the template is never checked. "Dynamic" means "came from an
   expression", so `tl:href="'javascript:void(0)'"` and a `#{msg}` result are checked too.
2. **Rule: a denylist.** The value is normalised as a browser's URL parser would see it: leading and trailing
   U+0000–U+0020 removed, ASCII tab, LF and CR removed anywhere, the scheme and a `data:` MIME type ASCII
   case-folded. It is unsafe when its scheme is `javascript` or `vbscript`, or it is `data:` with any media type other
   than `image/png`, `image/gif`, `image/jpeg`, `image/webp` or `image/avif` followed by `;` or `,`. Everything else,
   relative URLs included, passes unchanged.
3. **Replacement.** An unsafe value is written as `about:invalid#trellis-unsafe-url`. It never navigates or runs, and
   the marker is greppable in output and logs.
4. **Opt-out: `TrustedUrl`.** A new exported value type, `TrustedUrl('...')`, put in the render context from Dart,
   is written as-is. Trust is decided where the data's origin is known and cannot come from template text.
   `toString()` returns the URL. Concatenation, `|...|` literals and built-in filters return `String`, so they drop
   trust, which fails safe. A user-registered filter that returns a `TrustedUrl` is a deliberate opt-out.
5. **`...rest` maps count as checked.** Every value in a rest map is either a template literal on the host or already
   went through the check when the host pass ran, so the engine marks the map and `tl:attrs` writes its values
   without checking again. Reading one value out (`tl:href="${rest.href}"`) is an ordinary expression and is checked.
6. **Strict mode behaves the same.** An unsafe URL comes from data, not a template bug; throwing would let
   user-entered data fail renders wherever strict mode runs.
7. **No validator change.** `TemplateValidator` reads template text and cannot see runtime values.

## Consequences

- Untrusted URLs in the six attribute names are safe by default; callers no longer scheme-check them in Dart.
  TD-026 closes: theme front matter is rendered through the same check.
- A legitimate dynamic `javascript:` URL, a `data:image/svg+xml` value or any other `data:` URL now renders
  `about:invalid#trellis-unsafe-url` until the app wraps it in `TrustedUrl`. `data:image/svg+xml` in `<img src>` is
  harmless there but blocked, because the same value in `<object data>` or `<iframe src>` runs script.
- `TrustedUrl` is a value, not a string: `${t} == '/a'` is false, `${t.value}` is not a member, and `${t} + ${t}`
  throws. It has no `toJson()`, which the evaluator would reject for not returning a map.
- Out of scope and still the caller's job: dynamic `srcdoc`, `on*`, `style`, `hx-on*` and `hx-vals="js:..."`, SVG
  `<set to>`, and attributes a custom processor writes to `element.attributes` directly, which bypass the check.
- `trellis_site` builds its engine from YAML context with no filters, so a site author cannot pass a `TrustedUrl`.
  Adding a way later is additive (TD-059). The out-of-scope values above are tracked as TD-060.
- Second opinion (oracle, 2026-11-18): agreed with the default and the denylist, and found that `TrustedUrl` was
  flattened to a string in the rest map and then re-blocked in the callee. Decision 5 is the fix it proposed.

**Reversal**: one-way door. Turning the default off or swapping the denylist for an allowlist is another breaking
change for every app that adapted, and removing `TrustedUrl` breaks its callers.

## Alternatives Considered

1. **Allowlist** (relative plus `http`, `https`, `mailto`, `tel`, as Go does) – rejected: breaks `sms:`, `geo:`,
   `ftp:` and app deep links, and widening it later is another change. The denylist's residual risk is a future
   script-capable scheme.
2. **Replace with `#`, drop the attribute, or throw** – rejected: `#` jumps to the page top and hides the substitution;
   an `<a>` without `href` stops being a link; throwing lets user data turn a page into a 500.
3. **Engine-wide `sanitizeUrls: false` flag, a template-side `tl:uhref`-style directive, or both with the wrapper** –
   rejected: one line disables protection everywhere, or any template author can opt out, and each adds surface to
   document and test.
4. **Check every URL-valued attribute** (`cite`, `background`, `ping`, `srcset`, `poster`, ...) – rejected: none runs a
   `javascript:` URL in current browsers, and `srcset` needs list parsing.
5. **Floor option – keep HTML-escaping only and document the caller's duty** – rejected: the docs already said so and
   the themes still shipped the sink (TD-026).

## Implementation Notes

- One check in `_setAttribute`, keyed on the attribute name; delete the unused `_urlAttributes` constant, which
  described percent-encoding and listed `poster`.
- Hand-roll the trim: `String.trim()` leaves `\x01` (which a browser strips) and removes U+00A0 (which a browser
  keeps). Do not use `Uri.tryParse` as a gate: it returns `null` for `\x01javascript:` and `java\tscript:`.
- `captureHostAttributes` returns the rest map as a private unmodifiable map type that `_spreadAttributes` recognises.
- Tests fail first: the `attr_processor_test.dart` cases above, the bypass inputs, `TrustedUrl`, rest forwarding of a
  literal and of a `TrustedUrl`, and the changed doc example in `site/content/docs/syntax/attributes.md`.

## Project Compliance

Core stays minimal (Product principle 3): one function and one exported type, no dependency. AOT-safe: a type check,
no reflection. Pre-1.0 breaking change in a lockstep minor (ADR-009). Composition semantics of ADR-014 are unchanged
apart from decision 5.

## References

- ADR-009 (lockstep versioning), ADR-014 (`tl:attrs`, `...rest`).
- WHATWG URL Standard, basic URL parser (control-character and tab/newline stripping).
- Go `html/template` (`#ZgotmplZ`), Google Closure Templates (`about:invalid#zSoyz`).
