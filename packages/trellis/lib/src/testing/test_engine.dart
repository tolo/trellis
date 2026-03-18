import 'package:trellis/trellis.dart';

/// Creates a [Trellis] engine configured for testing.
///
/// Uses [MapLoader] with the provided [templates] map and enables
/// [strict] mode by default. Caching is disabled for test isolation.
///
/// ```dart
/// final engine = testEngine(templates: {
///   'page': '<h1 tl:text="${title}">Default</h1>',
///   'nav': '<nav tl:fragment="main">...</nav>',
/// });
/// ```
Trellis testEngine({
  Map<String, String>? templates,
  bool strict = true,
  String prefix = 'tl',
  Map<String, Function>? filters,
  List<Processor>? processors,
  List<Dialect>? dialects,
  bool includeStandard = true,
  MessageSource? messageSource,
  String? locale,
}) {
  return Trellis(
    loader: MapLoader(templates ?? {}),
    cache: false,
    strict: strict,
    prefix: prefix,
    filters: filters,
    processors: processors,
    dialects: dialects,
    includeStandard: includeStandard,
    messageSource: messageSource,
    locale: locale,
  );
}
