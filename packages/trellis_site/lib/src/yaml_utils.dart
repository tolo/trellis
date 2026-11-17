import 'package:yaml/yaml.dart';

/// Recursively converts a [YamlMap] to a [Map<String, dynamic>].
Map<String, dynamic> convertYamlMap(YamlMap map) {
  return {for (final entry in map.entries) entry.key.toString(): convertYaml(entry.value)};
}

/// Recursively converts YAML values to plain Dart types.
///
/// [YamlMap] → [Map<String, dynamic>], [YamlList] → [List<dynamic>],
/// all other values passed through unchanged.
dynamic convertYaml(dynamic value) {
  if (value is YamlMap) return convertYamlMap(value);
  if (value is YamlList) return [for (final item in value) convertYaml(item)];
  return value;
}

final _sourceName = RegExp(r'^[a-z][a-z0-9_]*$');

List<String> parseSourceNames(YamlMap yaml, Exception Function(String) error) {
  if (!yaml.containsKey('uses')) return const [];
  final value = yaml['uses'];
  if (value is YamlList && value.every((name) => name is String && _sourceName.stringMatch(name) == name)) {
    return List<String>.unmodifiable(value);
  }
  throw error("'uses:' must be a list of source names matching [a-z][a-z0-9_]*");
}
