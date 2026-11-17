// Executes the labelled examples published in the composition docs (ADR-014 primitives), so a page cannot drift from
// the engine. Labels live in each fence's info string, after the language:
//
//   file=<name>                  a template added to the page's loader; it must also validate clean
//   render=<id> [fragment=<f>]   the template source to render (with fragment=, through renderFragment)
//   context=<id>                 JSON render context for <id> (optional; default empty)
//   output=<id>                  the expected output of <id>, compared with whitespace collapsed
//   throws=<id>                  a fence whose first line must appear in the TemplateException message of <id>
//   static                       deliberately not executed (syntax or error text)
//
// Every html fence in every page below must carry one of file, render, output or static, so no example is unexecuted
// prose. Label an illustrative fence (it needs a loader or context the page does not define) `static`.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:trellis/testing.dart';
import 'package:trellis/trellis.dart';

import 'test_paths.dart';

final _docs = '${repoRoot.path}/site/content/docs/syntax';

/// Pages whose labelled examples run, and how many renders each must yield (guards against silently running none).
const _pages = {'composition.md': 17, 'attributes.md': 6, 'fragments.md': 5};

final class _Fence {
  final String lang;
  final Map<String, String> labels;
  final String body;
  final int line;
  _Fence(this.lang, this.labels, this.body, this.line);
}

List<_Fence> _fences(String page) {
  final file = File('$_docs/$page');
  if (!file.existsSync()) fail('$_docs/$page not found');
  final lines = file.readAsLinesSync();
  final fences = <_Fence>[];
  for (var i = 0; i < lines.length; i++) {
    final open = RegExp(r'^```(\w+)\s*(.*)$').firstMatch(lines[i]);
    if (open == null) continue;
    final labels = <String, String>{};
    for (final token in open[2]!.split(RegExp(r'\s+')).where((t) => t.isNotEmpty)) {
      final eq = token.indexOf('=');
      labels[eq == -1 ? token : token.substring(0, eq)] = eq == -1 ? '' : token.substring(eq + 1);
    }
    final start = i + 1;
    while (i + 1 < lines.length && lines[i + 1] != '```') {
      i++;
    }
    fences.add(_Fence(open[1]!, labels, lines.sublist(start, i + 1).join('\n'), start));
    i++;
  }
  return fences;
}

/// Drops the `<html><head></head><body>` wrapper the HTML parser adds around a fragment, then collapses whitespace.
String _normalize(String html) {
  var out = html.trim();
  final wrapper = RegExp(r'^<html><head></head><body>(.*)</body></html>$', dotAll: true).firstMatch(out);
  if (wrapper != null) out = wrapper[1]!;
  return out.replaceAll(RegExp(r'\s+'), ' ').replaceAll('> <', '><').trim();
}

void main() {
  for (final MapEntry(key: page, value: minimum) in _pages.entries) {
    group('docs/$page', () {
      final fences = _fences(page);
      final files = <String, String>{
        for (final f in fences)
          if (f.labels.containsKey('file')) f.labels['file']!: f.body,
      };
      final engine = testEngine(templates: files);

      T byId<T>(String label, String id, T Function(_Fence) pick) =>
          pick(fences.singleWhere((f) => f.labels[label] == id, orElse: () => fail('$page: no $label=$id fence')));

      final ids = [
        for (final f in fences)
          if (f.labels.containsKey('render')) f.labels['render']!,
      ];

      test('has at least $minimum executed renders', () => expect(ids.length, greaterThanOrEqualTo(minimum)));

      for (final name in files.keys) {
        test('file $name validates clean', () => expect(files[name]!, isValidTemplate()));
      }

      for (final id in ids) {
        test('render $id', () {
          final render = fences.singleWhere((f) => f.labels['render'] == id);
          final contextFence = fences.where((f) => f.labels['context'] == id);
          final context = contextFence.isEmpty
              ? <String, dynamic>{}
              : jsonDecode(contextFence.single.body) as Map<String, dynamic>;
          final fragment = render.labels['fragment'];
          String run() => fragment == null
              ? engine.render(render.body, context)
              : engine.renderFragment(render.body, fragment: fragment, context: context);

          final throwsFence = fences.where((f) => f.labels['throws'] == id);
          if (throwsFence.isNotEmpty) {
            final expected = throwsFence.single.body.split('\n').first.trim();
            expect(run, throwsA(isA<TemplateException>().having((e) => e.toString(), 'message', contains(expected))));
          } else {
            expect(_normalize(run()), _normalize(byId('output', id, (f) => f.body)));
          }
        });
      }

      test('every context, output and throws label belongs to a render', () {
        for (final label in ['context', 'output', 'throws']) {
          for (final f in fences.where((f) => f.labels.containsKey(label))) {
            expect(ids, contains(f.labels[label]), reason: '$page:${f.line} $label=${f.labels[label]}');
          }
        }
      });

      test('every html fence is labelled', () {
        const labels = {'file', 'render', 'output', 'static'};
        for (final f in fences.where((f) => f.lang == 'html')) {
          expect(f.labels.keys.any(labels.contains), isTrue, reason: '$page:${f.line} html fence has no label');
        }
      });
    });
  }
}
