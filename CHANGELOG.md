# Changelog

All notable changes to **trellis** are documented here.
This project follows [Semantic Versioning](https://semver.org/).

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
- **Framework Integration Guide**: `doc/guides/framework-integration.md` covering shelf, dart_frog, and HTMX patterns
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
