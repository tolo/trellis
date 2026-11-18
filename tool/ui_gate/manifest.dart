import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html;
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// A validated, component-independent gate recipe.
final class GateManifest {
  GateManifest._(this.file, this.data);
  final File file;
  final Map<String, Object?> data;
  String get name => data['name'] as String? ?? p.basenameWithoutExtension(file.path);
  String get page => data['page']! as String;
  String get root => data['root']! as String;
  Map<String, Object?> get states =>
      (data['states'] as Map?)?.cast<String, Object?>() ?? const {'default': <Object?>[]};
  Map<String, String> get elements => (data['elements'] as Map?)?.cast<String, String>() ?? {'root': root};
  List<Map<String, Object?>> steps(Object? raw) =>
      (raw as List? ?? const []).map((e) => (e as Map).cast<String, Object?>()).toList();
  List<Map<String, Object?>> get keyboard => steps(data['keyboard']);
  Map<String, Object?>? get htmx => (data['htmx'] as Map?)?.cast<String, Object?>();
  String resolveFile(String name) => p.normalize(p.join(file.parent.path, name));

  /// Parses unknown keys and selectors before starting either browser.
  static GateManifest load(File file) {
    final value = loadYaml(file.readAsStringSync());
    if (value is! Map) throw const FormatException('manifest: expected a mapping');
    final data = _plain(value) as Map<String, Object?>;
    _keys(data, {
      'name',
      'page',
      'root',
      'elements',
      'states',
      'keyboard',
      'semantics',
      'htmx',
      'instances',
      'distinct',
      'provenance',
      'axe',
    }, 'manifest');
    for (final field in ['page', 'root']) {
      if (data[field] is! String || (data[field] as String).isEmpty)
        throw FormatException('$field: required nonempty string');
    }
    if (!(data['page'] as String).startsWith('/') || (data['page'] as String).startsWith('//'))
      throw const FormatException('page: expected same-origin absolute path');
    _selector(data['root'], 'root');
    for (final entry in ((data['elements'] as Map?) ?? const {}).entries) {
      _selector(entry.value, 'elements.${entry.key}');
    }
    void steps(Object? raw, String field) {
      if (raw is! List) throw FormatException('$field: expected a step list');
      for (var i = 0; i < raw.length; i++) {
        final step = raw[i];
        if (step is! Map || step.length != 1) throw FormatException('$field[$i]: expected one step');
        final key = step.keys.single;
        if (!{'focus', 'click', 'hover', 'type', 'press', 'wait', 'expect', 'axe', 'state', 'eval'}.contains(key))
          throw FormatException('$field[$i].$key: unknown step');
        if ({'focus', 'click', 'hover'}.contains(key)) _selector(step[key], '$field[$i].$key');
        if (key == 'expect') {
          if (step[key] is! Map) throw FormatException('$field[$i].expect: expected expression/equals');
          _keys((step[key] as Map).cast<String, Object?>(), {'expression', 'equals'}, '$field[$i].expect');
          if ((step[key] as Map)['expression'] is! String || !(step[key] as Map).containsKey('equals'))
            throw FormatException('$field[$i].expect: expected expression/equals');
        }
      }
    }

    if (data['keyboard'] != null) steps(data['keyboard'], 'keyboard');
    if (data['states'] != null) {
      for (final entry in (data['states'] as Map).entries) {
        steps(entry.value, 'states.${entry.key}');
      }
    }
    for (final raw in data['semantics'] as List? ?? const []) {
      final assertion = (raw as Map).cast<String, Object?>();
      _keys(assertion, {'selector', 'attribute', 'equals', 'expression'}, 'semantics');
      if (assertion['selector'] != null) _selector(assertion['selector'], 'semantics.selector');
      if (!assertion.containsKey('equals')) throw const FormatException('semantics.equals: required');
    }
    for (final raw in data['provenance'] as List? ?? const []) {
      final notice = (raw as Map).cast<String, Object?>();
      _keys(notice, {'file', 'license'}, 'provenance');
      if (notice['file'] is! String || notice['license'] is! String)
        throw const FormatException('provenance: file/license required');
    }
    for (final selector in data['instances'] as List? ?? const []) {
      _selector(selector, 'instances');
    }
    for (final group in data['distinct'] as List? ?? const []) {
      if (group is! List || group.length < 2) throw const FormatException('distinct: at least two selectors required');
      for (final selector in group) {
        _selector(selector, 'distinct');
      }
    }
    final htmx = (data['htmx'] as Map?)?.cast<String, Object?>();
    if (htmx != null) {
      _keys(htmx, {'region', 'swap', 'navigate', 'transient', 'probe'}, 'htmx');
      _selector(htmx['region'], 'htmx.region');
      steps(htmx['swap'], 'htmx.swap');
      steps(htmx['navigate'], 'htmx.navigate');
      if (htmx['transient'] != null) _selector(htmx['transient'], 'htmx.transient');
      if (htmx['probe'] != null) {
        final probe = (htmx['probe'] as Map).cast<String, Object?>();
        _keys(probe, {'steps', 'expression', 'equals'}, 'htmx.probe');
        steps(probe['steps'], 'htmx.probe.steps');
      }
    }
    final axe = (data['axe'] as Map?)?.cast<String, Object?>();
    if (axe != null) {
      _keys(axe, {'disable'}, 'axe');
      for (final entry in ((axe['disable'] as Map?) ?? const {}).entries) {
        if (entry.value is! String || (entry.value as String).trim().isEmpty)
          throw FormatException('axe.disable.${entry.key}: a reason is required');
      }
    }
    return GateManifest._(file, data);
  }

  /// Missing pages and invalid root selectors fail before a browser launches.
  Future<String> validatePage(Uri base) async {
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(base.resolve(page))).close();
      if (response.statusCode != 200) throw FormatException('page: $page returned ${response.statusCode}');
      final source = await utf8.decodeStream(response);
      if (html.parse(source).querySelector(root) == null) throw FormatException('root: $root not found in $page');
      return source;
    } finally {
      client.close(force: true);
    }
  }
}

Object? _plain(Object? value) => switch (value) {
  Map map => <String, Object?>{for (final entry in map.entries) entry.key as String: _plain(entry.value)},
  List list => list.map(_plain).toList(),
  _ => value,
};

void _keys(Map<String, Object?> map, Set<String> allowed, String field) {
  for (final key in map.keys) {
    if (!allowed.contains(key)) throw FormatException('$field.$key: unknown key');
  }
}

void _selector(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) throw FormatException('$field: nonempty selector required');
  try {
    html.parse('<main></main>').querySelector(value);
  } on Object catch (error) {
    throw FormatException('$field: invalid selector $value ($error)');
  }
}
