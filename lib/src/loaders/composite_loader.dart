import '../exceptions.dart';
import 'template_loader.dart';

/// Tries multiple [TemplateLoader] delegates in order.
///
/// The first delegate that successfully loads a template wins.
/// Only [TemplateNotFoundException] triggers fallback to the next delegate;
/// all other exceptions propagate immediately.
///
/// Throws [TemplateNotFoundException] when all delegates fail.
///
/// ```dart
/// final loader = CompositeLoader([
///   AssetLoader('package:my_app/templates/'),
///   FileSystemLoader('templates/'),
/// ]);
/// ```
final class CompositeLoader implements TemplateLoader {
  final List<TemplateLoader> delegates;

  CompositeLoader(this.delegates) {
    if (delegates.isEmpty) {
      throw ArgumentError('CompositeLoader requires at least one delegate');
    }
  }

  @override
  Future<String> load(String name) async {
    for (final delegate in delegates) {
      try {
        return await delegate.load(name);
      } on TemplateNotFoundException {
        continue;
      }
    }
    throw TemplateNotFoundException(name);
  }

  @override
  String? loadSync(String name) {
    for (final delegate in delegates) {
      try {
        final result = delegate.loadSync(name);
        if (result != null) return result;
        // loadSync returned null — loader doesn't support sync; try next
      } on TemplateNotFoundException {
        continue;
      }
    }
    throw TemplateNotFoundException(name);
  }
}
