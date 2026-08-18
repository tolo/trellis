# Changelog

## 0.10.2

### Fixed

- Dev-mode template watching now sees changes in **nested** template directories on Linux. `FileSystemLoader(devMode: true)` relied on `Directory.watch(recursive: true)`, which dart:io implements with inotify on Linux — where the `recursive` flag is silently ignored, so hot reload only ever noticed edits directly in the template root. On Linux the loader now watches each directory in the tree itself, adding watches for directories that appear later (including ones created or moved in already carrying templates) and dropping them when they go away. macOS and Windows keep the single native recursive watch. No API change.
- A template directory the OS refuses to watch — most often Linux's `fs.inotify.max_user_watches` limit on a large template tree — now prints one warning naming the directory, instead of capping hot reload silently. A directory that is merely unreadable no longer stops the rest of the tree from being watched.
- `close()` on a dev-mode `FileSystemLoader` can no longer leave a watch behind: an event arriving while it was cancelling could install a new directory watch that the shutdown had already passed by.
- `listTemplates()` no longer follows symlinks, so every name it returns is one `load()` will actually serve. It previously listed templates reached through a symlink out of the template tree, which `load()` then rejected as a boundary escape — turning up as spurious failures from `warmUpAll()` and in `trellis_dev`'s validator. A symlink pointing back inside the tree only duplicated a template already listed under its real path.

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
