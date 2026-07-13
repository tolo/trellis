# Implementation Notes

Traps, gotchas, and non-obvious patterns from implementing Trellis. Bar for inclusion: *"Would a competent developer with access to the code and git history still get bitten by this?"*

---

## Expression Evaluator

- **`|` token is overloaded**: Pipe operator (filter chains) and literal substitution delimiter share the same character. Parser disambiguates by position — `|` in `_parsePrimary()` = literal sub opener, `|` after expression in `_parsePipe()` = pipe filter.
- **`!` must be scanned after `!=`**: Longest-match-first in the scanner — `!=` checked before `!`, or `!==` expressions break.
- **`scanRawUntil()` for non-expression content**: URL paths (`@{/path}`) and message keys (`#{greeting.formal}`) contain characters (`.`, `/`, `-`) that would normally be tokenized. Use raw text scanning to read them as-is.
- **Filter args are primary-level only**: `_parseFilterArg()` accepts literals, booleans, null, and bare identifiers — NOT full expressions or operators. Keeps parsing unambiguous with the `:` delimiter.
- **Cross-file fragment regex needs greedy match**: Group 2 in `~{file :: card(${x}, ${y})}` must use `(.+)` (greedy) — lazy `(.+?)` breaks on `}` inside `${...}` expressions.
- **URL expression encoding uses `Uri.encodeComponent` (RFC 3986)**: `@{}` URL expression parameter values are percent-encoded with `Uri.encodeComponent()` — spaces become `%20`, not `+`. The previous `Uri.encodeQueryComponent()` followed HTML form encoding (`application/x-www-form-urlencoded`). The `package:html` serializer then HTML-entity-escapes attribute values (`&` → `&amp;`) — this double layer is correct and expected in rendered output.

## DOM Processing

- **Children snapshot before iteration**: Always iterate `List<Element>.from(element.children)` — DOM mutations during processing (inserts, removes) corrupt the live child list.
- **`package:html` Text node auto-escapes on serialization**: For `tl:text`, setting `Text.data` is sufficient — the HTML serializer escapes `<>&"`. But inside `<script>`/`<style>`, content is raw text with no auto-escaping — `tl:inline` JS/CSS modes must manually escape.
- **`tl:block` self-closing tags consume siblings**: HTML5 parser ignores `/>` on unknown elements like `<tl:block/>`, swallowing everything after it as children. Fixed with pre-parse normalization (`<tl:block .../>` → `<tl:block ...></tl:block>`), but the normalizer must be quote-aware — `>` inside attribute values like `tl:if="${count > 0}"` must not trigger the rewrite.
- **Fragment definitions are removed from output only if parameterized**: Non-parameterized fragments remain in output for backward compatibility. Parameterized ones (`tl:fragment="name(arg)"`) are removed (step 3.5) to prevent evaluating `${param}` in the definition's outer context.
- **Fragment registry stores param names at pre-scan time**: The `tl:fragment` attribute is stripped during processing, so param names must be captured during the `collectFragments()` pre-scan, not at resolution time.
- **Cycle detection uses string IDs, not element identity**: Fragments are cloned before processing, so element identity doesn't work. IDs are `"name"` for same-file, `"file::name"` for cross-file.

## HTML5 Parser Boundary

Templates are parsed by `package:html` (a spec-compliant HTML5 parser) *before* any `tl:*` processor runs. The tokenizer/tree-builder silently mutates malformed input – and those mutations are invisible in the post-parse DOM, so the resulting bugs are silent (wrong output, no error). The validator surfaces them by reading `HtmlParser.errors` (curated allowlist in `_surfacedParseErrors`), since the runtime cannot detect them after the fact.

- **Duplicate attributes are dropped at tokenization**: `<el tl:attr="a=${x}" tl:attr="b=${y}">` keeps only the *first* `tl:attr` – the tokenizer drops the duplicate when emitting the start-tag token (parse error `duplicate-attribute`) and `element.attributes` is a map, so the processor never sees the second. A runtime "merge multiple `tl:attr`" is therefore impossible – the data is gone before trellis runs. Correct authoring: one comma-separated `tl:attr` per element. Detection is only possible via parse errors.
- **`tl:each` on `<tl:block>` inside `<table>`/`<select>` is foster-parented out**: An unknown element in "in table" insertion mode hits `startTagOther`, which emits parse error `unexpected-start-tag-implies-table-voodoo` and relocates the node out of the table – detaching the loop scope (symptom: right row/option count, empty cells). This is the HTML5 foster-parenting rule, not a trellis bug, so it can't be prevented. Correct authoring: put `tl:each` (and other `tl:*`) directly on `<tr>`/`<option>`, not a wrapping `<tl:block>`.

## Processor System

- **`ProcessorContext.domProcessor` is typed as `dynamic`**: Avoids circular import between `processor_api.dart` and `processor.dart`. Processors cast when they need DomProcessor methods.
- **Dart `_` prefix is library-private, not class-private**: Processors in separate files cannot access `_evaluator` on `ProcessorContext` — must be public despite being "internal."
- **`ProcessorPriority.afterIteration.index` can't use dot shorthand**: Dart infers context type as `num` (from `.index`), not `ProcessorPriority`. Explicit `ProcessorPriority.afterIteration.index` is required.
- **Attribute conflict: both custom and built-in fire**: When a custom processor has the same attribute as a built-in, both execute (built-in first). True replacement requires `Dialect` with `includeStandard: false`.

## Filter System

- **`Map<String, Function>` not `Map<String, dynamic Function(dynamic)>`**: The narrower type can't accept new-style `Function(dynamic, List<dynamic>)` filters. `Function` (untyped) enables runtime arity detection without ugly casts.
- **Arity detection via `NoSuchMethodError`**: `(filter as dynamic)(value, args)` — old-style (1-arg) filters throw `NoSuchMethodError`, caught and retried without args. Consistent with `_autoConvert()` pattern.

## Strict Mode

- **Null value is not undefined**: `context.containsKey()` distinguishes between a missing key and an explicit `null` value. `{'name': null}` is valid in strict mode.
- **Null-safe traversal preserved in strict mode**: `${user.name}` where `user` is explicitly `null` returns `null` without throwing — even in strict mode.

## Engine & Caching

- **Expression cache lives on `Trellis`, not `ExpressionEvaluator`**: Evaluator instances are stateless and recreated per render. Cache on the engine persists across renders.
- **`warmUp()` counts newly cached sources, not template names**: Duplicate names or identical source content don't inflate the `loaded` count.
- **`matcher` is a runtime dependency, not dev**: `package:trellis/testing.dart` exports matcher-based APIs, so `matcher` must be a regular dependency even though it's only used in tests by consumers.

## File Watching (Dev Mode)

- **Broadcast `StreamController` for `changes` stream**: Allows multiple listeners without coupling.
- **No debounce needed**: OS-level event coalescing (inotify/FSEvents) is sufficient for dev workloads. `clearCache()` is O(1).

## Object Context

- **`toMap()` first, `toJson()` fallback**: Matches common Dart model patterns. `NoSuchMethodError` = method missing (try next); other errors = domain failure (wrap in `TemplateException`).
- **Dynamic dispatch `(target as dynamic).toMap()`**: AOT-safe — no `dart:mirrors`. This is intentional.
- **Selection merges into context**: `{...context, ...selectionMap}` — selection properties overlay but don't replace outer context variables.

## Template Inheritance

- **`tl:define` stripping must happen AFTER all merging**: The recursive `_resolveChain` must not strip `tl:define` attributes from the base template — the caller needs them to locate blocks for merging. Stripping happens once at the top level in `resolve()` after the full chain is resolved.
- **Block collection does not recurse into `tl:define` elements**: A `tl:define` inside another `tl:define` is part of the outer block's content. Overriding the outer block replaces everything, including the nested define.
- **Parent element preserved, only children replaced**: `_mergeBlocks` replaces the parent `tl:define` element's children (nodes), not the element itself. This preserves the parent element's tag, id, class, and other attributes — the child's `tl:define` wrapper element is discarded.
- **`_parse()` automatically caches and clones parent DOMs**: Parent templates loaded via `loader.loadSync()` go through the engine's `_parse()` which handles caching. Each call returns a clone, so the cached parent is never mutated by the merge operation.

## Testing

- **`FileSystemLoader` validates directory existence at construction**: Tests using `Trellis()` no-arg constructor need a `MapLoader({})` instead, or the test directory must exist.
- **`IOOverrides` CAN capture stderr**: `IOOverrides.runZoned(stderr: ...)` with a small `noSuchMethod`-based `Stdout` fake (`_BufferStdout`) captures writes reliably, even across async gaps.

## Themes & SSG (docs-site)

- **A fragment-root `tl:if` is NOT re-evaluated on cross-file insertion**: when a layout pulls a fragment via `tl:replace="~{base.html :: toc}"`, a `tl:if` on the *fragment's root element* does not gate the insertion — the fragment's raw `${...}`/`tl:` content can leak when its source var is absent. Guard at the **call site** instead: `<div tl:if="${page.toc}" tl:replace="~{base.html :: toc}"></div>`. (Arbor theme sidebar/TOC/prev-next all guard at the call site for this reason.)
- **A fragment inserted twice (responsive dual-render) must not carry a literal `id`**: a TOC/nav fragment rendered once for mobile and once for desktop (one CSS-hidden per breakpoint) puts two copies in the DOM. Any hard-coded `id`/`aria-labelledby` inside it becomes a duplicate id (invalid HTML, ambiguous ARIA). Name the region with `aria-label` on a `<nav>` instead of `aria-labelledby`+`id`.
- **Theme `theme:` values are joined then must be normalized**: theme resolution is `p.join(siteDir, 'themes', <value>)`. A relative `theme:` that escapes the site dir (`../../themes/arbor`) yields un-collapsed `..` through a non-existent `<siteDir>/themes`; `ThemeManifest.load` canonicalizes but the template `FileSystemLoader` does not, so the raw path fails. Fixed by `p.normalize`-ing `themeDir` at both computation sites in `trellis_site_builder.dart` before use.
- **`pathPrefix` belongs in emitted URLs, not the on-disk output layout**: deriving output file paths from the (prefixed) `page.url` nests pages under `output/<prefix>/` while sitemap/feeds/search/static stay at the root — un-deployable to a sub-path host. `stripPathPrefix` the url before deriving the file path so the whole `output/` tree publishes at the site root and the host mounts it under the prefix.
- **`layout: home` needs a `${page.content}` slot to be content-driven**: a home layout that renders only a hero + `${pages}` grid silently drops the `_index.md` markdown body. A landing that carries pitch/CTAs in its body needs the home layout to `tl:utext="${page.content}"` too.
- **Content-link prefixing must skip `<pre>`/`<code>`**: `package:markdown` escapes `<`, `>`, `&` inside code but leaves the attribute quote `"` **literal**, so a docs *code example* renders as `<code>&lt;link href="/css/main.css"&gt;</code>` — with real quotes. A naive `href="/…"` rewriter (for `pathPrefix`) then rewrites the URL the example is *teaching*, corrupting the docs. `applyPathPrefixToLinks` skips `<pre>`/`<code>` regions (a leading regex alternative consumed before the link pattern) so example URLs are never rewritten. Test with real markdown-rendered code (literal quotes), not `&quot;`-escaped strings.
- **Docs card summaries need `excerpt_length` or HTML leaks**: `page.summary` is the first *rendered* paragraph (with `<code>`/`<a>` tags) when no `excerpt_length` is set; a theme rendering it via `tl:text` then shows literal `<code>…</code>` tags in cards. Setting the standard `excerpt_length` param makes the engine strip tags and produce a plain-text, word-boundary-truncated summary. Blog themes (Verdant) rarely hit this because prose first-paragraphs lack inline markup; docs first-paragraphs are full of it.
- **`${site.menu}` section nodes order by `_index.md` `weight`** (then lexically): `NavigationBuilder` orders sibling *section* nodes by the section page's `weight`, mirroring the single-page rule — so a docs IA controls section order deliberately (no folder-naming tricks). With no section weights, the order is pure-lexical (backward-compatible).
- **Empty string is truthy in `tl:if`**: only null/false/0/'false'/'off'/'no' are falsy – bare guards pass '' (e.g. `href=""` self-links); use `${x != ''}` or emit null, not '' (truthiness.dart).
- **Theme bugs can hide behind the params bridge**: a theme built standalone (no site `theme_params`) uses its own unquoted `_variables.scss` `!default` values, while a bridged build substitutes generator-emitted values — so a generator bug (e.g. the 0.9.0 quoted-string params producing invalid `font-family:"..."` / `max-width:"1200px"` CSS that broke fonts and layout width on the live docs site) is invisible in standalone previews and in source-math checks (WCAG contrast computed from SCSS, tests asserting CSS *contains* values). The docs-site review verified contrast/structure mathematically but never visually rendered the bridged deployed output — the breakage shipped to production and was caught by a human. Preventive: any theme/SSG visual claim must be verified against a BRIDGED build's compiled CSS (assert no quoted CSS values) AND a rendered screenshot of the built output (agent-browser), not source math or standalone previews.

## Release & Publishing

- **Hotfixes still get reviewed**: fresh-context adversarial review of the fix diff BEFORE tag push, every release incl. hotfixes – the 0.9.1 SASS-quoting hotfix shipped unreviewed with 4 real issues.
- **Retiring a theme param/asset requires a multi-surface propagation sweep**: the 0.10.0 review found the syntax_highlighting retirement (ADR-010) landed in code+themes but left 8 stale spots (5 independent reviewers): the standard-params contract ("19 params" count claim), the CLI theme scaffolder templates + its test (`packages/trellis_cli/lib/src/templates/`), arbor's `theme.yaml` description, both theme-authoring doc copies (`docs/guides` + `site/content`), and `dev/architecture/`. Before closing a retirement, grep the retired symbol repo-wide – incl. `docs/`, `site/content/`, CLI templates, `themes/*/theme.yaml`, `dev/architecture/` – and check count claims ("N params") near the removal site.
