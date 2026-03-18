import 'package:trellis/trellis.dart';

/// Renders a specific fragment from an in-memory template.
///
/// Convenience wrapper around [Trellis.renderFragment] for test code.
/// The [template] parameter is a template name (key in MapLoader),
/// not a raw source string. The source is loaded via `engine.loader.loadSync()`.
///
/// ```dart
/// final html = testFragment(engine, 'nav', 'mainNav', {
///   'items': [{'url': '/home', 'label': 'Home'}],
/// });
/// expect(html, hasElement('a'));
/// ```
///
/// Throws [TemplateNotFoundException] if [template] is not in the engine's loader.
/// Throws [FragmentNotFoundException] if [fragment] is not found in the template.
String testFragment(Trellis engine, String template, String fragment, Map<String, dynamic> context) {
  final source = engine.loader.loadSync(template);
  if (source == null) {
    throw TemplateNotFoundException(template);
  }
  return engine.renderFragment(source, fragment: fragment, context: context);
}

/// Async version for file-based templates.
///
/// Uses [Trellis.renderFileFragment] for templates loaded from disk.
///
/// ```dart
/// final html = await testFragmentFile(engine, 'partials/nav', 'mainNav', {
///   'items': [{'url': '/home', 'label': 'Home'}],
/// });
/// expect(html, hasElement('a'));
/// ```
Future<String> testFragmentFile(Trellis engine, String templateName, String fragment, Map<String, dynamic> context) {
  return engine.renderFileFragment(templateName, fragment: fragment, context: context);
}
