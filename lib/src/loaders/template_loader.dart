/// Abstract interface for loading template sources by name.
abstract class TemplateLoader {
  /// Load a template asynchronously.
  Future<String> load(String name);

  /// Load a template synchronously, if supported.
  /// Returns null only when sync loading is unsupported by the loader.
  /// Implementations that support sync loading should throw
  /// [TemplateNotFoundException]-compatible errors when a template is missing.
  String? loadSync(String name);
}
