import 'dart:io';

import 'package:path/path.dart' as p;

import 'checks.dart';
import 'record.dart';

/// Components whose failure blocks release regardless of a proposed disposition.
const requiredReleaseComponents = {'combobox', 'dialog', 'dropdown-menu', 'tabs', 'toast'};

/// Every component in the shipped first slice, including any whose evidence is retained after removal.
const releaseComponents = {
  ...requiredReleaseComponents,
  'alert',
  'alert-dialog',
  'badge',
  'breadcrumb',
  'button',
  'card',
  'checkbox',
  'cluster',
  'container',
  'field',
  'grid',
  'input',
  'native-select',
  'pagination',
  'radio',
  'separator',
  'stack',
  'switch',
  'table',
  'textarea',
};

/// Release decisions are recorded next to the ADR's revisit trigger, apart from the observed results.
const releasePolicyPath = 'dev/adrs/ADR-012-trellis-ui-contract.md';

const _items = {...automatedItems, ...manualItems};
const _browsers = {'chrome', 'firefox'};

/// Optional-component dispositions for the release checks and reference generator.
final class ComponentReleasePolicy {
  ComponentReleasePolicy._(this._dispositions);

  /// Reads the structured release decisions in ADR-012.
  factory ComponentReleasePolicy.read(Directory root) =>
      ComponentReleasePolicy.parse(File(p.join(root.path, releasePolicyPath)).readAsStringSync());

  /// Reads the component, disposition and exact failed item IDs from the ADR's text block.
  factory ComponentReleasePolicy.parse(String adr) {
    final section = RegExp(
      r'^#### Optional component release dispositions\n[^#]*?^```text\n([\s\S]*?)^```$',
      multiLine: true,
    ).allMatches(adr.replaceAll('\r\n', '\n')).toList();
    if (section.length != 1) {
      throw const FormatException('ADR-012 must have one Optional component release dispositions block');
    }

    final dispositions = <String, ({bool removed, Set<String> failedItems})>{};
    for (final line in section.single[1]!.split('\n').map((line) => line.trim())) {
      if (line.isEmpty) continue;
      final fields = line.split('|').map((field) => field.trim()).toList();
      if (fields case [final name, 'unsupported' || 'removed', final ids]) {
        if (!releaseComponents.contains(name) || requiredReleaseComponents.contains(name)) {
          throw FormatException('ADR-012 cannot set a release disposition for $name');
        }
        final items = ids.split(',').map((item) => item.trim()).toList();
        final failedItems = items.toSet();
        if (failedItems.length != items.length || !_items.containsAll(failedItems)) {
          throw FormatException('ADR-012: $name needs distinct, known failed gate item IDs');
        }
        if (dispositions.containsKey(name)) {
          throw FormatException('ADR-012 has more than one release disposition for $name');
        }
        dispositions[name] = (removed: fields[1] == 'removed', failedItems: failedItems);
      } else {
        throw FormatException('ADR-012 has an invalid release disposition: $line');
      }
    }
    return ComponentReleasePolicy._(dispositions);
  }

  final Map<String, ({bool removed, Set<String> failedItems})> _dispositions;

  /// Removed components retain evidence and have no live qualification recipe.
  bool isRemoved(String component) => _dispositions[component]?.removed ?? false;

  /// An accepted failure withdraws the component from published reference pages.
  bool isWithdrawn(String component) => _dispositions.containsKey(component);

  /// Retain live checks for components that still ship unsupported.
  Set<String> get activeComponents => releaseComponents.where((name) => !isRemoved(name)).toSet();

  /// Checks that qualification obligations cannot be dropped by deleting a source or record.
  List<String> inventoryIssues(Directory root) {
    final issues = <String>[];
    for (final (folder, extension, expected) in [
      ('dev/ui-gate/records', '.json', releaseComponents),
      ('dev/ui-gate/manifests', '.yaml', activeComponents),
      ('packages/trellis_ui/gallery/pages', '.html', activeComponents),
      ('packages/trellis_ui/assets/fragments', '.html', activeComponents),
    ]) {
      final directory = Directory(p.join(root.path, folder));
      final actual = {
        if (directory.existsSync())
          for (final file in directory.listSync(followLinks: false).whereType<File>())
            if (p.extension(file.path) == extension) p.basenameWithoutExtension(file.path),
      };
      issues.addAll(expected.difference(actual).map((name) => '$folder/$name$extension: missing'));
      issues.addAll(actual.difference(expected).map((name) => '$folder/$name$extension: unexpected'));
    }
    return issues;
  }

  /// Checks that each observed failure has an explicit, current release disposition.
  ///
  /// Composed app records must pass in both browsers. Pending manual work remains visible at release prep.
  List<String> recordIssues(String name, Object? record, {bool app = false}) {
    if (record case {
      'component': final component,
      'automated': final verdict,
      'items': Map<String, Object?> items,
    } when component == name && items.length == _items.length && items.keys.toSet().containsAll(_items)) {
      final issues = <String>[];
      final observedFailures = <String>{};
      final strict = app || name == 'alert-dialog' || requiredReleaseComponents.contains(name);
      for (final item in manualItems) {
        final value = items[item];
        if (!validManualResult(value)) {
          issues.add('$name: $item invalid manual result');
        } else if (value case {'status': 'fail', 'evidence': List<Object?> evidence}) {
          observedFailures.add(item);
          if (!_hasEvidence(evidence)) issues.add('$name: $item missing failure evidence');
        }
      }

      var automatedPass = true;
      for (final item in automatedItems) {
        if (items[item] case {
          'status': final status,
          'browsers': Map<String, Object?> browsers,
        } when browsers.length == _browsers.length && browsers.keys.toSet().containsAll(_browsers)) {
          final results = <GateResult>[];
          for (final browser in _browsers) {
            final raw = browsers[browser];
            if (raw case {
              'status': final String result,
              'evidence': final List<Object?> evidence,
            } when {'pass', 'fail', 'not-run'}.contains(result) && evidence.every((entry) => entry is String)) {
              final unsupported = (raw as Map)['unsupported'] == true;
              results.add(GateResult(result, evidence.cast<String>(), unsupported: unsupported));
              if (!_hasEvidence(evidence)) issues.add('$name: $item/$browser missing evidence');
              if (unsupported && result != 'not-run') issues.add('$name: $item/$browser invalid unsupported marker');
              if (result == 'not-run' && (strict || !unsupported)) issues.add('$name: $item/$browser did not run');
            } else {
              issues.add('$name: $item/$browser invalid browser result');
            }
          }
          final aggregate = gateItemStatus(results);
          if (results.length != _browsers.length || status != aggregate) {
            issues.add('$name: $item inconsistent browser results');
          }
          if (aggregate == 'fail') observedFailures.add(item);
          if (aggregate == 'not-run') issues.add('$name: $item did not run');
          if (aggregate != 'pass') automatedPass = false;
        } else {
          issues.add('$name: $item invalid automated result');
        }
      }

      if (verdict != (automatedPass ? 'pass' : 'fail')) issues.add('$name: inconsistent automated verdict');
      final accepted = app ? null : _dispositions[name]?.failedItems;
      for (final item in observedFailures.difference(accepted ?? const {})) {
        issues.add('$name: $item failed without a release disposition');
      }
      for (final item in (accepted ?? const <String>{}).difference(observedFailures)) {
        issues.add('$name: $item release disposition has no matching failure');
      }
      return issues;
    }
    return ['$name: invalid gate record'];
  }
}

bool _hasEvidence(Iterable<Object?> entries) => entries.any((entry) => entry is String && entry.trim().isNotEmpty);
