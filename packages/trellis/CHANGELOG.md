# Changelog

## 0.13.0

### Breaking

- `tl:utext` no longer processes `tl:*` attributes in the HTML it inserts; they are output as-is, as Thymeleaf's `th:utext` does. Processing them let any HTML that reached `tl:utext` read every render-context value (`<i tl:text="${secret}">`) and include any template the loader can reach (`tl:insert`), which is server-side template injection, not only XSS. Markup that relied on it, such as raw `tl:*` HTML in `trellis_site` Markdown, now shows those attributes literally; move it into a template or shortcode. `tl:utext="_"` and an element where `tl:text` wins keep their template content, which is still processed.
- A `fragment:`/`fragments:` value with arguments in parentheses (`toast('error')`) passed to `renderFragment()`, `renderFragments()` or their file variants now throws `TemplateException` naming the bare name to pass instead, since parameters come from the render context. The value was matched against the literal `tl:fragment` attribute, so passing a definition's full value (`toast(type, title)`) also throws now. An empty `()` (`toast()`) still resolves, as the bare name.
- A same-file `tl:insert`/`tl:replace` by CSS selector (`#id`, `.class`) or tag name now copies the target as written in the template and processes the copy in the host's scope, as a by-name reference does. A target before the host was copied as already processed and then processed again, so `tl:*` attributes in HTML an earlier `tl:utext` inserted were evaluated after all (template injection). The copy now evaluates its expressions with the host's variables instead of repeating the target's output, a target removed by its own `tl:if` or `tl:remove` is still found (and removes itself again), a `tl:each` target repeats inside the host instead of yielding its first rendered item, and an `id` or `class` set by `tl:id`, `tl:attr` or `tl:class` no longer matches.
- `tl:inline` no longer evaluates text a custom processor creates: a new `Text` node that replaces template text, or markup it builds from HTML it parses itself. To keep template text inlinable, set the existing node's `data`, with template text, never a value. This follows from the `tl:inline` fix under Fixed.
- `FragmentHost.pushFragmentRegistry` takes an optional named `document` parameter, the file the registry came from. A class that implements `FragmentHost` must add it. This follows from the cross-file selector fix under Fixed.

### Added

- **Content slots, `tl:slot`** (ADR-014). Inside a `tl:fragment`, an element with `tl:slot="name"` declares a named region and a bare `tl:slot` the one anonymous region; its children are the fallback. At a `tl:insert`/`tl:replace` invocation by fragment name, a literal direct child of the host with `tl:slot="name"` fills that region: the region element stays, its children are replaced, and the marker element is dropped, as with `tl:define` (`<tl:block tl:slot="name">` adds no wrapper). Several markers for one slot concatenate in document order, and `tl:if`/`tl:unless` on a marker gate its contribution. Unmarked children (not whitespace-only text or comments) fill the anonymous slot when the fragment declares one and are discarded as before when it does not. Slot content is processed in the fragment's scope, so a region inside the fragment's `tl:each` sees the loop variable. Markers nested deeper, including inside a plain `<tl:block>`, are not looked through; on a page they are inert. To forward a slot through a fragment that invokes another, re-mark it inside a direct-child marker (`<tl:block tl:slot><p tl:slot="message">…</p></tl:block>`). These throw `TemplateException` at invocation: a marker naming a slot the fragment does not declare (including a bare marker without an anonymous slot, and any marker on a `~{file :: #id}` selector invocation), another `tl:*` attribute on a marker, a duplicate slot name, `tl:slot` on the `tl:fragment` element itself, and, inside a definition, a `tl:slot` wrapped in an inner host's unmarked content, which can neither fill the inner slot nor declare one (thrown even when the caller does not fill it or the inner invocation is gated off). A `tl:slot` outside any fragment is stripped and its content kept.
- **Attribute spreading, `tl:attrs="${map}"`** (ADR-014). Writes each map entry as an attribute, before the element's other attribute directives (shorthands, `tl:classappend`/`tl:styleappend`, `tl:attr`), which override it. Entries overwrite literal attributes, except `class` and `style`, which append. Values follow `tl:attr`: `null` removes the attribute, and a boolean attribute (`disabled`, `required`, …) renders valueless for `true` and is removed for `false`. A `null` map is a no-op. A non-`Map` value, a key not matching `^[A-Za-z][A-Za-z0-9_:.-]*$`, or a key starting with the attribute prefix (`tl:`, case-insensitive, since it would run as a directive) throws `TemplateException` before any entry is written.
- **Attribute pass-through, the `...rest` fragment parameter** (ADR-014). A fragment whose last parameter is `...name` (`field(label, name, ...attrs)`) receives under that name a map of the invoking host's attributes: its literal attributes plus the results of its own attribute directives (`tl:attrs`, `tl:attr`, shorthands, appends), evaluated once in the caller's scope, without `tl:*` control attributes. Valueless attributes arrive as `''` and render valueless again. The fragment places the map with `tl:attrs`. A `tl:insert` host keeps its directive results as well, so spreading the map repeats them there; components are invoked with `tl:replace`. A repeated, non-final or unnamed rest parameter throws `TemplateException` when the definition is collected, and so does an invocation with more positional arguments than the parameters before the rest parameter. Fragments without a rest parameter are unchanged: they ignore extra arguments, and a `tl:replace` host's attribute directives stay inert.
- **Top-level rendering of parameterised fragments.** `renderFragment()`, `renderFragments()`, `renderFileFragment()` and `renderFileFragments()` find a fragment declared with parameters (`toast(type, title)`) by its bare name (`fragment: 'toast'`), as do the Shelf, Dart Frog and Relic helpers built on them. The parameters resolve from the same-named context keys like any variable (null when absent, a throw in strict mode), and a `...rest` parameter is bound to an empty map. Previously only the literal `tl:fragment` value matched, so a bare name threw `FragmentNotFoundException`.
- **`TemplateValidator` checks for composition** (also `dart run trellis:validate`): a `tl:slot` marker under a `tl:insert`/`tl:replace` host that is not the host's literal direct child (a warning on a page, where it is inert; an error with the engine's message inside a fragment definition, unless it sits inside a direct-child marker), a repeated, non-final or unnamed `...rest` parameter (error), and a literal `id` on or inside a parameterised fragment that neither `tl:id` nor a `tl:attr` `id` binding overrides (warning, since the fragment can render several times on one page). `tl:slot` and `tl:attrs` count as known attributes, and a `tl:attrs` expression is syntax-checked.

### Fixed

- `tl:inline` now evaluates `[[…]]`/`[(…)]` only in template text, never in a text node a processor added: the output of `tl:text`, `tl:utext`, a custom processor or an earlier inline expression, on the same element or brought into a `tl:insert` host by the fragment. It ran after them, so a value such as `[[${secret}]]` read the render context (template injection). Template text is still inlined, including the text an element keeps with `tl:text="_"` or `tl:utext="_"` and a fragment's own text under a `tl:inline` host. Text a custom processor creates is no longer inlined (see Breaking).
- A self-closing `<tl:block … />` in a fragment included from another file (`~{file :: name}`) no longer swallows the elements after it. Cross-file sources skipped the self-closing normalisation that same-file templates and the validator apply.
- Inside a fragment included from another file (`~{file :: name}`), a `tl:insert`/`tl:replace` target by CSS selector (`#id`, `.class`) or tag name now resolves in that file first, as a by-name target already did, and falls back to the page only when the file has no match. It was looked up only in the page, so a component targeting its own `#z` threw `FragmentNotFoundException`, or inserted a page element with the same id. Caller content filling a slot is processed in the fragment's scope, so its selector targets also try the fragment's file first, as its by-name targets do.
- A processor with `autoProcessChildren => false` now keeps the element's children unprocessed when a later-priority processor also fires on the element (`tl:class`, `tl:attr`, `tl:remove`, or a custom one). Only the last processor's flag counted, so the later one opted the children back in.
- `tl:replace` with a fragment whose root is `<tl:block>` no longer leaves the `<tl:block>` tag in the output. It leaked in `render()`, `renderFragment()`, inside `tl:insert`ed fragments and in `tl:each` bodies, and an unknown inline element there collapses to 0×0 in the browser. The fragment clone was processed before it took the host's place, so every processor that acts on the root through its parent did nothing. `tl:replace` now puts the clone in place first, which also fixes a `tl:if`/`tl:unless` on a replaced fragment's root (a false condition rendered the root anyway, raw `tl:if` attribute included) and a root `tl:each` (threw a null-check error).
- `tl:insert` now applies a `tl:if`, `tl:unless`, `tl:each`, `tl:remove` or `tl:replace` on the fragment's root. It processed the root detached and moved only its children into the host, so a false condition or `tl:remove="all"` still inserted the children, unprocessed with their raw `tl:*` attributes, and a root `tl:each` or `tl:replace` threw. The root now acts as a `<tl:block>` that is the host's only child: a removed root leaves the host empty, and a root `tl:each` repeats the children once per item inside the host.
- `tl:remove="tag"` now processes the children it keeps, anywhere, including on a `tl:insert`ed or `tl:replace`d fragment's root. It moved them out before the engine recursed into the element, so they were output raw with their `tl:*` attributes (`<b tl:text="${x}">`). The element now unwraps after its children are processed, in its own context (a `tl:with` on it applies), as `<tl:block>` does, so a later-priority processor on the element, a custom one at `ProcessorPriority.lowest` included, now runs before it unwraps; attributes it sets go with the tag. HTML from `tl:utext` or `tl:insert` on the same element is still not processed again.
- `renderFragment()`, `renderFragments()` and their file variants now process the directives on the rendered fragment's own root as the fragment would be in place. The root was processed with no parent, so a root `tl:replace` (`<div tl:fragment="w(x)" tl:replace="leaf(${x})">`) threw `UnsupportedError`, a root `tl:each` threw a null-check error, and a root `tl:if` that is false, `tl:unless` that is true or `tl:remove="all"` returned the element with its raw `tl:*` attributes. The root now gets a temporary parent: `tl:replace` renders the target, `tl:each` one element per item (also for a parameterised root), a removed root renders nothing (`renderFragments()` concatenates the rest), and `tl:remove="tag"` or a `<tl:block>` root render their processed children.

## 0.12.0

### Changed

- Lockstep version bump to keep all Trellis SDK packages on a single shared version.
- `expectSnapshot`, `expectSnapshotFromSource` and `compareOrCreateGolden` now **fail on a missing golden file when the `CI` environment variable is `true`**, instead of creating it and passing. On CI the created file was compared against itself and then discarded with the workspace, so a deleted or never-committed golden passed unnoticed. Local runs still create missing goldens on first run. `compareOrCreateGolden` takes a new `createMissing` parameter to override the default.

## 0.11.1

### Changed

- Lockstep version bump to keep all Trellis SDK packages on a single shared version. No functional changes in this package.

## 0.11.0

### Changed

- Lockstep version bump to keep all Trellis SDK packages on a single shared version. No functional changes in this package.

## 0.10.2

### Fixed

- Dev-mode template watching now sees changes in **nested** template directories on Linux. `FileSystemLoader(devMode: true)` relied on `Directory.watch(recursive: true)`, which dart:io implements with inotify on Linux — where the `recursive` flag is silently ignored, so hot reload only ever noticed edits directly in the template root. On Linux the loader now watches each directory in the tree itself, adding watches for directories that appear later (including ones created or moved in already carrying templates) and dropping them when they go away; the per-directory walk tolerates unreadable directories, so one of them does not stop the rest of the tree from being watched. macOS and Windows keep the single native recursive watch. No API change.
- A template updated by **rename** now triggers a reload on Linux and Windows. Atomic-save tools (`sed -i`, rsync, some editors) write `page.html.tmp` and rename it over `page.html`; that arrives as a single move event whose path is the *source*, so the template-extension filter — which checked only that path — never fired. macOS reports renames as delete + create and was unaffected.
- A template directory the OS refuses to watch — most often Linux's `fs.inotify.max_user_watches` limit on a large template tree — now prints one warning naming the directory, instead of capping hot reload silently. (Per-directory watching, so Linux; macOS/Windows keep the native watch's existing error behaviour.)
- `close()` on a dev-mode `FileSystemLoader` can no longer leave a watch behind: an event arriving while it was cancelling could install a new directory watch that the shutdown had already passed by.
- `listTemplates()` no longer follows symlinks, so every name it returns is one `load()` will actually serve. It previously listed templates reached through a symlink out of the template tree, which `load()` then rejected as a boundary escape — turning up as spurious `warmUpAll()` failures. A symlink pointing back **inside** the tree is also no longer listed: its target stays listed under the real path, and `load()` still serves the alias name, but the alias itself disappears from enumeration-driven features (`warmUpAll()`, `trellis_dev`'s validator).

## 0.10.1

### Breaking

- `ProcessorContext.domProcessor` is now typed `FragmentHost` (non-nullable) instead of `dynamic`. **This is a source break for code that constructs `ProcessorContext` directly** — a `null` or duck-typed stub that compiled against 0.10.0 no longer does. Shipped as a patch deliberately: Trellis is pre-1.0 with no known external users, `ProcessorContext` is documented as something a `Processor` *receives* (never constructs), and `package:trellis/testing.dart` is the supported test path. If you do construct one, pass a `FragmentHost` implementation.

### Added

- `FragmentHost` — the narrow fragment-resolution contract (`evaluator`, `processFragmentContent`, `querySelectorFromDoc`, `lookupFragment`, `pushFragmentRegistry`, `popFragmentRegistry`) implemented by the engine's DOM processor. Declared `abstract interface class`, so future members can be added without breaking implementers.

### Changed

- Fragment-aware processors now get static checking on `context.domProcessor` rather than unchecked dynamic dispatch; the internal `as DomProcessor` cast is gone.

## 0.10.0

### Changed

- Lockstep version bump to keep all Trellis SDK packages on a single shared version. No functional changes in this package.

## 0.9.1

### Changed

- Lockstep version bump to keep all Trellis SDK packages on a single shared version. No functional changes in this package.

## 0.9.0

### Changed

- Lockstep version bump to keep all Trellis SDK packages on a single shared version. No functional changes in this package.

All notable changes to **trellis** are documented here.
This project follows [Semantic Versioning](https://semver.org/).

## [0.8.2]

### Added
- **`trellis:validate --strict` CI gate**: the `--strict` flag (alias `--fatal-warnings`) makes the CLI exit `1` on warnings, not only errors. This lets `dart run trellis:validate` gate CI on the silent HTML5-parser mutations surfaced in 0.8.1 (duplicate `tl:attr`, `<table>`/`<select>` foster-parenting) — these are reported as *warnings*, so a plain run exits `0` even when present.
- **`trellis:validate` accepts the target directory positionally** — `dart run trellis:validate templates` now works alongside `--dir templates`.

## [0.8.1]

### Fixed
- **`TemplateValidator` surfaces silent HTML5 parser mutations**: templates are parsed by `package:html` before `tl:*` processors run, and the parser can silently rewrite malformed input – dropping duplicate attributes and foster-parenting elements out of `<table>`/`<select>` – stripping `tl:*` directives with no error. The validator now reports these as warnings:
  - **Duplicate `tl:attr` on one element** – only the first is kept (HTML forbids duplicate attribute names); use a single comma-separated `tl:attr` instead.
  - **`tl:each`/`tl:*` on a `<tl:block>` (or other unknown tag) inside `<table>`/`<select>`** – foster-parented out of the table, detaching the loop scope; put the directive directly on `<tr>`/`<option>`.

## [0.8.0]

### Added
- **Expression utility objects**: `${#strings.*}`, `${#numbers.*}`, `${#dates.*}`, `${#lists.*}` — 53 built-in methods for common string, number, date, and list operations
  - `#strings`: `capitalize`, `upperCase`, `lowerCase`, `trim`, `isEmpty`, `isNotEmpty`, `length`, `contains`, `startsWith`, `endsWith`, `replace`, `substring`, `indexOf`, `split`, `join`, `repeat`
  - `#numbers`: `formatDecimal`, `formatCurrency`, `formatPercent`, `abs`, `min`, `max`, `round`, `floor`, `ceil`, `isOdd`, `isEven`
  - `#dates`: `format`, `formatDate`, `formatTime`, `now`, `year`, `month`, `day`, `hour`, `minute`, `second`, `isBefore`, `isAfter`
  - `#lists`: `size`, `isEmpty`, `isNotEmpty`, `first`, `last`, `contains`, `sort`, `sortBy`, `reverse`, `take`, `skip`, `where`, `map`, `join`, `flatten`
- `UtilityCallExpr` AST node and parser rule for `${#name.method(args)}` syntax
- `#dates.format` and `#numbers.format` use `package:intl` when available, English-only fallback otherwise
- Unknown utility object or method produces `ExpressionException` with a message listing available options
- **Testing utilities** — merged `trellis_test` into core as `package:trellis/testing.dart`:
  - `testEngine()` — preconfigured engine factory for testing with `MapLoader`, strict mode enabled, and caching disabled
  - CSS-selector HTML matchers: `hasElement`, `hasNoElement`, `hasAttribute`, `elementCount`, `hasTextContent`
  - Snapshot golden file testing: `expectSnapshot`, `expectSnapshotFromSource` — auto-creates on first run, fails with readable diff on mismatch; `TRELLIS_UPDATE_GOLDENS=true` regenerates all golden files
  - Fragment isolation helpers: `testFragment`, `testFragmentFile`
  - `normalizeHtml()` — parse-and-serialize round-trip for stable snapshot comparison

### Changed
- Added `matcher` dependency to support the merged `testing.dart` matchers

## [0.7.0]

### Added
- **Template inheritance**: `tl:extends` and `tl:define` for layout-based template composition — child templates extend parents and override named blocks
- **Contextual escaping**: URL-encoding for `@{}` expressions, `tl:href`, and `tl:src` attributes — values are properly percent-encoded for safe URL construction
- **Inheritance validation**: `TemplateValidator` recognizes `tl:extends` and `tl:define` attributes, warns on duplicate block names, validates non-empty values

### Changed
- `InheritanceResolver` runs as a pre-pass between DOM cloning and fragment collection — transparent to existing render pipeline
- `loadSync()` method on `TemplateLoader` for synchronous parent template loading (maintains sync-first contract of `render()`)

## [0.6.0]

### Added
- **Expression AST cache**: parsed expressions are now cached per `Trellis` instance and exposed via `cacheStats.expressionCacheSize`
- **Warm-up APIs**: `warmUp()` and `warmUpAll()` pre-load templates into the DOM cache with `WarmUpResult` reporting for failures and evictions
- **Template discovery**: `listTemplates()` on `FileSystemLoader` and `MapLoader` for startup warm-up workflows
- **Template validation toolkit**: `TemplateValidator`, `ValidationError`, and `ValidationSeverity` for static template checks
- **Testing helper**: `package:trellis/testing.dart` exports `isValidTemplate()` for unit-test assertions
- **CLI validator**: `dart run trellis:validate` validates template directories for CI usage

## [0.5.0]

### Added
- `devMode` parameter on `FileSystemLoader` — file watching via `dart:io` `Directory.watch()`
- `devMode` parameter on `Trellis` — automatic cache invalidation on template file changes
- `close()` on `FileSystemLoader` and `Trellis` for async resource disposal
- `FileSystemLoader.changes` stream for change notifications


## [0.4.1]

- Added logo to README


## [0.4.0]

- Bumped minimum Dart SDK from 3.7 to 3.10
- Applied Dart 3.10 dot shorthand syntax throughout `lib/src/` (zero behavioral changes)


## [0.3.0]

### Added
- **Processor interface & pipeline**: `Processor` abstract class, `ProcessorPriority` enum (8 priority slots), `ProcessorContext` class — all built-in processors implement the interface; pipeline iterates a sorted processor list
- **Custom processor registration**: `DomProcessor(processors: [...])` registers custom `Processor` instances with auto-prefixed attributes, priority-sorted merge, error wrapping, and `autoProcessChildren` control
- **Dialect system**: `Dialect` abstract class and `StandardDialect`; `DomProcessor(dialects: [...], includeStandard: false)` composes processors and filters across multiple dialects
- **Filter arguments**: `| filterName:arg1:arg2` syntax for parameterized filters; supports string (`\'` escape), int, double, bool, null, and bare identifier args; backward compatible with existing `Function(dynamic)` filters
- **i18n message expressions**: `#{key}` expression type with `MessageSource` abstract class and `MapMessageSource` implementation; parameterized messages `#{key(arg1, arg2)}` with `{0}`/`{1}` positional replacement; locale support via engine config and `_locale` context override; strict/lenient missing-key behavior
- **`AssetLoader`**: loads templates from Dart package assets via `Isolate.resolvePackageUri`
- **`CompositeLoader`**: tries delegate loaders in order, falling back on `TemplateNotFoundException`
- **`Trellis` constructor params**: `processors`, `dialects`, `includeStandard`, `messageSource`, `locale`
- **Framework Integration Guide**: `docs/guides/framework-integration.md` covering shelf, dart_frog, and HTMX patterns
- **Todo app example**: `example/todo_app/` — full Shelf + HTMX app demonstrating v0.3 features

### Changed
- `example/` restructured into `example/basic/` and `example/todo_app/` sub-packages


## [0.2.1]

### Fixed
- **`tl:block` self-closing**: `<tl:block/>` no longer swallows subsequent siblings — normalizer now uses a quote-aware scanner instead of a regex, correctly handling `>` inside attribute values (e.g. `tl:if="${count > 0}"`)
- **`tl:fragment` on `tl:block`**: `renderFragment()` and `renderFragments()` now correctly unwrap block elements, returning inner content instead of empty output
- **`tl:each` with null/missing iterable**: gracefully removes the host element instead of throwing; consistent with lenient-mode semantics

### Added
- **`!` negation operator**: `!` is now supported as an alias for `not` in expressions (e.g. `tl:if="!${active}"`)


## [0.2.0]

### Added
- **Expression enhancements**: arithmetic operators (`+ - * / %`), literal substitution (`|Hello, ${name}!|`), dynamic index expressions (`${list[index]}`), selection expressions (`*{field}` with `tl:object`), comparison aliases (`gt`, `lt`, `ge`, `le`, `eq`, `ne`), no-op token (`_`)
- **`tl:switch` / `tl:case`**: multi-branch conditional rendering
- **`tl:classappend` / `tl:styleappend`**: append to existing class/style attributes
- **`tl:block`**: virtual element that renders only its children (no host element in output)
- **`tl:remove`**: remove elements or content from output (`all`, `body`, `tag`, `all-but-first`, `none`)
- **`tl:inline`**: inline expression processing in text, JavaScript, and CSS contexts (`[[${expr}]]` escaped, `[(${expr})]` unescaped)
- **`tl:object` / `*{}`**: object context and selection expressions for scoped field access; auto-conversion via `toMap()`/`toJson()`
- **Parameterized fragments**: `tl:fragment="card(title, body)"` with argument passing at inclusion time
- **CSS selector targeting**: `tl:insert="~{file :: #id}"` and `tl:insert="~{file :: .class}"`
- **Cycle detection**: fragment inclusion stack replaces depth-only guard — recursive inclusions detected immediately
- **`renderFragments()`**: render multiple named fragments from a single template string in one call
- **`renderFileFragments()`**: async variant loading from the filesystem
- **Strict mode**: `Trellis(strict: true)` — undefined variables, members, and keys throw `ExpressionException`
- **LRU cache**: configurable max cache size via `maxCacheSize` parameter; evicts least-recently-used entries
- **`CacheStats`**: expose cache hit/miss/size metrics via `engine.cacheStats`
- **`clearCache()`**: clear DOM cache and reset statistics
- **`TrellisContext`**: fluent builder for constructing rendering context maps
- **`data-tl-*` prefix mode**: `Trellis(prefix: 'data-tl')` for strict HTML5-valid attribute names

### Fixed
- Expression parser: alias/keyword words (`gt`, `eq`, `and`, `true`, etc.) now work as member names after `.` — e.g. `${obj.eq}`, `${stats.gt}`
- README: corrected `TrellisContext` example, `renderFragments` return types, `tl:switch` case syntax, `tl:classappend` ternary, `maxCacheSize` default, removed nonexistent `separator` parameter

### Changed
- Fragment registry entries now carry parameter names for parameterized fragment resolution
- Inclusion depth guard replaced by cycle detection stack (still enforces max depth 32 as hard limit)


## [0.1.0]

### Added
- Core template engine with 15 `tl:*` attributes for natural HTML templating
- Text substitution: `tl:text` (escaped) and `tl:utext` (unescaped HTML)
- Conditionals: `tl:if` and `tl:unless`
- Iteration: `tl:each` with status variables (index, count, size, first, last, odd, even, current)
- Fragment system: `tl:fragment`, `tl:insert`, `tl:replace` with cross-file inclusion
- Local variable binding: `tl:with`
- Attribute setting: `tl:attr`, `tl:href`, `tl:src`, `tl:value`, `tl:class`, `tl:id`
- Expression evaluator: `${var}` variables, `@{/url}` URL expressions, string literals, ternary, Elvis, comparisons, boolean operators
- Four public API methods: `render()`, `renderFile()`, `renderFragment()`, `renderFileFragment()`
- DOM caching with deep-clone for performance
- Configurable attribute prefix (default `tl`)
- `FileSystemLoader` with security boundary enforcement (path traversal, symlink escape protection)
- `MapLoader` for in-memory templates and testing
- Typed exception hierarchy: `TemplateException`, `ExpressionException`, `FragmentNotFoundException`, `TemplateNotFoundException`, `TemplateSecurityException`
