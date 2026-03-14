import '../exceptions.dart';
import 'template_loader.dart';

/// In-memory template loader for testing. Templates keyed by name.
final class MapLoader implements TemplateLoader {
  final Map<String, String> templates;

  MapLoader(this.templates);

  @override
  Future<String> load(String name) async {
    final source = templates[name];
    if (source == null) {
      throw TemplateNotFoundException(name);
    }
    return source;
  }

  @override
  String? loadSync(String name) {
    final source = templates[name];
    if (source == null) {
      throw TemplateNotFoundException(name);
    }
    return source;
  }

  /// Return all template names stored in this loader.
  List<String> listTemplates() => templates.keys.toList();
}
