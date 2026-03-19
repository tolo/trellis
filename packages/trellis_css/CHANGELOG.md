# Changelog

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
