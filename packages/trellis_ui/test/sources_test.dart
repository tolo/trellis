import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:html/parser.dart' show parse;
import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

void main() {
  test('every vendored input carries its licence and the pinned commit', () {
    final pins = jsonDecode(File('tool/pins.json').readAsStringSync()) as Map<String, dynamic>;
    final source = pins['shadcn'] as Map<String, dynamic>;
    final vendor = 'vendor/shadcn/${source['tag']}';
    expect(File('$vendor/SOURCE.md').readAsStringSync(), contains(source['commit']));
    for (final dir in [vendor, 'vendor/tailwind', 'vendor/tw-animate', 'vendor/lucide']) {
      expect(
        Directory(dir).listSync().whereType<File>().any((f) => f.uri.pathSegments.last.startsWith('LICENSE')),
        isTrue,
        reason: dir,
      );
      expect(File('$dir/SOURCE.md').existsSync(), isTrue, reason: dir);
    }
    for (final component in (pins['components'] as List).cast<String>()) {
      expect(File('$vendor/ui/$component.tsx').existsSync(), isTrue);
    }
    final lucide = pins['lucide'] as Map<String, dynamic>;
    expect(File('vendor/lucide/SOURCE.md').readAsStringSync(), contains(lucide['commit']));
    for (final icon in (lucide['icons'] as List).cast<String>()) {
      expect(File('vendor/lucide/$icon.svg').existsSync(), isTrue, reason: icon);
    }
    final notice = File('THIRD_PARTY_NOTICES.md').readAsStringSync();
    for (final name in [
      'shadcn/ui',
      'Tailwind CSS',
      'tw-animate-css',
      'Lucide',
      'Feather',
      'ISC License',
      'Cole Bemis',
    ]) {
      expect(notice, contains(name));
    }
    final css = File('generated/trellis.min.css').readAsStringSync();
    expect(css, contains('tailwindcss v4.3.3'));
    expect(css, contains('Derived from shadcn/ui, MIT License'));
    final sri = 'sha384-${base64Encode(sha384.convert(File('gallery/static/htmx.min.js').readAsBytesSync()).bytes)}';
    expect(
      File('../trellis_cli/lib/src/templates/htmx_asset.dart').readAsStringSync(),
      contains("const htmxSriHash = '$sri'"),
    );
  });

  test('gallery htmx matches its recorded checksum and notice', () {
    const directory = 'gallery/static';
    expect(
      File('$directory/htmx.min.js.sha256').readAsLinesSync(),
      unorderedEquals([
        for (final name in ['htmx.min.js', 'LICENSE.htmx.txt'])
          '${sha256.convert(File('$directory/$name').readAsBytesSync())}  $name',
      ]),
    );
    expect(File('gallery/static/LICENSE.htmx.txt').readAsStringSync(), contains('Zero-Clause'));
    expect(File('THIRD_PARTY_NOTICES.md').readAsStringSync(), contains('htmx 2.0.10'));
    expect(File('.pubignore').readAsLinesSync(), contains('gallery/'));
  });

  test('strict-CSP-clean sources and clean fragments', () {
    final fragments = Directory(
      'assets/fragments',
    ).listSync(followLinks: false).whereType<File>().where((f) => f.path.endsWith('.html')).toList();
    expect(fragments, isNotEmpty);
    for (final file in fragments) {
      expect(TemplateValidator().validate(file.readAsStringSync()), isEmpty, reason: file.path);
    }
    final html = [
      for (final dir in ['assets', 'gallery'])
        ...Directory(
          dir,
        ).listSync(recursive: true, followLinks: false).whereType<File>().where((f) => f.path.endsWith('.html')),
    ];
    expect(html, isNotEmpty);
    for (final file in html) {
      final doc = parse(file.readAsStringSync());
      expect(doc.querySelectorAll('style, script:not([src])'), isEmpty, reason: file.path);
      for (final element in doc.querySelectorAll('*')) {
        expect(
          element.attributes.keys.where((a) => a == 'style' || a.toString().toLowerCase().startsWith('on')),
          isEmpty,
          reason: file.path,
        );
      }
    }
  });
}
