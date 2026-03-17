/// CSS utilities for the Trellis template engine.
///
/// Provides:
/// - [TrellisCss] for Dart-native SASS/SCSS compilation
/// - [CssDialect] and [ScopeProcessor] for `tl:scope` fragment-scoped CSS
///
/// ## SASS compilation
///
/// ```dart
/// import 'package:trellis_css/trellis_css.dart';
///
/// final css = TrellisCss.compileSass('styles/main.scss');
/// final css2 = TrellisCss.compileSassString('.btn { color: blue; }');
/// ```
///
/// ## Fragment-scoped CSS
///
/// ```dart
/// import 'package:trellis/trellis.dart';
/// import 'package:trellis_css/trellis_css.dart';
///
/// final engine = Trellis(dialects: [CssDialect()]);
/// ```
library;

export 'src/css_dialect.dart' show CssDialect;
export 'src/output_style.dart' show OutputStyle;
export 'src/sass_compilation_exception.dart' show SassCompilationException;
export 'src/scope_processor.dart' show ScopeProcessor, OrphanScopeProcessor;
export 'src/syntax.dart' show Syntax;
export 'src/trellis_css.dart' show TrellisCss;
