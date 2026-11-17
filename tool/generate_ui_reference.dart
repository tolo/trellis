import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html;
import 'package:path/path.dart' as p;

import '../packages/trellis_ui/tool/src/bundle.dart';
import 'ui_gate/checks.dart' show automatedItems, manualItems;
import 'ui_gate/record.dart' show validManualResult;

const _regenerate = 'dart run tool/generate_ui_reference.dart';
const _usage = 'Usage: $_regenerate [--check] [project-root]';
const _header =
    '''
# GENERATED FILE – do not edit by hand.
# Sources: dev/ui-gate/records/ and packages/trellis_ui/ fragments and stylesheets.
# Regenerate with: $_regenerate
''';

final _componentName = RegExp(r'^[a-z][a-z0-9-]*$');
final _signature = RegExp(r'^([A-Za-z][\w-]*)(?:\(([^()]*)\))?$');
final _partClass = RegExp(r'\.(trellis-[\w-]+)');
final _comments = RegExp(r'/\*.*?\*/', dotAll: true);
const _statuses = {'pass', 'fail', 'not-run'};

final class UiReferenceException implements Exception {
  const UiReferenceException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Builds the component inventory and checks the qualified reference page set.
final class UiReferenceGenerator {
  UiReferenceGenerator(this.projectRoot);

  final String projectRoot;

  Directory get _suite => Directory(p.join(projectRoot, 'packages', 'trellis_ui'));
  File get _data => File(p.join(projectRoot, 'site', 'data', 'ui_components.yaml'));

  void write() {
    final model = _build();
    _data.parent.createSync(recursive: true);
    _data.writeAsStringSync(model.yaml);
  }

  List<String> check() {
    final model = _build();
    final pagesDir = Directory(p.join(projectRoot, 'site', 'content', 'docs', 'ui', 'components'));
    final pages = {
      if (pagesDir.existsSync())
        for (final file in pagesDir.listSync(followLinks: false).whereType<File>())
          if (p.extension(file.path) == '.md' && p.basename(file.path) != '_index.md')
            p.basenameWithoutExtension(file.path),
    };
    return [
      if (!_data.existsSync() || _data.readAsStringSync() != model.yaml)
        'site/data/ui_components.yaml is stale or missing. Regenerate with: $_regenerate',
      for (final name in model.qualified.difference(pages).toList()..sort()) 'Missing reference page: $name',
      for (final name in pages.difference(model.qualified).toList()..sort()) 'Unexpected reference page: $name',
    ];
  }

  ({String yaml, Set<String> qualified}) _build() {
    final files = sourceFiles(Directory(p.join(projectRoot, 'dev', 'ui-gate', 'records')), '.json');
    if (files.isEmpty) throw const UiReferenceException('No dev/ui-gate/records/*.json found');
    final names = files.map((file) => p.basenameWithoutExtension(file.path)).toList();
    final prefixes = [...names]..sort((a, b) => b.length.compareTo(a.length));
    final classes =
        _partClass.allMatches(bundleCss(_suite).replaceAll(_comments, '')).map((match) => match[1]!).toSet().toList()
          ..sort();
    final parts = {for (final name in names) name: <String>[]};
    for (final part in classes) {
      final hook = part.substring('trellis-'.length);
      for (final name in prefixes) {
        if (hook == name || hook.startsWith('$name-')) {
          parts[name]!.add(part);
          break;
        }
      }
    }
    final prefixedParts = parts.values.expand((parts) => parts).toSet();

    final buffer = StringBuffer(_header);
    final qualified = <String>{};
    for (final (index, file) in files.indexed) {
      final name = names[index];
      final (passes, items) = _gate(name, file);
      // Keep a release-prep failure in its gate record without publishing the component.
      if (items.skip(automatedItems.length).any((item) => item['status'] == 'fail')) continue;
      final (fragments, aliases) = _fragments(name);
      if (passes) qualified.add(name);
      final supported = passes && items.every((item) => item['status'] == 'pass');
      final partClasses = {
        ...parts[name]!,
        for (final alias in aliases)
          for (final part in classes)
            if ((part == alias || part.startsWith('$alias-')) && !prefixedParts.contains(part)) part,
      }.toList()..sort();
      buffer
        ..writeln('${jsonEncode(name)}:')
        ..writeln('  name: ${jsonEncode(name)}')
        ..writeln('  qualified: $passes')
        ..writeln('  supported: $supported')
        ..writeln('  part_classes: ${jsonEncode(partClasses)}')
        ..writeln('  fragments:');
      for (final fragment in fragments) {
        buffer.writeln('    - ${jsonEncode(fragment)}');
      }
      buffer.writeln('  items:');
      for (final item in items) {
        buffer.writeln('    - ${jsonEncode(item)}');
      }
    }
    if (buffer.length == _header.length) buffer.writeln('{}');
    return (yaml: buffer.toString(), qualified: qualified);
  }

  (bool, List<Map<String, Object>>) _gate(String name, File file) {
    final Object? root = jsonDecode(file.readAsStringSync());
    if (!_componentName.hasMatch(name) ||
        root is! Map<String, Object?> ||
        root['component'] != name ||
        !{'pass', 'fail'}.contains(root['automated']) ||
        root['items'] is! Map<String, Object?>) {
      throw UiReferenceException('$name: invalid gate record');
    }
    final entries = root['items'] as Map<String, Object?>;
    final items = <Map<String, Object>>[];
    for (final nameOfItem in [...automatedItems, ...manualItems]) {
      final raw = entries[nameOfItem];
      if (raw is! Map<String, Object?>) throw UiReferenceException('$name: missing gate item $nameOfItem');
      final status = raw['status'];
      final browsers = <Map<String, Object>>[];
      if (manualItems.contains(nameOfItem)) {
        if (!validManualResult(raw)) throw UiReferenceException('$name: invalid manual gate item $nameOfItem');
      } else {
        final results = raw['browsers'];
        if (!_statuses.contains(status) || results is! Map<String, Object?>) {
          throw UiReferenceException('$name: invalid automated gate item $nameOfItem');
        }
        for (final browser in ['chrome', 'firefox']) {
          final result = results[browser];
          if (result is! Map<String, Object?> || !_statuses.contains(result['status'])) {
            throw UiReferenceException('$name: invalid $browser result for $nameOfItem');
          }
          browsers.add({
            'name': browser,
            'status': result['status']! as String,
            if (result['unsupported'] == true) 'unsupported': true,
          });
        }
        if (status == 'pass' &&
            (!browsers.any((browser) => browser['status'] == 'pass') ||
                browsers.any(
                  (browser) =>
                      browser['status'] != 'pass' &&
                      !(browser['status'] == 'not-run' && browser['unsupported'] == true),
                ))) {
          throw UiReferenceException('$name: $nameOfItem is pass but its browser results do not pass');
        }
      }
      items.add({'name': nameOfItem, 'status': status! as String, 'browsers': browsers});
    }
    if (items.length != entries.length) throw UiReferenceException('$name: unexpected gate item');
    final passes = root['automated'] == 'pass';
    if (passes && items.take(automatedItems.length).any((item) => item['status'] != 'pass')) {
      throw UiReferenceException('$name: automated verdict is pass but an automated item did not pass');
    }
    return (passes, items);
  }

  (List<Map<String, Object>>, Set<String>) _fragments(String component) {
    final path = p.join(_suite.path, 'assets', 'fragments', '$component.html');
    final document = html.parse(File(path).readAsStringSync());
    final definitions = document.querySelectorAll(r'[tl\:fragment]');
    if (definitions.isEmpty) throw UiReferenceException('$component: no fragment definitions');
    final fragments = <Map<String, Object>>[];
    final aliases = <String>{};
    for (final definition in definitions) {
      final source = definition.attributes['tl:fragment']!.trim();
      final match = _signature.firstMatch(source);
      if (match == null) throw UiReferenceException('$component: invalid fragment signature $source');
      final name = match[1]!;
      final parameters = (match[2] ?? '').split(',').map((value) => value.trim()).where((value) => value.isNotEmpty);
      final nodes = [definition, ...definition.querySelectorAll('*')];
      final receivers = nodes.where((node) => node.attributes['tl:attrs'] == r'${attrs}').toList();
      if (receivers.isEmpty) throw UiReferenceException('$component :: $name: no attribute target');
      // Aliases such as sidebar and toastViewport can expose unprefixed component hooks.
      aliases.addAll(definition.classes.where((part) => part.startsWith('trellis-')));
      fragments.add({
        'name': name,
        'signature': source,
        'parameters': parameters.toList(),
        'slots': [
          for (final node in nodes)
            if (node.attributes['tl:slot'] case final String slot) slot.isEmpty ? 'anonymous' : slot,
        ],
        'attribute_targets': [
          for (final target in receivers)
            {'tag': '<${target.localName}>', if (target.attributes['data-slot'] case final String part) 'part': part},
        ],
      });
    }
    return (fragments, aliases);
  }
}

void main(List<String> args) {
  if (args.contains('-h') || args.contains('--help')) {
    stdout.writeln(_usage);
    return;
  }
  final positional = args.where((arg) => !arg.startsWith('-')).toList();
  if (positional.length > 1 || args.any((arg) => arg.startsWith('-') && arg != '--check')) {
    stderr.writeln(_usage);
    exitCode = 2;
    return;
  }

  final generator = UiReferenceGenerator(p.absolute(positional.isEmpty ? '.' : positional.single));
  try {
    if (args.contains('--check')) {
      final problems = generator.check();
      if (problems.isNotEmpty) throw UiReferenceException(problems.join('\n'));
      stdout.writeln('ui_reference: generated data and qualified pages are current.');
    } else {
      generator.write();
      stdout.writeln('ui_reference: generated site/data/ui_components.yaml.');
    }
  } on UiReferenceException catch (error) {
    stderr.writeln('ui_reference: FAILED – $error');
    exitCode = 1;
  } on FormatException catch (error) {
    stderr.writeln('ui_reference: FAILED – ${error.message}');
    exitCode = 1;
  } on FileSystemException catch (error) {
    stderr.writeln('ui_reference: FAILED – ${error.message}: ${error.path}');
    exitCode = 1;
  }
}
