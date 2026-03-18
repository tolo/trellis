# Changelog

## 0.1.0

- `TrellisCss.compileSass()` — file-based SASS/SCSS compilation via `package:sass`
- `TrellisCss.compileSassString()` — string-based SASS/SCSS compilation
- `OutputStyle` enum — `expanded` (default) and `compressed` output styles
- `Syntax` enum — `scss` (default) and `sass` (indented) input syntax
- `SassCompilationException` — structured compilation error with file path, line, and column info
- `CssDialect` and `ScopeProcessor` — `tl:scope` fragment-scoped CSS via CSS `@scope`
