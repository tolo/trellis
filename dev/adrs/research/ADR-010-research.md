# ADR-010 Research Appendix: Syntax Highlighting Strategy

Curated research supporting [ADR-010](../ADR-010-syntax-highlighting.md).

This appendix condenses the evidence behind choosing **build-time syntax
highlighting in Dart** (`package:highlight`) over client-side highlighting for the
Trellis SSG. It covers the prior-art precedent, a hands-on `package:highlight`
feasibility spike (identity, language coverage, HTML output shape, CSS mapping,
risks), the pub.dev alternatives, and the weighted comparison.

## Objective

Decide where and how Trellis highlights fenced Markdown code blocks in
`trellis_site` output, under the SDK's binding constraints: pure Dart, no Node.js,
no JS build step, AOT-compatible, self-contained static output, progressive
enhancement, and no runtime CDN dependencies in shipped themes — without anchoring
on the incumbent client-side Prism.

## Prior Art

- **Hugo** (leading SSG) highlights **at build time** with **Chroma** (a native Go
  tokenizer), emitting pre-colored HTML with CSS classes; no client JS by default.
  This is the reference model for Option A.
- **Zola** likewise highlights at build (syntect / Sublime grammars).
- **Eleventy / Jekyll** commonly use build-time plugins (`@11ty/eleventy-plugin-syntaxhighlight`
  wrapping Prism at build, Rouge for Jekyll) — again server/build-side, not shipped JS.
- **Docusaurus / MkDocs** lean client-side (Prism/highlight.js) — but they are
  JS/Python toolchains with a different asset model.

The dominant SSG pattern is **build-time highlighting**. Client-side is the
exception, driven by dynamic content or JS-first toolchains — neither of which
applies to a pure-Dart static generator.

## Feasibility Spike — `package:highlight`

Hands-on: a throwaway Dart console project with `dart pub add highlight`, sample
snippets highlighted and inspected, package source read under `lib/`, run on Dart
3.12.

### 1. Identity & health

| Field | Value |
|---|---|
| Version | **0.7.0**, published **2021-03-07** |
| Publisher | Unverified uploader |
| License | MIT |
| Pub points | 120 / 160; ~59 likes; ~233k downloads/30d (heavy transitive use) |
| Null-safety / Dart 3 | Yes (`is:null-safe`, `is:dart3-compatible`) |
| Declared SDK | `>=2.12.0 <3.0.0` — but resolves & runs cleanly under Dart 3.12 with plain `pub add`, no override |
| Deps | `collection` only (current) |

**Maintenance**: stale-but-stirring. Last pub.dev release 2021; a GitHub revival is
in progress (repo `pd4d10/highlight.dart`: workspace migration, Dart-3 SDK
constraint, regenerated grammars, unreleased **0.7.1** targeting "190+ languages"),
but nothing newer than 0.7.0 has shipped. Structurally a faithful port of
highlight.js `core.js` (the compile/terminators/mode-stack algorithm), emitting the
`hljs-*` class convention.

### 2. Language coverage

**189 languages registered.** All Trellis-required languages present (verified live,
including alias resolution): `dart`, `xml` (alias `html`), `css`, `scss`,
`javascript` (`js`), `typescript` (`ts`), `json`, `yaml` (`yml`), `bash`/`shell`
(`sh`, `zsh`), `markdown` (`md`), `python` (`py`), `java`, `sql` — plus go, rust,
kotlin, swift, php, ruby, c/cpp, dockerfile, nginx, ini, diff, graphql, and ~160
more. Registration is via an all-languages import (`languages/all.dart`); a curated
per-language registry is also available. Auto-detection exists but is **opt-in and
discouraged** (brute-forces every grammar; the package's own docs warn of
performance cost). **Always specify the language explicitly.**

### 3. HTML output shape

API: `highlight.parse(source, language: 'dart').toHtml()`. `Result` exposes **both**
a walkable token tree (`List<Node>`) and a rendered HTML string. `toHtml()` emits
`<span class="hljs-{class}">` (faithful hljs convention), with **no root wrapper**
(caller supplies `<pre><code>`), and HTML-escapes text (`&`, `<`, `>`).

Dart sample (verbatim):
```html
<span class="hljs-class"><span class="hljs-keyword">class</span> <span class="hljs-title">Greeter</span> </span>{
  <span class="hljs-keyword">final</span> <span class="hljs-built_in">String</span> name;
  <span class="hljs-keyword">const</span> Greeter(<span class="hljs-keyword">this</span>.name);
  <span class="hljs-built_in">String</span> greet() =&gt; <span class="hljs-string">"Hello, <span class="hljs-subst">$name</span>!"</span>;
}
```

HTML/XML sample (verbatim):
```html
<span class="hljs-tag">&lt;<span class="hljs-name">p</span> <span class="hljs-attr">tl:text</span>=<span class="hljs-string">"${msg}"</span>&gt;</span>placeholder<span class="hljs-tag">&lt;/<span class="hljs-name">p</span>&gt;</span>
```

CSS/JSON/Python samples similarly produced valid, correctly-classed output. All 13
required languages verified.

### 4. CSS mapping — the classes themes must style

Across varied snippets, **32 distinct token classes** observed:
```
addition, attr, attribute, built_in, bullet, class, code, comment, deletion,
emphasis, function, keyword, link, literal, meta, meta-keyword, name, number,
params, quote, regexp, section, selector-class, selector-pseudo, selector-tag,
string, strong, subst, symbol, tag, title, variable
```
highlight.js's canonical reference defines **~49 stylable scopes**; a full theme
stylesheet realistically needs **~35–45 `.hljs-*` rules**, with the top ~15
(`keyword`, `string`, `comment`, `number`, `built_in`, `title`, `params`,
`function`, `class`, `tag`, `attr`, `attribute`, `name`, `meta`, `literal`)
covering the vast majority of visible tokens. These map cleanly onto Trellis's
existing `--trellis-code-*` custom properties (the same properties arbor/verdant
already drive from `.token.*`).

### 5. Risks (and why they are bounded)

- **Staleness** (0.7.0, 2021). Bounded: build-time only (never shipped to the
  browser), MIT + pure Dart + one dep → trivially **forkable/vendorable**; output
  is stable `hljs-*` classes; revival in progress.
- **Silent plaintext fallback on unknown language** — `parse` does not throw on a
  bad language string; it renders plaintext but echoes the bad string via
  `Result.language`. Guard: validate the fence language against `allLanguages.keys`
  + aliases before tokenizing; unknown ⇒ leave the block plain.
- **Debug `print()` in the auto-detection hot path** + minor analyzer warnings and a
  discontinued transitive dev-dep (`pedantic`) in the package. Avoided by always
  specifying language (never auto-detecting); dev-deps don't affect consumers.
- **Older hljs class scheme** (nested wrapper spans + hyphenated names vs. modern
  dotted sub-scopes) — author theme CSS against this package's real output, not a
  copy-pasted modern highlight.js theme. Common single-class selectors match fine.

### 6. Alternatives (pub.dev, checked live)

| Package | Pure-Dart / build-time? | Coverage | Verdict |
|---|---|---|---|
| **`highlight` 0.7.0** | ✅ pure Dart, build-time | 189 langs, `hljs-*` HTML | **Chosen** — only option that fits all constraints |
| `flutter_highlight` | ❌ Flutter widget over `highlight` | same 189 | Render layer only; irrelevant to a pure-Dart SSG |
| `highlighter` 0.1.1 | ✅ pure Dart | ~same | Abandoned near-duplicate of `highlight`; no advantage |
| `re_highlight` 0.0.3 | ❌ hard `flutter` dep | broad | Flutter-only; disqualified |
| `syntax_highlight` (Serverpod) 0.5.0 | ❌ `flutter` + platform deps | ~14 langs (no scss/bash/markdown/xml) | Higher-fidelity TextMate tokenization, but Flutter-coupled, narrower, emits styled `TextSpan`s not classed HTML; would need a serializer + fill coverage gaps |
| `syntax_highlight_lite` 0.0.1 | ✅ pure Dart | **Dart only** | Bakes colors into a span tree (no semantic CSS classes) — wrong output model; single-language |
| `prism` 2.x | — | — | Red herring — a color-manipulation lib, not a highlighter |

**Bottom line**: nothing on pub.dev beats `package:highlight` for a pure-Dart,
build-time, CSS-classed, broad-language HTML emitter. The TextMate options offer
nicer tokenization for a few languages but are Flutter-coupled and/or emit the wrong
output shape, and still leave coverage gaps `highlight` fills for free.

## Weighted Comparison (A vs B vs C)

| Driver | A: Build-time Dart | B: Client highlight.js | C: Client Prism (status quo) |
|---|---|---|---|
| Pure Dart, no npm/Node | ✅ (build dep only) | ✅ (vendored) | ✅ (vendored) |
| Zero client JS / works with JS off | ✅ | ❌ | ❌ |
| Self-contained output, no per-theme asset dup | ✅ | ⚠️ 1 file × 3 themes | ❌ 9 files × theme |
| No runtime CDN | ✅ | ✅ | ✅ (old verdant used CDN — removed) |
| Arbitrary end-user languages | ✅ 189 | ✅ broad | ❌ fixed grammar set |
| Consistent token-CSS convention | ✅ `.hljs-*` (purger-ready) | ✅ `.hljs-*` | ⚠️ `.token.*` (Prism-specific) |
| Dependency risk | ⚠️ stale pkg (bounded) | ✅ | ✅ |

Option A wins every driver except the single (bounded, build-time-only)
`package:highlight` dependency — the decisive trade for eliminating all shipped
highlighter JS across every theme.

## Corroborating Signals

- The Phase 5 CSS-purger design already safelists `/^hljs-/`
  (`docs/specs/sdk-phase5/prd-draft.md`, private repo) — downstream tooling was
  already designed around highlight.js classes, not Prism's `.token.*`.
- The incumbent Prism grammar set was sized to the **doc-site's fixed language
  list** and paired with a since-removed SRI discipline — a sunk-cost artifact, not
  a general highlighting decision.

## References

- `package:highlight`: https://pub.dev/packages/highlight · repo https://github.com/pd4d10/highlight.dart
- highlight.js CSS class reference: https://highlightjs.readthedocs.io/en/latest/css-classes-reference.html
- Hugo syntax highlighting (Chroma): https://gohugo.io/content-management/syntax-highlighting/
- Zola syntax highlighting (syntect): https://www.getzola.org/documentation/content/syntax-highlighting/
- `package:markdown` `FencedCodeBlockSyntax` (emits `language-*` class): https://pub.dev/packages/markdown
