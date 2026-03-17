import 'package:sass/sass.dart' as sass;

import 'output_style.dart';
import 'sass_compilation_exception.dart';
import 'syntax.dart';

/// Dart-native CSS processing for the Trellis template engine.
///
/// Provides SASS/SCSS compilation via `package:sass` — the canonical SASS
/// implementation written in Dart. No npm or Node.js required.
///
/// ## Compile a file
///
/// ```dart
/// final css = TrellisCss.compileSass('styles/main.scss');
/// ```
///
/// ## Compile a string
///
/// ```dart
/// const source = r'''
/// $primary: #3498db;
/// .container { color: $primary; }
/// ''';
/// final css = TrellisCss.compileSassString(source);
/// ```
class TrellisCss {
  TrellisCss._();

  /// Compiles a SASS/SCSS file at [path] to CSS.
  ///
  /// [outputStyle] controls CSS formatting: [OutputStyle.expanded] (default)
  /// for human-readable output, [OutputStyle.compressed] for minified.
  ///
  /// [loadPaths] specifies directories to search when resolving
  /// `@use` and `@import` rules.
  ///
  /// Throws [SassCompilationException] if compilation fails (syntax error,
  /// missing file, unresolved import, etc.).
  static String compileSass(
    String path, {
    OutputStyle outputStyle = OutputStyle.expanded,
    List<String> loadPaths = const [],
  }) {
    try {
      final result = sass.compileToResult(path, style: _mapOutputStyle(outputStyle), loadPaths: loadPaths);
      return result.css;
    } on Object catch (e) {
      throw SassCompilationException.fromSassException(e);
    }
  }

  /// Compiles SASS/SCSS source code from a [source] string to CSS.
  ///
  /// [syntax] specifies the input syntax: [Syntax.scss] (default, curly-brace)
  /// or [Syntax.sass] (indented, without curly braces).
  ///
  /// [outputStyle] controls CSS formatting.
  ///
  /// [loadPaths] specifies directories to search when resolving
  /// `@use` and `@import` rules.
  ///
  /// Throws [SassCompilationException] if compilation fails.
  static String compileSassString(
    String source, {
    OutputStyle outputStyle = OutputStyle.expanded,
    Syntax syntax = Syntax.scss,
    List<String> loadPaths = const [],
  }) {
    try {
      final result = sass.compileStringToResult(
        source,
        syntax: _mapSyntax(syntax),
        style: _mapOutputStyle(outputStyle),
        loadPaths: loadPaths,
      );
      return result.css;
    } on Object catch (e) {
      throw SassCompilationException.fromSassException(e);
    }
  }

  static sass.OutputStyle _mapOutputStyle(OutputStyle style) {
    return switch (style) {
      OutputStyle.expanded => sass.OutputStyle.expanded,
      OutputStyle.compressed => sass.OutputStyle.compressed,
    };
  }

  static sass.Syntax _mapSyntax(Syntax syntax) {
    return switch (syntax) {
      Syntax.scss => sass.Syntax.scss,
      // package:sass uses Syntax.sass for .sass indented syntax files
      Syntax.sass => sass.Syntax.sass,
    };
  }
}
