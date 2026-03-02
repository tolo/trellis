# Changelog

All notable changes to **trellis** are documented here.
This project follows [Semantic Versioning](https://semver.org/).

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)

---

## [0.2.1] — 2026-03-02

### Fixed
- **`tl:block` self-closing**: `<tl:block/>` no longer swallows subsequent siblings — normalizer now uses a quote-aware scanner instead of a regex, correctly handling `>` inside attribute values (e.g. `tl:if="${count > 0}"`)
- **`tl:fragment` on `tl:block`**: `renderFragment()` and `renderFragments()` now correctly unwrap block elements, returning inner content instead of empty output
- **`tl:each` with null/missing iterable**: gracefully removes the host element instead of throwing; consistent with lenient-mode semantics

### Added
- **`!` negation operator**: `!` is now supported as an alias for `not` in expressions (e.g. `tl:if="!${active}"`)

---

## [0.2.0] — 2026-03-01

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

---

## [0.1.0] — 2026-02-27

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

---

## 0.0.1-dev.1

- Name reservation on pub.dev
