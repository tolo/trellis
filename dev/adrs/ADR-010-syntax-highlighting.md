# ADR-010: Syntax Highlighting Strategy — Build-Time in Dart

## Status
Accepted (2026-07-08) — Implemented (2026-07-11, branch `feature/0.10.0`, ships in
v0.10.0). Supersedes the unrecorded, de-facto "vendored client-side Prism" approach
previously in the `arbor` theme.

## Context

The Trellis SSG (`trellis_site`) renders fenced Markdown code blocks to
`<pre><code class="language-x">…</code></pre>` and stops — it does **not** highlight
at build time ([`markdown_renderer.dart`](../../packages/trellis_site/lib/src/markdown_renderer.dart)
just calls `md.markdownToHtml(...)`). All coloring today is client-side and lives
in the themes, inconsistently:

- **`arbor`** (docs theme) vendors **Prism 1.29.0** client-side: core + `clike` +
  7 grammars = **9 same-origin JS files** under `static/prism/`, nine `<script>`
  tags in `base.html` gated on a `syntax_highlighting` theme param, styling Prism
  `.token.*` classes. This set was sized to the doc-site's own **fixed language
  list** (Dart, HTML, CSS, YAML, Bash, SCSS, Markdown) — not to arbitrary content.
- **`verdant`** (blog theme) previously loaded Prism core + the autoloader **from a
  CDN** (a runtime external dependency with on-demand grammar fetching). That was
  removed; verdant now ships **no** highlighter — code renders clean but uncolored.
  Its `_code.scss` still styles Prism `.token.*` and its `syntax_highlighting` param
  gates nothing.
- **`bloom`** (landing theme) carries the same `syntax_highlighting` param + a
  `.token.*` `_code.scss` stub.

There is no ADR for any of this. Prism arrived as an artifact of the doc-site's
narrow, fixed language set (and a since-removed Subresource-Integrity discipline),
then was quietly generalized into "the theme highlighter." We are pre-1.0 and want
a recorded, first-principles decision — not sunk-cost anchoring on the incumbent.

The decision is **where and how Trellis highlights code**: at build time in Dart
(emit pre-colored HTML, zero client JS), or client-side (ship a JS highlighter with
each theme).

Research: [ADR-010 research appendix](research/ADR-010-research.md) (includes a
hands-on `package:highlight` feasibility spike).

## Decision Drivers

- **Pure Dart, no Node.js, no JS build step** — the core SDK differentiator. A
  highlighter must not reintroduce npm or a bundler.
- **Self-contained static output** — the SSG's value proposition is a folder you can
  host anywhere. Fewer shipped assets, fewer moving parts, works with JS disabled.
- **No runtime CDN dependencies in shipped themes** — external hosts are a
  privacy, availability, and supply-chain liability for a static site.
- **Arbitrary end-user content** — a general SSG highlights whatever language the
  author fences, not a curator's fixed list.
- **Consistency across the official themes** (arbor / verdant / bloom) — one
  highlighting model, one token-CSS convention, styled per theme.
- **Progressive enhancement** — code must remain readable when a highlighter is
  absent or JS is off.
- Explicitly: **do not choose an option because it is already present.**

## Options

### A. Build-time highlighting in Dart (Recommended)
The SSG tokenizes fenced code **during `trellis build`** and emits pre-colored
HTML; **zero client-side JS**. Themes ship only token CSS. Precedent: **Hugo**, the
leading SSG, highlights at build with Chroma (native Go) by default. Candidate
tokenizer: [`package:highlight`](https://pub.dev/packages/highlight) — a pure-Dart
port of highlight.js emitting `<span class="hljs-*">`.

- (+) No client JS shipped; pages load faster and render colored with JS disabled
- (+) Self-contained output — no vendoring, no CDN, no SRI question ever, no
  per-theme asset duplication
- (+) Broad language coverage (189 languages incl. Dart) from one build-time dep
- (+) One token-CSS convention (`.hljs-*`) reused across all themes; the Phase 5
  CSS purger already anticipates `hljs-*` classes
- (+) Highlighting becomes an engine capability, not a per-theme concern —
  verdant/bloom get colored code for free once themes ship token CSS
- (−) Adds `package:highlight` as a `trellis_site` dependency (build-time only)
- (−) `package:highlight` is **stale** on pub.dev (0.7.0, 2021) — see Risks
- (−) Re-highlighting on every full build (cheap; scoped to changed pages with
  incremental builds later)

### B. Client-side highlight.js (single vendored bundle)
Ship one self-contained, vendored `highlight.min.js` per theme (`.hljs-*` classes,
auto-detect). Simpler to vendor than Prism (1 file vs 9), still client-side.

- (+) One vendored file; broad language coverage; same `.hljs-*` CSS as Option A
- (+) No build-time tokenizer dependency
- (−) Ships JS to every visitor; no color with JS disabled until it loads
- (−) Still a vendored asset to pin, audit, and duplicate across three themes
- (−) Client-side auto-detect is a guess; larger bundle for all-language coverage

### C. Client-side Prism, per-grammar vendored (status quo, `arbor`)
The current approach: vendor Prism core + one grammar per language, style `.token.*`.

- (+) "Ship only the grammars you need" minimizes bytes **for a fixed language set**
- (−) A fixed grammar set does not fit arbitrary end-user content (a fenced
  language with no vendored grammar renders uncolored)
- (−) 9 files per theme to vendor, order, and maintain; `.token.*` is a
  Prism-specific CSS convention diverging from the `.hljs-*` ecosystem
- (−) Client-side, JS-dependent, per-theme duplication — the very costs Option A
  eliminates

## Weighted Trade-off Analysis

Structured comparison (scores 1–5 × weight; only criteria that discriminate — pure
Dart / no-npm / no-JS-build is a **gate all three pass**, not a weighted axis). See
the [trade-off report](../../../trellis-private/docs/research/08-syntax-highlighting-tradeoff.md)
(private) for the full derivation.

| Criterion (weight) | A: Build-time Dart | B: Client hljs | C: Client Prism |
|---|---|---|---|
| Self-contained / zero-JS output (25%) | 5 | 2 | 2 |
| Progressive enhancement — colored w/ JS off (20%) | 5 | 2 | 2 |
| Arbitrary-language coverage (15%) | 5 | 4 | 2 |
| Cross-theme consistency & maintenance (15%) | 5 | 3 | 2 |
| Dependency risk / longevity (15%) | 2 | 5 | 4 |
| Build performance / complexity (10%) | 3 | 5 | 5 |
| **Weighted total** | **4.35** | 3.20 | 2.60 |

A leads decisively and is **robust to weight flattening** (even-weighting stress
test: 4.17 / 3.50 / 2.83). Sensitivity: A is overtaken by B **only** when
dependency-risk is weighted ≈50%+ — the single lever that flips the decision, and
one deliberately not given dominance (the SDK's self-contained-output value is the
decisive criterion).

### Framework validation

The scoring is corroborated by named design frameworks:

- **Ousterhout (deep modules / pull complexity down)** — build-time A is a *deep
  module*: trivial interface (fenced code → colored HTML), complexity absorbed by
  the engine. Client Prism (C) is *shallow and leaky* — every theme re-implements 9
  ordered `<script>` tags + gating. A pulls that complexity down into the SSG.
- **CUPID** — A is more **Predictable** (deterministic build output vs. client
  auto-detect), more **Idiomatic** (matches both Trellis's build-time/pure-Dart/AOT
  idiom and the dominant SSG idiom — Hugo/Zola highlight at build; client-Prism is
  idiomatic to JS-SPA doc tools, not a Dart SSG), and more **Composable** (token CSS
  composes; no JS load-order coupling).
- **Martin (SDP / stable-dependencies)** — siting the volatile, stale
  `package:highlight` inside the `trellis_site` **build tool** (never the shipped
  theme artifact) points the dependency the right way: themes depend on nothing, and
  the build boundary quarantines the risky dep.

## Decision

**Adopt Option A: build-time syntax highlighting in Dart, in `trellis_site`, using
`package:highlight`.** The SSG highlights fenced code during the build and emits
pre-colored `<span class="hljs-*">` HTML. **No client-side highlighter ships in any
official theme.** Themes provide only `.hljs-*` **token CSS**, styled per skin via
the existing `--trellis-code-*` custom properties.

The feasibility spike (see appendix) confirms `package:highlight` covers every
language Trellis needs (dart, html/xml, css, scss, js, ts, json, yaml, bash/shell,
markdown, python, java, sql, + ~175 more), emits faithful highlight.js `.hljs-*`
classes, HTML-escapes text, and exposes both a token tree and a rendered-HTML API —
all pure Dart, single `collection` dependency, MIT.

### Enshrined principle — asset preference order

This decision codifies a general Trellis convention (motivated here, applied
project-wide):

> **Prefer self-contained, build-time-generated output; then vendored, same-origin
> assets; and only as a last resort, runtime CDN dependencies — in shipped themes
> and SSG output.**

This is a **default with rationale, not an absolute ban**: build-time output has no
runtime cost or third-party trust surface; a vendored same-origin asset (e.g.
`search.js`, `code-enhance.js`) is auditable and outage-independent; a runtime CDN
dependency trades availability, privacy, and supply-chain integrity for convenience
and should be a deliberate, documented exception. Syntax highlighting moves from the
worst tier (CDN, in old verdant) and the middle tier (vendored client JS, in arbor)
to the best tier (build-time output).

### Enablement and defaults

- Highlighting is a **build-config** concern, not a per-theme client toggle. It is
  configured in `trellis_site.yaml` under a `highlight:` key and defaults to
  **on** (Hugo-like): fenced blocks with a recognized language get highlighted.
- A fenced block **without** a language identifier is left as plain
  `<pre><code>` — unchanged from today.
- An **unrecognized** language identifier is left as plain
  `<pre><code class="language-x">` (class preserved so CSS/copy-button still apply),
  optionally with a build warning. The highlighter validates the fence language
  against the known language + alias set **before** calling the tokenizer, because
  `package:highlight` otherwise silently falls back to plaintext while echoing the
  bad language string (see Risks).
- The language is always specified explicitly from the fence info-string;
  **auto-detection is never used** (it is slow, a guess, and triggers a debug
  `print()` in the package's hot path — see Risks).

## Consequences

### Positive
- Official themes ship **zero** client-side highlighter JS; the CDN dependency
  (old verdant) and the 9 vendored Prism files (arbor) both disappear.
- Code is colored with JavaScript disabled; faster page loads; smaller themes.
- One highlighting model and one `.hljs-*` token-CSS convention across all themes;
  verdant and bloom gain colored code with only a CSS-class migration.
- The `VENDORED.md` / SRI question for highlighting is retired permanently — there
  is nothing client-side to vendor or pin.
- Aligns with the Phase 5 CSS purger, which already safelists `/^hljs-/`.

### Negative
- `trellis_site` gains a `package:highlight` dependency. It is build-time only
  (never shipped to the browser), pure Dart, single transitive dep — but it is a
  **stale** package (see Risks).
- Themes must migrate token CSS from Prism `.token.*` to highlight.js `.hljs-*`
  (arbor, verdant, bloom) — a one-time, mechanical, per-theme change.
- Full rebuilds re-highlight all code (negligible vs render time; naturally scoped
  by future incremental builds).

### Neutral
- Core `trellis` (the template engine) is untouched — highlighting is SSG-only.
- The per-theme `syntax_highlighting` param loses its original job (gating client
  scripts). It is retired from themes; the on/off switch lives in build config.
  Token CSS is emitted unconditionally (harmless when highlighting is off — no
  `hljs-*` spans are produced, and `<pre>/<code>` base styles still apply).
- `code-enhance.js` (copy button + language label) stays: it is a genuine
  progressive enhancement independent of highlighting, reads the `language-*` class
  and `textContent`, and needs no tokenizer.

### Risks (`package:highlight` staleness) and mitigations
- **Stale on pub.dev**: last release 0.7.0 (2021); pubspec declares `<3.0.0` but
  resolves and runs cleanly under Dart 3.12. A revival is in progress on GitHub
  (workspace migration, Dart-3 SDK, unreleased 0.7.1) but unshipped.
  *Mitigation*: build-time-only blast radius; MIT + pure Dart + single `collection`
  dep make it trivially **forkable/vendorable** if it breaks; output is stable
  `.hljs-*` classes; a pinned version is deterministic.
- **Silent plaintext fallback on unknown language** (echoes the bad language via
  `Result.language`). *Mitigation*: validate the fence language against
  `allLanguages.keys` + known aliases before tokenizing; treat unknown as
  "leave plain" (+ optional warning).
- **Debug `print()` in the auto-detection path** + minor analyzer warnings in the
  package. *Mitigation*: always pass an explicit language (never auto-detect),
  avoiding that path entirely.
- **Older hljs class scheme** (nested wrapper spans + hyphenated names, not the
  modern dotted sub-scopes). *Mitigation*: author theme token CSS against **this
  package's actual output**, not a copy-pasted modern highlight.js theme (the
  common `.hljs-keyword`/`.hljs-string`/… single-class selectors match fine).

Nothing on pub.dev beats `package:highlight` for a pure-Dart, build-time,
CSS-classed, broad-language HTML emitter: `flutter_highlight`/`re_highlight` are
Flutter-coupled, `syntax_highlight` (Serverpod) is Flutter-coupled + narrower +
emits styled `TextSpan`s not classed HTML, and `syntax_highlight_lite` is Dart-only
but single-language. See the appendix for the full comparison.

## Implementation Sketch

**Implemented as sketched (2026-07-11, branch `feature/0.10.0`).** The steps below
are retained as an accurate as-built record — all nine were carried out substantially
as written. Step 9's arch/STATE doc sync (`dev/architecture/system-architecture.md`,
`dev/state/STATE.md`) was completed 2026-07-12 as part of review remediation.

Original scheduling note (candidate: alongside or just after SDK Phase 5 CSS
processing, which already assumes `hljs-*` classes):

1. **Dependency** — add `highlight: <pinned>` to `packages/trellis_site/pubspec.yaml`.
2. **Config** — add a `HighlightConfig` (`enabled`, optional language allowlist /
   unknown-language policy) parsed from `trellis_site.yaml`'s `highlight:` key,
   mirroring the existing `SearchConfig.fromYaml` pattern in
   [`site_config.dart`](../../packages/trellis_site/lib/src/site_config.dart).
   Default `enabled: true`.
3. **Highlighter component** — a `CodeHighlighter` in `trellis_site` that takes
   rendered HTML, finds `pre > code[class^="language-"]` (reuse `package:html`,
   already a core dep, for correct entity round-tripping), reads the raw code via
   the parsed node's text, validates the language, calls
   `highlight.parse(code, language: lang).toHtml()`, and replaces the `<code>`
   inner HTML with the `.hljs-*` spans. Fenceless / unknown-language blocks pass
   through untouched.
4. **Pipeline wiring** — inject the highlighter into `MarkdownRenderer` so
   `render()` post-processes after `markdownToHtml`
   ([`trellis_site_builder.dart:194`](../../packages/trellis_site/lib/src/trellis_site_builder.dart)),
   and apply the same pass to the `markdownToHtml` call in
   [`shortcode_processor.dart`](../../packages/trellis_site/lib/src/shortcode_processor.dart).
5. **Theme token-CSS migration** — rewrite the `.token.*` rule blocks in
   **arbor** (`_code.scss` ~L115–171) and **verdant** (`_code.scss` ~L38–93) to
   highlight.js `.hljs-*` selectors, keeping the existing `--trellis-code-*`
   custom-property mapping and per-skin colors. Author against the package's real
   output. **bloom** has no `.token.*` rules (only base `pre`/`code` container
   styles) — nothing to migrate there.
6. **Retire arbor's vendored Prism** — delete `themes/arbor/static/prism/*` (9
   files), remove the nine gated `<script>` tags in `base.html` (~L38–59), drop the
   Prism section from `themes/arbor/VENDORED.md` (leaving first-party
   `search.js` / `code-enhance.js`), keep `code-enhance.js`.
7. **Retire the theme `syntax_highlighting` param** — remove from arbor/verdant/bloom
   manifests (in bloom it is already inert/unreferenced) and drop verdant's stale
   `$trellis-syntax-highlighting !default` SASS var (`_variables.scss` ~L59–64);
   token CSS is now unconditional and the enable switch is build config.
8. **Verdant/bloom** — no client work: once themes ship `.hljs-*` token CSS and the
   build highlights by default, their code blocks are colored. (Interim: verdant
   stays uncolored until this lands — it never advertised highlighting, so nothing
   regresses; **do not vendor Prism into verdant meanwhile**.)
9. **Docs** — write the "self-contained / vendored-over-CDN" convention into
   `docs/guides/theme-authoring.md` (a new static-assets subsection) with a pointer
   from the repo `CLAUDE.md` `## Conventions` section; update the stale
   "vendored Prism + SRI / 9 SRI hashes" text in
   `dev/architecture/system-architecture.md` (L434–437, L447) and `dev/state/STATE.md`
   (L15).

### ADR location
This ADR lives in the **public** repo `dev/adrs/` (as ADR-010), consistent with
ADR-001…009 — all ADRs are public so contributors read them on GitHub, and the
implementation lands here. It is **not** duplicated into the private repo (a copy
would only drift); the private research index carries a pointer for inventory
completeness.

## Alternatives Considered
See Options A/B/C above, the [Weighted Trade-off Analysis](#weighted-trade-off-analysis)
(A 4.35 / B 3.20 / C 2.60), and the [research appendix](research/ADR-010-research.md).
Option A wins on every decision driver except the single `package:highlight`
dependency, whose risk is bounded to build time and mitigated by forkability — and
that risk only flips the decision if weighted to dominance, which it is not.

This decision was validated via a structured weighted trade-off (andthen:architecture
`trade-off,advise`); the criteria weights and the dominance of self-contained /
zero-JS output were confirmed with the maintainer.

## References
- Research: [ADR-010 research appendix](research/ADR-010-research.md)
- Trade-off report (weighted matrix + framework analysis): [`docs/research/08-syntax-highlighting-tradeoff.md`](../../../trellis-private/docs/research/08-syntax-highlighting-tradeoff.md) (private)
- `package:highlight`: https://pub.dev/packages/highlight
- highlight.js CSS class reference: https://highlightjs.readthedocs.io/en/latest/css-classes-reference.html
- Hugo syntax highlighting (Chroma, build-time): https://gohugo.io/content-management/syntax-highlighting/
- Related: [ADR-006](ADR-006-css-strategy.md) (CSS strategy — Phase 5 purger safelists `hljs-*`), [ADR-008](ADR-008-ssg-theme-system.md) (theme system)
- Integration points: [`markdown_renderer.dart`](../../packages/trellis_site/lib/src/markdown_renderer.dart), [`site_config.dart`](../../packages/trellis_site/lib/src/site_config.dart), [`trellis_site_builder.dart`](../../packages/trellis_site/lib/src/trellis_site_builder.dart)
