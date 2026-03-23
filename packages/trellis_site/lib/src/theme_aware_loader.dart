import 'package:trellis/trellis.dart';

/// A [TemplateLoader] that supports theme-aware template resolution.
///
/// Intercepts the `theme:` prefix in template names to load directly
/// from the theme directory, bypassing the site-first resolution.
/// For unprefixed names, delegates to an inner loader that resolves
/// site templates first, then falls back to theme templates.
///
/// Example:
/// ```dart
/// // In a themed site, layouts/base.html resolves site-first, then theme.
/// // theme:layouts/base.html always loads from the theme directory directly.
/// final loader = ThemeAwareLoader.forTheme(
///   siteDir: '/path/to/site',
///   themeDir: '/path/to/site/themes/verdant',
/// );
/// ```
///
/// If no theme is active, the `theme:` prefix produces a clear [TemplateException].
class ThemeAwareLoader implements TemplateLoader {
  /// The inner loader chain (site-first composite, or site-only when no theme).
  final TemplateLoader _inner;

  /// The theme-only loader for `theme:` prefix resolution.
  ///
  /// Null when no theme is active.
  final TemplateLoader? _themeLoader;

  static const _themePrefix = 'theme:';

  /// Creates a [ThemeAwareLoader] with the given inner and theme loaders.
  ///
  /// [inner] is the composite loader for normal resolution (site-first, theme-fallback).
  /// [themeLoader] is the theme-only loader for `theme:` prefix resolution.
  /// When [themeLoader] is null, the `theme:` prefix produces a [TemplateException].
  ThemeAwareLoader({required TemplateLoader inner, TemplateLoader? themeLoader})
    : _inner = inner,
      _themeLoader = themeLoader;

  /// Creates a [ThemeAwareLoader] for a themed site.
  ///
  /// Constructs a [CompositeLoader] with site-first, theme-fallback ordering
  /// for unprefixed names, and a separate theme-only loader for `theme:` prefix
  /// resolution.
  ///
  /// Both [siteDir] and [themeDir] must exist when this factory is called.
  factory ThemeAwareLoader.forTheme({required String siteDir, required String themeDir}) {
    final siteLoader = FileSystemLoader(siteDir);
    final themeLoader = FileSystemLoader(themeDir);
    final composite = CompositeLoader([siteLoader, themeLoader]);
    return ThemeAwareLoader(inner: composite, themeLoader: themeLoader);
  }

  /// Creates a [ThemeAwareLoader] for a non-themed site (pass-through).
  ///
  /// All template names are resolved via a [FileSystemLoader] rooted at [siteDir].
  /// The `theme:` prefix is not available and will throw [TemplateException].
  factory ThemeAwareLoader.noTheme({required String siteDir}) {
    final siteLoader = FileSystemLoader(siteDir);
    return ThemeAwareLoader(inner: siteLoader);
  }

  @override
  Future<String> load(String name) {
    if (name.startsWith(_themePrefix)) {
      return _loadFromTheme(name);
    }
    return _inner.load(name);
  }

  @override
  String? loadSync(String name) {
    if (name.startsWith(_themePrefix)) {
      return _loadSyncFromTheme(name);
    }
    return _inner.loadSync(name);
  }

  Future<String> _loadFromTheme(String name) {
    if (_themeLoader == null) {
      return Future.error(
        TemplateException(
          "'theme:' prefix requires an active theme. "
          'No theme is configured in trellis_site.yaml.',
        ),
      );
    }
    final unprefixed = name.substring(_themePrefix.length);
    return _themeLoader.load(unprefixed);
  }

  String? _loadSyncFromTheme(String name) {
    if (_themeLoader == null) {
      throw TemplateException(
        "'theme:' prefix requires an active theme. "
        'No theme is configured in trellis_site.yaml.',
      );
    }
    final unprefixed = name.substring(_themePrefix.length);
    return _themeLoader.loadSync(unprefixed);
  }
}
