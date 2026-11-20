import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:html/parser.dart';
import 'package:test/test.dart';
import 'package:trellis_ui/trellis_ui.dart';

import '../../../tool/ui_gate/release_policy.dart';
import 'fixtures.dart';

Iterable<File> filesUnder(String path) => Directory(path).listSync(recursive: true).whereType<File>();

void main() {
  test('the example uses no withdrawn suite fragments', () {
    final policy = ComponentReleasePolicy.read(Directory.current.parent.parent);
    final sources = {
      for (final file in [...filesUnder('templates'), ...filesUnder('lib')]) file.path: file.readAsStringSync(),
    };
    expect(_withdrawnSuiteUses(sources, policy), isEmpty);
  });

  test('withdrawal applies to nested suite fragments and HTML template names', () {
    final policy = ComponentReleasePolicy.parse('''
#### Optional component release dispositions

```text
button | unsupported | safari
```
''');
    expect(_withdrawnSuiteUses({'edit.html': '<div tl:replace="~{trellis-ui/dialog :: dialog}"></div>'}, policy), [
      'edit.html → dialog → button',
    ]);
    expect(_withdrawnSuiteUses({'edit.html': '<div tl:replace="~{trellis-ui/dialog.html :: dialog}"></div>'}, policy), [
      'edit.html → dialog → button',
    ]);
    expect(
      _withdrawnSuiteUses({'edit.html': '<div tl:replace="~{trellis-ui/combobox :: combobox}"></div>'}, policy),
      isEmpty,
    );
  });

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

  test('app CSS stays within 50 lines and only the pinned calendar recipe adds scripts', () {
    final files = filesUnder('static');
    int sourceLines(File file) => file
        .readAsStringSync()
        .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .length;
    final cssLines = {
      for (final file in files)
        if (file.path.toLowerCase().endsWith('.css')) file.path: sourceLines(file),
    };
    expect(cssLines, isNotEmpty);
    expect(
      cssLines.values.fold<int>(0, (total, lines) => total + lines),
      lessThanOrEqualTo(50),
      reason: cssLines.entries.map((entry) => '${entry.key}: ${entry.value} lines').join(', '),
    );
    expect(
      files
          .where((file) => RegExp(r'\.(?:[cm]?js)$', caseSensitive: false).hasMatch(file.path))
          .map((file) => file.path),
      unorderedEquals([
        for (final asset in [htmxAsset, dateRecipeAsset, callyAsset]) 'static$asset',
      ]),
    );
    expect(sha256.convert(File('static$callyAsset').readAsBytesSync()).toString(), callySha256);
    expect(
      sha256.convert(File('static$callyLicense').readAsBytesSync()).toString(),
      'c48fd407090d6d752b0370d39db55bd750e6dfc678ee252d4c906bddf54132eb',
    );
  });
}

Iterable<String> _withdrawnSuiteUses(Map<String, String> sources, ComponentReleasePolicy policy) sync* {
  // The templates compose most fragments. The HTTP handlers also render some by name.
  final reference = RegExp(r'''(?:~\{\s*|['"])trellis-ui/([\w-]+)(?:\.html)?(?=\s*::|['"])''');
  final loader = TrellisUiLoader();
  final visited = <String>{};
  Iterable<String> visit(String source, String path) sync* {
    for (final match in reference.allMatches(source)) {
      final component = match[1]!;
      if (!visited.add(component)) continue;
      final chain = '$path → $component';
      if (policy.isWithdrawn(component)) {
        yield chain;
      } else {
        yield* visit(loader.loadSync('trellis-ui/$component'), chain);
      }
    }
  }

  for (final entry in sources.entries) {
    yield* visit(entry.value, entry.key);
  }
}
