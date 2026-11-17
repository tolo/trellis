import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

import '../tool/src/pipeline.dart';

void main() {
  late Directory fixture;
  setUp(() {
    fixture = Directory.systemTemp.createTempSync('suite_pipeline_');
    for (final dir in ['tool', 'generated']) {
      Directory('${fixture.path}/$dir').createSync();
    }
    File('${fixture.path}/tool/pins.json').writeAsStringSync(File('tool/pins.json').readAsStringSync());
  });
  tearDown(() => fixture.deleteSync(recursive: true));

  test('a compiler that does not match its pin stops the build before generating', () async {
    final executable = File('${fixture.path}/compiler')..writeAsStringSync('untrusted');
    final untouched = File('${fixture.path}/generated/entry.css')..writeAsStringSync('untouched');
    final pipeline = Pipeline(fixture);
    final pin = ((pipeline.pins['compiler'] as Map)['platforms'] as Map)['macos-arm64'] as String;
    await expectLater(
      pipeline.build(compilerPath: executable.path, platform: 'macos-arm64'),
      throwsA(
        isA<StateError>().having(
          (e) => '$e',
          'digest message',
          allOf(contains(pin), contains(sha256.convert(utf8.encode('untrusted')).toString())),
        ),
      ),
    );
    await expectLater(
      pipeline.build(compilerPath: executable.path, platform: 'unknown'),
      throwsA(isA<StateError>().having((e) => '$e', 'platform', contains('unknown'))),
    );
    expect(untouched.readAsStringSync(), 'untouched');
    expect(Directory('${fixture.path}/generated').listSync(), hasLength(1));
  });

  test('entry.css regenerates byte for byte from the vendored inputs', () async {
    await Pipeline(Directory.current).generator.generate(output: Directory('${fixture.path}/generated'));
    for (final name in ['entry.css', 'report.json']) {
      expect(
        File('${fixture.path}/generated/$name').readAsStringSync(),
        File('generated/$name').readAsStringSync(),
        reason: name,
      );
    }
  });

  test('structural classes without a hook are reported', () async {
    final pins = Pipeline(Directory.current).pins;
    pins['components'] = ['button'];
    File('${fixture.path}/tool/pins.json').writeAsStringSync(jsonEncode(pins));
    final tag = (pins['shadcn'] as Map)['tag'];
    final src = Directory('${fixture.path}/vendor/shadcn/$tag/ui')..createSync(recursive: true);
    for (final file in ['tailwind.css', 'style-vega.css', 'colors-neutral.json']) {
      File('vendor/shadcn/$tag/$file').copySync('${src.parent.path}/$file');
    }
    File('${src.path}/button.tsx').writeAsStringSync(
      '''<button data-slot="orphan" className={cn("fixed invisible")} /><p data-slot="literal" className="absolute visible" />''',
    );
    await Pipeline(fixture).generator.generate();
    final report = jsonDecode(File('${fixture.path}/generated/report.json').readAsStringSync()) as Map<String, dynamic>;
    expect(report['orphanLiterals'], [
      {'file': 'button.tsx', 'line': 1, 'slot': 'orphan', 'literal': 'fixed invisible'},
      {'file': 'button.tsx', 'line': 1, 'slot': 'literal', 'literal': 'absolute visible'},
    ]);
    final entry = File('${fixture.path}/generated/entry.css').readAsStringSync();
    expect(entry, isNot(contains('@apply fixed invisible')));
    expect(entry, isNot(contains('@apply absolute visible')));
  });

  test('fetch uses commit URLs and fails before replacing inputs on an absent component', () async {
    final seen = <Uri>[];
    final pipeline = Pipeline(
      fixture,
      download: (uri) async {
        seen.add(uri);
        if (uri.path.endsWith('button.tsx')) throw const HttpException('404');
        return utf8.encode('fixture');
      },
    );
    await expectLater(pipeline.fetch(), throwsA(isA<HttpException>()));
    expect(seen, isNotEmpty);
    final commit = (pipeline.pins['shadcn'] as Map)['commit'] as String;
    expect(seen.every((u) => u.path.contains(commit)), isTrue);
    expect(Directory('${fixture.path}/vendor').existsSync(), isFalse);
  });
}
