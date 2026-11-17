import 'dart:io';

import 'package:html/parser.dart';
import 'package:test/test.dart';

Iterable<File> filesUnder(String path) => Directory(path).listSync(recursive: true).whereType<File>();

void main() {
  test('templates are provider-free and strict-clean', () {
    final templates = filesUnder('templates').where((file) => file.path.endsWith('.html'));
    expect(templates, isNotEmpty);
    for (final file in templates) {
      final source = file.readAsStringSync();
      expect(source, isNot(matches(r'\bcn-')), reason: file.path);
      final elements = parse(source).querySelectorAll('*');
      for (final element in elements) {
        final reason = '${file.path}: ${element.outerHtml.split('\n').first}';
        expect(element.localName, isNot('style'), reason: reason);
        if (element.localName == 'script') {
          final script = element.attributes['src'];
          expect(script, startsWith('/'), reason: reason);
          expect(Uri.parse(script!).hasAuthority, isFalse, reason: reason);
          expect(element.text.trim(), isEmpty, reason: reason);
        }
        for (final attribute in element.attributes.keys.whereType<String>()) {
          final name = attribute.replaceFirst(RegExp(r'^data-(?=hx-on)'), '');
          expect(name, isNot(matches(r'^(data-slot$|style$|on|hx-on)')), reason: reason);
        }
        expect(element.classes, everyElement(matches(r'^(admin|trellis)-')), reason: reason);
      }
    }
  });

  test('app CSS stays within 50 lines and no authored JS exists', () {
    final files = filesUnder('static');
    final css = files.where((file) => file.path.toLowerCase().endsWith('.css')).toList();
    expect(css, isNotEmpty);
    int sourceLines(File file) => file
        .readAsStringSync()
        .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .length;
    expect(
      css.fold<int>(0, (total, file) => total + sourceLines(file)),
      lessThanOrEqualTo(50),
      reason: css.map((file) => '${file.path}: ${sourceLines(file)} lines').join(', '),
    );
    expect(
      files
          .where((file) => RegExp(r'\.(?:[cm]?js)$', caseSensitive: false).hasMatch(file.path))
          .map((file) => file.path),
      ['static/js/htmx.min.js'],
    );
  });
}
