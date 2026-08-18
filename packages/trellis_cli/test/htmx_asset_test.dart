import 'dart:io';

import 'package:test/test.dart';
import 'package:trellis_cli/src/templates/base_layout_template.dart';
import 'package:trellis_cli/src/templates/dart_frog/dart_frog_base_layout_template.dart';
import 'package:trellis_cli/src/templates/htmx_asset.dart';
import 'package:trellis_cli/src/templates/relic/relic_base_layout_template.dart';

import '_workspace_root.dart';

/// Matches any pinned HTMX CDN URL, capturing the version.
final _htmxPin = RegExp(r'htmx\.org@([\d.]+(?:-[\w.]+)?)/dist/htmx\.min\.js');

void main() {
  group('scaffolded layouts', () {
    final layouts = {
      'shelf': baseLayoutTemplate('demo'),
      'relic': relicBaseLayoutTemplate('demo'),
      'dart_frog': dartFrogBaseLayoutTemplate('demo'),
    };

    // The pin used to be copy-pasted into each layout, so a bump silently
    // missed some. Every layout must resolve it from htmx_asset.dart instead.
    for (final entry in layouts.entries) {
      test('${entry.key} layout pins exactly the shared HTMX version', () {
        final pins = _htmxPin.allMatches(entry.value).map((m) => m.group(1)).toList();

        expect(pins, hasLength(1), reason: 'expected exactly one HTMX script tag');
        expect(pins.single, htmxVersion);
      });

      test('${entry.key} layout SRI-pins the HTMX script', () {
        expect(entry.value, contains('integrity="$htmxSriHash"'));
        expect(entry.value, contains('crossorigin="anonymous"'));
      });

      test('${entry.key} layout keeps the script tag on its own lines', () {
        // A newline was once lost splicing the tag into a raw-string
        // concatenation, gluing the next element onto the </script> line.
        final scriptClose = entry.value.split('\n').firstWhere((l) => l.contains('crossorigin="anonymous">'));
        expect(scriptClose.trim(), 'crossorigin="anonymous"></script>');
      });
    }
  });

  // Example templates are plain HTML and cannot import the Dart constant, so
  // this is the only thing keeping them from drifting away from it.
  test('example app templates pin the same HTMX version as the CLI', () async {
    final root = await findWorkspaceRoot();
    final examples = Directory('${root.path}/examples');

    final pinned = <String, String>{};
    for (final file in examples.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.html')) continue;
      final match = _htmxPin.firstMatch(file.readAsStringSync());
      if (match != null) {
        pinned[file.path.substring(root.path.length + 1)] = match.group(1)!;
      }
    }

    expect(pinned, isNotEmpty, reason: 'expected example templates to load HTMX');
    expect(
      pinned.values.toSet(),
      {htmxVersion},
      reason:
          'example templates disagree with htmxVersion ($htmxVersion): $pinned. '
          'Bump htmx_asset.dart and every example template together.',
    );
  });

  test('every example HTMX script tag carries the current SRI hash', () async {
    // A bump that updates `src=` but forgets the adjacent `integrity=` passes
    // the version check above, and the browser then silently refuses to load
    // HTMX. So the hash is checked wherever the pin appears, not just where an
    // integrity attribute happens to exist.
    final root = await findWorkspaceRoot();
    final examples = Directory('${root.path}/examples');

    final missing = <String>[];
    final wrong = <String, String>{};
    for (final file in examples.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.html')) continue;
      final content = file.readAsStringSync();
      if (!_htmxPin.hasMatch(content)) continue;
      final rel = file.path.substring(root.path.length + 1);

      final integrity = RegExp(r'integrity="(sha384-[A-Za-z0-9+/=]+)"').firstMatch(content)?.group(1);
      if (integrity == null) {
        missing.add(rel);
      } else if (integrity != htmxSriHash) {
        wrong[rel] = integrity;
      }
    }

    expect(missing, isEmpty, reason: 'example templates load HTMX without an SRI hash: $missing');
    expect(wrong, isEmpty, reason: 'example templates carry a stale SRI hash (expected $htmxSriHash): $wrong');
  });
}
