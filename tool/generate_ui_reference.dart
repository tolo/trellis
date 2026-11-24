import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html;
import 'package:path/path.dart' as p;

import '../packages/trellis_ui/tool/src/bundle.dart';
import 'ui_gate/record.dart';
import 'ui_gate/release_policy.dart';

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
    final policy = ComponentReleasePolicy.read(Directory(projectRoot));
    final files = sourceFiles(Directory(p.join(projectRoot, 'dev', 'ui-gate', 'records')), '.json');
    if (files.isEmpty) throw const UiReferenceException('No dev/ui-gate/records/*.json found');
    final names = files.map((file) => p.basenameWithoutExtension(file.path)).toList();
    final missingEvidence = releaseComponents.where((name) => policy.isWithdrawn(name) && !names.contains(name));
    if (missingEvidence.isNotEmpty) {
      throw UiReferenceException('Missing gate evidence for withdrawn components: ${missingEvidence.join(', ')}');
    }
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
      if (!_componentName.hasMatch(name)) throw UiReferenceException('$name: invalid component name');
      final record = GateRecordAssessment.inspect(name, jsonDecode(file.readAsStringSync()));
      final problems = policy.withdrawalIssues(record);
      if (problems.isNotEmpty) throw UiReferenceException(problems.join('\n'));
      if (policy.isRemoved(name)) continue;
      if (record.invalid.isNotEmpty) throw UiReferenceException(record.invalid.join('\n'));
      if (record.declaredVerdict == 'pass' && !record.qualified) {
        throw UiReferenceException('$name: inconsistent automated verdict');
      }
      // Manual failures stay in the gate record. Automated failures can appear as internal diagnostics.
      if (record.manual.containsValue('fail')) continue;
      final (fragments, aliases) = _fragments(name);
      if (record.qualified) qualified.add(name);
      final partClasses = {
        ...parts[name]!,
        for (final alias in aliases)
          for (final part in classes)
            if ((part == alias || part.startsWith('$alias-')) && !prefixedParts.contains(part)) part,
      }.toList()..sort();
      buffer
        ..writeln('${jsonEncode(name)}:')
        ..writeln('  name: ${jsonEncode(name)}')
        ..writeln('  qualified: ${record.qualified}')
        ..writeln('  supported: ${record.supported}')
        ..writeln('  part_classes: ${jsonEncode(partClasses)}')
        ..writeln('  fragments:');
      for (final fragment in fragments) {
        buffer.writeln('    - ${jsonEncode(fragment)}');
      }
      buffer.writeln('  items:');
      for (final item in record.automated.entries) {
        buffer.writeln(
          '    - ${jsonEncode({
            'name': item.key,
            'status': item.value.status,
            'browsers': [
              for (final browser in item.value.browsers.entries) {'name': browser.key, 'status': browser.value.status, if (browser.value.unsupported) 'unsupported': true},
            ],
          })}',
        );
      }
      for (final item in record.manual.entries) {
        buffer.writeln('    - ${jsonEncode({'name': item.key, 'status': item.value, 'browsers': []})}');
      }
    }
    if (buffer.length == _header.length) buffer.writeln('{}');
    return (yaml: buffer.toString(), qualified: qualified);
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
      final parameters = (match[2] ?? '')
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
      final nodes = [definition, ...definition.querySelectorAll('*')];
      final receivers = nodes.where((node) => node.attributes['tl:attrs'] == r'${attrs}').toList();
      if (parameters.contains('...attrs') && receivers.isEmpty) {
        throw UiReferenceException('$component :: $name: no attribute target');
      }
      // Aliases such as sidebar and toastViewport can expose unprefixed component hooks.
      aliases.addAll(definition.classes.where((part) => part.startsWith('trellis-')));
      fragments.add({
        'name': name,
        'signature': source,
        'parameters': parameters,
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
