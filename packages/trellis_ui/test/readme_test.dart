import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('the component table lists every public fragment of the six components', () {
    const components = ['alert-dialog', 'combobox', 'dialog', 'dropdown-menu', 'tabs', 'toast'];
    final declaration = RegExp(r'tl:fragment="([\w-]+)\(([^"]*)\)"');
    final row = RegExp(r'^\| `([\w-]+) :: ([\w-]+)` \| ([^|]+) \|', multiLine: true);
    final catalogue = File('README.md').readAsStringSync();
    final entries = [
      for (final match in row.allMatches(catalogue))
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
