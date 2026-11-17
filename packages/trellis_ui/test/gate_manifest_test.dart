import 'dart:io';

import 'package:test/test.dart';

import '../../../tool/ui_gate/manifest.dart';

void main() {
  GateManifest manifest(String name) => GateManifest.load(File('../../dev/ui-gate/manifests/$name.yaml'));
  Iterable<Object?> presses(String name) => manifest(name).keyboard.map((step) => step['press']).whereType<String>();

  test('dropdown-menu keyboard script walks every key of the menu pattern', () {
    final keys = presses('dropdown-menu');
    expect(keys, containsAll(['Enter', ' ', 'ArrowDown', 'ArrowUp', 'Home', 'End', 'Escape', 'Tab']));
    expect(keys.any((key) => key is String && RegExp(r'^[a-z]$', caseSensitive: false).hasMatch(key)), isTrue);
  });

  test('tabs keyboard script walks every key of the tabs pattern', () {
    expect(
      presses('tabs'),
      containsAll(['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown', 'Home', 'End', 'Enter', ' ', 'Tab']),
    );
  });

  test('combobox keyboard script walks every key of the combobox pattern', () {
    expect(manifest('combobox').keyboard, contains(containsPair('type', 'ap')));
    expect(presses('combobox'), containsAll(['ArrowDown', 'ArrowUp', 'Enter', 'Escape', 'Home', 'End', 'Tab']));
  });
}
