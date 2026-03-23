import 'dart:io';

/// Targeted updates to `trellis_site.yaml` for theme configuration.
///
/// Uses line-based string manipulation rather than full YAML round-trip
/// to preserve user comments and formatting.
class ThemeConfigUpdater {
  /// The path to the `trellis_site.yaml` file.
  final String configPath;

  ThemeConfigUpdater(this.configPath);

  /// Sets `theme: <name>` in the config file.
  ///
  /// If a `theme:` line exists, replaces it. Otherwise, appends it.
  /// Also sets `theme_ref: <ref>` if [ref] is provided.
  void setTheme(String name, {String? ref}) {
    final file = File(configPath);
    var content = file.readAsStringSync();

    content = _setOrAppendKey(content, 'theme', name);
    if (ref != null) {
      content = _setOrAppendKey(content, 'theme_ref', ref);
    }

    file.writeAsStringSync(content);
  }

  /// Clears `theme:` and `theme_ref:` from the config file.
  ///
  /// Does NOT remove `theme_params:` — that is user-managed.
  void clearTheme() {
    final file = File(configPath);
    var content = file.readAsStringSync();

    content = _removeKey(content, 'theme');
    content = _removeKey(content, 'theme_ref');

    file.writeAsStringSync(content);
  }

  /// Sets or appends a top-level YAML key with the given [value].
  ///
  /// If a line matching `key: ...` exists, replaces it in-place.
  /// Otherwise appends `key: value` at the end of the file.
  String _setOrAppendKey(String content, String key, String value) {
    final pattern = RegExp('^$key:.*\$', multiLine: true);
    if (pattern.hasMatch(content)) {
      return content.replaceFirst(pattern, '$key: $value');
    }
    // Append at end, ensuring there's a newline before
    final trailing = content.endsWith('\n') ? '' : '\n';
    return '$content$trailing$key: $value\n';
  }

  /// Removes the top-level YAML key line matching `key: ...`.
  String _removeKey(String content, String key) {
    final pattern = RegExp('^$key:.*\n?', multiLine: true);
    return content.replaceFirst(pattern, '');
  }
}
