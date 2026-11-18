import 'package:trellis/trellis.dart';

/// Templates and static assets contributed by a named site source.
///
/// Site and theme templates take precedence. The loader must implement
/// [TemplateLoader.loadSync] for cross-file fragments.
///
/// Asset keys are output-relative POSIX paths. Sources cannot share a path or
/// use another asset file as a directory.
/// Theme static files overwrite source assets, and site static files win last.
final class SiteSource {
  final TemplateLoader loader;
  final Map<String, List<int>> assets;

  const SiteSource({required this.loader, this.assets = const {}});
}
