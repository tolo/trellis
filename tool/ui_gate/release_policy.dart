import 'dart:io';

import 'package:path/path.dart' as p;

import 'checks.dart';
import 'record.dart';

/// Components whose failure blocks release regardless of a proposed disposition.
const requiredReleaseComponents = {'combobox', 'dialog', 'dropdown-menu', 'popover', 'tabs', 'toast'};

/// Every release subject, including components whose evidence is retained after removal.
const releaseComponents = {
  ...requiredReleaseComponents,
  'accordion',
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
  'navigation-menu',
  'native-select',
  'pagination',
  'radio',
  'separator',
  'sheet',
  'stack',
  'switch',
  'table',
  'textarea',
  'tooltip',
};

/// Release decisions are recorded next to the ADR's revisit trigger, apart from the observed results.
const releasePolicyPath = 'dev/adrs/ADR-012-trellis-ui-contract.md';

const _items = {...automatedItems, ...manualItems};

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

  /// Checks completeness and matches observed failures to current release dispositions.
  List<String> recordIssues(String name, Object? record, {bool app = false}) =>
      _recordIssues(GateRecordAssessment.inspect(name, record), app: app);

  /// Checks an already assessed component before applying a publication withdrawal.
  List<String> withdrawalIssues(GateRecordAssessment record) =>
      isWithdrawn(record.name) ? _recordIssues(record) : const [];

  List<String> _recordIssues(GateRecordAssessment record, {bool app = false}) {
    if (record.declaredVerdict == null) return record.invalid;
    final name = record.name;
    final accepted = app ? const <String>{} : _dispositions[name]?.failedItems ?? const <String>{};
    final failures = record.failedItems;
    return [
      ...record.invalid,
      ...record.unavailable,
      if (!record.hasConsistentVerdict) '$name: inconsistent automated verdict',
      for (final item in failures.difference(accepted)) '$name: $item failed without a release disposition',
      for (final item in accepted.difference(failures)) '$name: $item release disposition has no matching failure',
    ];
  }
}
