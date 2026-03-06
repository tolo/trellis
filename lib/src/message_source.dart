/// Pluggable message source for `#{key}` expressions [D08].
abstract class MessageSource {
  /// Resolve a message key, optionally with locale and positional arguments.
  /// Returns null if the key is not found.
  String? resolve(String key, {String? locale, List<dynamic> args});
}

/// Map-based message source implementation.
///
/// Structure: `{'en': {'greeting': 'Hello, {0}!'}, 'fr': {'greeting': 'Bonjour, {0}!'}}`
///
/// Keys are flat strings — dots are part of the key name (`greeting.formal`
/// is one key, not nested access) [D08].
class MapMessageSource implements MessageSource {
  final Map<String, Map<String, String>> _messages;

  MapMessageSource({required Map<String, Map<String, String>> messages})
      : _messages = messages;

  @override
  String? resolve(String key, {String? locale, List<dynamic> args = const []}) {
    // Try exact locale
    final localeMessages = locale != null ? _messages[locale] : null;
    String? template = localeMessages?[key];

    // If no locale match, try first available locale (fallback)
    if (template == null && _messages.isNotEmpty) {
      for (final messages in _messages.values) {
        template = messages[key];
        if (template != null) break;
      }
    }

    if (template == null) return null;

    return _applyArgs(template, args);
  }

  /// Replace `{0}`, `{1}`, ... placeholders with positional args.
  /// Not expression evaluation — pure string replacement (no injection risk).
  static String _applyArgs(String template, List<dynamic> args) {
    var result = template;
    for (var i = 0; i < args.length; i++) {
      result = result.replaceAll('{$i}', args[i]?.toString() ?? '');
    }
    return result;
  }
}
