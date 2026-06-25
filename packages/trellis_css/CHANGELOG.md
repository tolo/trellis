# Changelog

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
