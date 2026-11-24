import 'dart:io';

import 'package:test/test.dart';

import '../../../tool/ui_gate/release_policy.dart';

void main() {
  test('the component table lists every public fragment of required or example-used components', () {
    final policy = ComponentReleasePolicy.read(Directory.current.parent.parent);
    final components = {
      ...requiredReleaseComponents,
      if (!policy.isWithdrawn('alert-dialog')) 'alert-dialog',
      if (!policy.isWithdrawn('navigation-menu')) 'navigation-menu',
    };
    final declaration = RegExp(r'tl:fragment="([\w-]+)\(([^"]*)\)"');
    final row = RegExp(r'^\| `([\w-]+) :: ([\w-]+)` \| ([^|]+) \|', multiLine: true);
    final catalogue = File('README.md').readAsStringSync();
    final rows = row.allMatches(catalogue).toList();
    expect(rows.map((match) => match[1]!).where(policy.isWithdrawn), isEmpty);
    final entries = [
      for (final match in rows)
        if (components.contains(match[1])) (match[1]!, match[2]!, match[3]!.trim().replaceAll('`', '')),
    ];
    expect(entries, isNotEmpty);
    expect(
      entries,
      unorderedEquals([
        for (final component in components)
          for (final fragment in declaration.allMatches(File('assets/fragments/$component.html').readAsStringSync()))
            (component, fragment[1]!, fragment[2] == '...attrs' ? 'none' : fragment[2]!.replaceFirst(', ...attrs', '')),
      ]),
    );
  });
}
