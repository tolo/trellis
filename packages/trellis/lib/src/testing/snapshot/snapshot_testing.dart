import 'dart:io';

import 'package:matcher/expect.dart' show fail;
import 'package:trellis/trellis.dart';

import 'html_normalizer.dart';

/// Whether golden files should be updated instead of compared.
///
/// Set via the `TRELLIS_UPDATE_GOLDENS` environment variable:
/// ```sh
/// TRELLIS_UPDATE_GOLDENS=true dart test
/// ```
bool get updateGoldens {
  final value = Platform.environment['TRELLIS_UPDATE_GOLDENS'];
  return value == 'true' || value == '1';
}

/// Renders a template file and compares the output against a golden file.
///
/// On first run (golden file does not exist), the golden file is auto-created
/// and the test passes with an informational print message.
///
/// On subsequent runs, the rendered output is compared against the golden file.
/// A mismatch causes a test failure with a readable diff showing expected vs
/// actual content.
///
/// When `TRELLIS_UPDATE_GOLDENS=true` is set, the golden file is always
/// overwritten with the current rendered output, and the test passes.
///
/// The [goldenFile] path is relative to the current working directory
/// (typically the package root when running `dart test`). If a [fragment] is
/// specified, only that fragment is rendered.
///
/// ```dart
/// test('page snapshot', () async {
///   await expectSnapshot(
///     engine, 'page',
///     {'title': 'Hello', 'items': ['A', 'B']},
///     goldenFile: 'test/goldens/page.html',
///   );
/// });
/// ```
Future<void> expectSnapshot(
  Trellis engine,
  String template,
  Map<String, dynamic> context, {
  required String goldenFile,
  String? fragment,
}) async {
  final String rendered;
  if (fragment != null) {
    rendered = await engine.renderFileFragment(template, fragment: fragment, context: context);
  } else {
    rendered = await engine.renderFile(template, context);
  }
  compareOrCreateGolden(normalizeHtml(rendered), goldenFile);
}

/// Renders a template source string and compares against a golden file.
///
/// Same semantics as [expectSnapshot] but accepts a raw template source
/// string instead of a template name. Useful when templates are defined
/// inline in test code.
///
/// ```dart
/// test('inline snapshot', () {
///   expectSnapshotFromSource(
///     engine,
///     '<h1 tl:text="${title}">x</h1>',
///     {'title': 'Hello'},
///     goldenFile: 'test/goldens/inline.html',
///   );
/// });
/// ```
void expectSnapshotFromSource(
  Trellis engine,
  String source,
  Map<String, dynamic> context, {
  required String goldenFile,
  String? fragment,
}) {
  final String rendered;
  if (fragment != null) {
    rendered = engine.renderFragment(source, fragment: fragment, context: context);
  } else {
    rendered = engine.render(source, context);
  }
  compareOrCreateGolden(normalizeHtml(rendered), goldenFile);
}

/// Core golden file comparison logic. Package-private for testability.
///
/// 1. If [update] is true: write [actual] to [goldenPath], return (pass).
/// 2. If golden file does not exist: create it with [actual], print info message, return (pass).
/// 3. If golden file exists: read expected, compare with [actual].
///    - Match: return (pass).
///    - Mismatch: throw [TestFailure] with a readable line-by-line diff.
void compareOrCreateGolden(String actual, String goldenPath, {bool? update}) {
  final shouldUpdate = update ?? updateGoldens;
  final file = File(goldenPath);

  if (shouldUpdate) {
    _writeGolden(file, actual);
    // ignore: avoid_print
    print('Golden file updated: $goldenPath');
    return;
  }

  if (!file.existsSync()) {
    _writeGolden(file, actual);
    // ignore: avoid_print
    print('Golden file created: $goldenPath (first run)');
    return;
  }

  final expected = file.readAsStringSync();
  if (expected == actual) return;

  fail(_buildDiff(expected, actual, goldenPath));
}

/// Creates parent directories and writes golden file content.
void _writeGolden(File file, String content) {
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

/// Builds a readable line-by-line diff of expected vs actual content.
String _buildDiff(String expected, String actual, String goldenPath) {
  final expectedLines = expected.split('\n');
  final actualLines = actual.split('\n');

  final buffer = StringBuffer();
  buffer.writeln('Snapshot mismatch for $goldenPath');
  buffer.writeln();
  buffer.writeln('--- expected');
  buffer.writeln('+++ actual');

  // Simple line-by-line diff with up to 2 lines of context around each hunk.
  const contextSize = 2;
  final maxLen = expectedLines.length > actualLines.length ? expectedLines.length : actualLines.length;

  var inHunk = false;
  var lastPrintedLine = -1;

  for (var i = 0; i < maxLen; i++) {
    final exp = i < expectedLines.length ? expectedLines[i] : null;
    final act = i < actualLines.length ? actualLines[i] : null;

    if (exp != act) {
      // Print context before this diff line (if not already printed).
      final contextStart = (i - contextSize).clamp(0, maxLen - 1);
      if (!inHunk || lastPrintedLine < contextStart - 1) {
        buffer.writeln('@@ line ${i + 1} @@');
        inHunk = true;
      }
      // Print any context lines between last printed and current.
      for (var c = (lastPrintedLine + 1).clamp(contextStart, i); c < i; c++) {
        if (c < expectedLines.length) buffer.writeln(' ${expectedLines[c]}');
      }
      if (exp != null) buffer.writeln('-$exp');
      if (act != null) buffer.writeln('+$act');
      lastPrintedLine = i;
    } else if (inHunk && i <= lastPrintedLine + contextSize) {
      // Print trailing context lines after a diff.
      if (exp != null) buffer.writeln(' $exp');
      lastPrintedLine = i;
    }
  }

  buffer.writeln();
  buffer.writeln('To update golden files, run:');
  buffer.write('  TRELLIS_UPDATE_GOLDENS=true dart test');
  return buffer.toString();
}
