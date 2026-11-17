import 'package:test/test.dart';
import 'package:trellis_cli/trellis_cli.dart';
import 'package:trellis_cli/src/templates/htmx_asset.dart';

void main() {
  final scaffolds = {
    'shelf': (
      generateDefault: (InMemoryFileWriter writer) => ProjectGenerator(projectName: 'demo', writer: writer).generate(),
      generateUi: (InMemoryFileWriter writer) =>
          ProjectGenerator(projectName: 'demo', writer: writer, ui: true).generate(),
      page: 'templates/pages/ui.html',
      layout: 'templates/layouts/base.html',
      preview: 'static/trellis-ui',
      relative: '../../static/trellis-ui',
    ),
    'relic': (
      generateDefault: (InMemoryFileWriter writer) =>
          RelicProjectGenerator(projectName: 'demo', writer: writer).generate(),
      generateUi: (InMemoryFileWriter writer) =>
          RelicProjectGenerator(projectName: 'demo', writer: writer, ui: true).generate(),
      page: 'templates/ui.html',
      layout: 'templates/base.html',
      preview: 'static/trellis-ui',
      relative: '../static/trellis-ui',
    ),
    'dart frog': (
      generateDefault: (InMemoryFileWriter writer) =>
          DartFrogProjectGenerator(projectName: 'demo', writer: writer).generate(),
      generateUi: (InMemoryFileWriter writer) =>
          DartFrogProjectGenerator(projectName: 'demo', writer: writer, ui: true).generate(),
      page: 'templates/pages/ui.html',
      layout: 'templates/layouts/base.html',
      preview: 'public/trellis-ui',
      relative: '../../public/trellis-ui',
    ),
  };

  test('default scaffolds mention no trellis_ui', () async {
    for (final scaffold in scaffolds.values) {
      final defaultWriter = InMemoryFileWriter();
      final uiWriter = InMemoryFileWriter();
      await scaffold.generateDefault(defaultWriter);
      await scaffold.generateUi(uiWriter);
      expect(uiWriter.files.keys, containsAll(defaultWriter.files.keys));
      expect(defaultWriter.files.keys, isNot(contains(scaffold.page)));
      expect(defaultWriter.files['.gitignore'], isNot(contains(scaffold.preview)));
      for (final entry in defaultWriter.files.entries) {
        expect(entry.value, isNot(contains('trellis_ui')), reason: entry.key);
        expect(entry.value, isNot(contains('/trellis-ui/')), reason: entry.key);
        if (entry.key.endsWith('/styles.css')) {
          expect(uiWriter.files[entry.key], contains(entry.value), reason: entry.key);
        } else if (entry.key.endsWith('.js')) {
          expect(uiWriter.files[entry.key], entry.value, reason: entry.key);
        }
      }
    }
  });

  for (final entry in scaffolds.entries) {
    final scaffold = entry.value;
    test('${entry.key} ui scaffold files are strict-clean, provider-free and gitignore the preview folder', () async {
      final writer = InMemoryFileWriter();
      await scaffold.generateUi(writer);
      final files = writer.files;
      expect(files['.gitignore']!.split('\n'), contains('/${scaffold.preview}/'));
      expect(files.values.any((source) => source.contains('href="/ui"')), isTrue);
      final page = files[scaffold.page]!;
      final classes = RegExp(r'\bclass="([^"]+)"').allMatches(page).expand((match) => match[1]!.split(RegExp(r'\s+')));
      expect(classes, isNotEmpty);
      expect(classes, everyElement(startsWith('trellis-')));
      for (final entry in files.entries.where((entry) => entry.key.endsWith('.html'))) {
        expect(entry.value, isNot(contains('data-slot')), reason: entry.key);
        expect(entry.value, isNot(contains('cn-')), reason: entry.key);
        expect(
          entry.value,
          isNot(
            matches(
              RegExp(r'<style\b|\s(?:style|on[a-z]+|hx-on[^=\s]*)\s*=|<script(?![^>]*\bsrc=)', caseSensitive: false),
            ),
          ),
          reason: entry.key,
        );
      }
      for (final path in [scaffold.layout, scaffold.page]) {
        final source = files[path]!;
        expect(source, contains('href="${scaffold.relative}/trellis-ui.css" tl:href="@{/trellis-ui/trellis-ui.css}"'));
        expect(source, contains('src="${scaffold.relative}/trellis-ui.js" tl:src="@{/trellis-ui/trellis-ui.js}"'));
        expect(source, isNot(contains('type="module"')));
        expect(source, isNot(contains('/trellis-ui/htmx-indicator.css')));
      }
      expect(files['${scaffold.preview.split('/').first}/styles.css'], contains(htmxIndicatorCss));
    });
  }
}
