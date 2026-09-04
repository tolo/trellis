# Changelog

## 0.11.1

### Fixed

- README install snippet pinned `trellis_css: ^0.1.0`, a range no published version of the package
  matches, so a copied snippet failed `dart pub get`. It now tracks the lockstep version and
  `tool/version_lockstep.sh` keeps it current.

## 0.11.0

### Changed

- Lockstep version bump to keep all Trellis SDK packages on a single shared version. No functional changes in this package.

## 0.10.2

### Changed

- Lockstep version bump to keep all Trellis SDK packages on a single shared version. No functional changes in this package.

## 0.10.1

### Changed

- Lockstep version bump to keep all Trellis SDK packages on a single shared version. No functional changes in this package.

## 0.10.0

### Added

- `TrellisCss.compileSass` gains a `silenceImportDeprecation` flag. When set, Dart Sass's `@import`-rule deprecation warning is suppressed for that compile — for callers that deliberately rely on `@import` (the SDK theme bridge; see TD-006) — while the default still surfaces the warning for other consumers.

## 0.9.1

### Changed

- Lockstep version bump to keep all Trellis SDK packages on a single shared version. No functional changes in this package.

## 0.9.0

### Changed

- Lockstep version bump to keep all Trellis SDK packages on a single shared version. No functional changes in this package.

## 0.8.2

### Changed

- Lockstep version bump to keep all Trellis SDK packages on a single shared version. No functional changes in this package.

## 0.8.1

### Changed

- Lockstep version bump to keep all Trellis SDK packages on a single shared version. No functional changes in this package.

## 0.8.0

### Changed

- Version aligned to the unified Trellis SDK lockstep versioning scheme — all SDK packages now share a single version number and are released together. No functional changes since 0.1.0.

## 0.1.0

### Added

- `TrellisCss.compileSass()` for file-based SASS and SCSS compilation.
- `TrellisCss.compileSassString()` for compiling inline SASS and SCSS source.
- `OutputStyle` with `expanded` and `compressed` output modes.
- `Syntax` with `scss` and indented `sass` parsing modes.
- `SassCompilationException` with file path, line, and column information for failed compilations.

### Trellis Integration

- `CssDialect` for registering CSS-focused processors with a Trellis engine.
- `ScopeProcessor` and `OrphanScopeProcessor` for `tl:scope` fragment-scoped CSS using native `@scope` output.
