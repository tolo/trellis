/// A Thymeleaf-inspired HTML template engine for Dart.
///
/// Natural HTML templates with `tl:*` attributes.
/// Fragment-first design for HTMX partial rendering.
library;

export 'src/cache_stats.dart';
export 'src/context_builder.dart';
export 'src/engine.dart';
export 'src/evaluator.dart' show ExpressionEvaluator;
export 'src/exceptions.dart';
export 'src/loaders/template_loader.dart';
export 'src/loaders/file_loader.dart';
export 'src/loaders/map_loader.dart';
