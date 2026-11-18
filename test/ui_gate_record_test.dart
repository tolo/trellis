import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../tool/ui_gate/appearance.dart';
import '../tool/ui_gate/checks.dart';
import '../tool/ui_gate/driver.dart';
import '../tool/ui_gate/firefox.dart';
import '../tool/ui_gate/manifest.dart';
import '../tool/ui_gate/record.dart';
import '../tool/ui_gate/run.dart';
import 'browser_reflow_probe.dart';
import 'ui_gate_test_support.dart';

void main() {
  test('record preserves manual items and does not hide failed or unavailable checks', () {
    final results = {
      for (final item in automatedItems) item: const GateResult('pass', ['observed']),
    };
    final previous = <String, Object?>{
      'items': {
        'safari': {
          'status': 'pass',
          'evidence': ['Owner checked Safari'],
        },
      },
    };
    final record = gateRecord('fixture', {'chrome': results}, previous: previous);
    expect(record['automated'], 'pass');
    final items = record['items'] as Map;
    expect(items.keys, [...automatedItems, ...manualItems]);
    expect(items['safari'], (previous['items'] as Map)['safari']);
    expect((items['screen-reader-voiceover-safari'] as Map)['status'], 'release-prep');
    expect(encodeRecord(gateRecord('fixture', {'chrome': results}, previous: record)), encodeRecord(record));
    results['touch-target'] = const GateResult('fail', ['20px below 24px']);
    final failed = gateRecord('fixture', {'chrome': results});
    expect(failed['automated'], 'fail');
    expect(((failed['items'] as Map)['touch-target'] as Map)['status'], 'fail');
    results['touch-target'] = const GateResult('not-run', ['condition unavailable']);
    expect(gateRecord('fixture', {'chrome': results})['automated'], 'fail');
    final supported = {
      for (final item in automatedItems) item: const GateResult('pass', ['observed']),
    };
    results['touch-target'] = const GateResult('not-run', ['condition unavailable'], unsupported: true);
    expect(gateRecord('fixture', {'chrome': supported, 'firefox': results})['automated'], 'pass');
  });

  test('a missing visual baseline reports that the comparison did not run', () async {
    if (BrowserProbe.locateChrome() == null) {
      requireChromeInCi('UI gate visual baseline availability');
      markTestSkipped('Chrome not installed');
      return;
    }
    final server = await fixtureServer();
    final scratch = Directory('.agent_temp')..createSync(recursive: true);
    final baselineDir = scratch.createTempSync('gate-missing-baseline-');
    addTearDown(() => baselineDir.deleteSync(recursive: true));
    final results = await runGate(fixtureManifest(), server.baseUrl, 'chrome', baselines: baselineDir);
    expect(results['visual']!.status, 'not-run');
    expect(results['visual']!.unsupported, isFalse);
    expect(results['visual']!.evidence, ['no baseline for fixture/chrome on ${Platform.operatingSystem}']);
  });

  test('unsupported dark emulation preserves an already observed appearance failure', () async {
    if (BrowserProbe.locateChrome() == null) {
      requireChromeInCi('UI gate appearance before an unsupported condition');
      markTestSkipped('Chrome not installed');
      return;
    }
    final server = await fixtureServer();
    final scratch = Directory('.agent_temp')..createSync(recursive: true);
    final baselineDir = scratch.createTempSync('gate-emulation-after-capture-');
    addTearDown(() => baselineDir.deleteSync(recursive: true));

    Future<GateResult> visual(String page) async {
      final result = await runGate(fixtureManifest(page: page), server.baseUrl, 'chrome', baselines: baselineDir);
      return result['visual']!;
    }

    final failed = await visual('/pass.html?unsupported-dark&defect=overlap');
    expect(failed.status, 'fail', reason: '${failed.evidence}');
    expect(failed.unsupported, isFalse);
    expect(failed.evidence.join('\n'), contains('default #toast-one overlaps #toast-two'));
    expect(failed.evidence.join('\n'), contains('dark=true'));

    final unsupported = await visual('/pass.html?unsupported-dark');
    expect(unsupported.status, 'not-run');
    expect(unsupported.unsupported, isTrue);
    expect(unsupported.evidence.single, contains('dark=true'));

    final baseline = File('${baselineDir.path}/fixture.${Platform.operatingSystem}.json');
    final driver = await ChromeDriver.launch();
    try {
      final captured = await captureAppearance(GateSession(fixtureManifest(), driver, server.baseUrl));
      expect(captured['invariants'], isEmpty);
      baseline.writeAsStringSync(
        encodeCapture({
          'platform': Platform.operatingSystem,
          'browsers': {'chrome': captured},
        }),
      );
    } finally {
      await driver.close();
    }
    final unchanged = await visual('/pass.html?unsupported-dark');
    expect(unchanged.toJson(), unsupported.toJson(), reason: 'unmeasured states are still eligible for fallback');

    final changed = await runGate(
      fixtureManifest(page: '/pass.html?unsupported-dark&defect=late-outline'),
      server.baseUrl,
      'chrome',
      baselines: baselineDir,
    );
    final visualChange = changed['visual']!;
    expect(visualChange.status, 'fail', reason: '${visualChange.toJson()}');
    expect(visualChange.unsupported, isFalse);
    expect(visualChange.evidence.join('\n'), contains('default/focus-visible:input #name outlineColor'));
    expect(visualChange.evidence.join('\n'), contains('dark=true'));
    final passingBrowser = {
      for (final item in automatedItems) item: const GateResult('pass', ['observed']),
    };
    final record = gateRecord('fixture', {'chrome': changed, 'firefox': passingBrowser});
    expect(((record['items'] as Map)['visual'] as Map)['status'], 'fail');

    baseline.writeAsStringSync('{');
    final unreadable = await visual('/pass.html?unsupported-dark');
    expect(unreadable.status, 'not-run');
    expect(unreadable.unsupported, isFalse);
    expect(unreadable.evidence.single, contains('Unexpected end of input'));

    final measured = await visual('/pass.html?unsupported-dark&defect=overlap');
    expect(measured.status, 'fail');
    expect(measured.evidence.join('\n'), contains('default #toast-one overlaps #toast-two'));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('a visual capture artifact that cannot be written is unavailable', () async {
    if (BrowserProbe.locateChrome() == null) {
      requireChromeInCi('UI gate capture artifact availability');
      markTestSkipped('Chrome not installed');
      return;
    }
    final server = await fixtureServer();
    final scratch = Directory('.agent_temp')..createSync(recursive: true);
    final fixture = scratch.createTempSync('gate-unwritable-capture-');
    addTearDown(() => fixture.deleteSync(recursive: true));
    final blocked = File('${fixture.path}/captures')..createSync();
    final results = await runGate(
      fixtureManifest(),
      server.baseUrl,
      'chrome',
      baselines: fixture,
      captures: Directory(blocked.path),
    );
    expect(results['visual']!.status, 'not-run');
    expect(results['visual']!.unsupported, isFalse);
    expect(results['visual']!.evidence.single, contains('captures'));
  });

  test('exhausted Firefox hover capture retries report an unavailable visual check', () async {
    if (FirefoxDriver.locateFirefox() == null || FirefoxDriver.locateGeckodriver() == null) {
      markTestSkipped('Firefox or geckodriver not installed');
      return;
    }
    final server = await fixtureServer();
    final scratch = Directory('.agent_temp')..createSync(recursive: true);
    final fixture = scratch.createTempSync('gate-hover-without-focus-');
    addTearDown(() => fixture.deleteSync(recursive: true));
    final manifest = fixtureManifest(
      replace: 'default: []',
      withText: 'default:\n    - eval: "document.hasFocus = () => false"',
    );
    final results = await runGate(manifest, server.baseUrl, 'firefox', baselines: fixture);
    expect(results['visual']!.status, 'not-run');
    expect(results['visual']!.unsupported, isFalse);
    expect(results['visual']!.evidence.single, contains('Firefox lost document focus during three hover captures'));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('record and cli', () async {
    if (BrowserProbe.locateChrome() == null) {
      requireChromeInCi('UI gate CLI');
      markTestSkipped('Chrome not installed');
      return;
    }
    final server = await fixtureServer();
    final root = Directory.systemTemp.createTempSync('gate_cli_');
    addTearDown(() => root.deleteSync(recursive: true));
    final records = Directory('${root.path}/records'), baselines = Directory('${root.path}/baselines');
    Future<ProcessResult> run(List<String> extra, {Map<String, String>? environment}) => Process.run(
      Platform.resolvedExecutable,
      ['run', 'tool/ui_gate.dart', '--records', records.path, '--baselines', baselines.path, ...extra],
      environment: {
        // The fixture writes its baselines under a disposable directory, including on CI.
        if (extra.contains('--record')) 'CI': 'false',
        ...?environment,
      },
    );
    final browsers = [
      'chrome',
      if (FirefoxDriver.locateFirefox() != null && FirefoxDriver.locateGeckodriver() != null) 'firefox',
    ];
    final defaults = [
      '--browsers',
      browsers.join(','),
      '--base',
      '${server.baseUrl}',
      'test/ui_gate_fixtures/pass.yaml',
    ];
    print('CLI: initial recording');
    final first = await run(['--record', '--captures', '${root.path}/captures', ...defaults]);
    expect(first.exitCode, 0, reason: '${first.stdout}${first.stderr}');
    final baseline = File('${baselines.path}/fixture.${Platform.operatingSystem}.json');
    expect(baseline.existsSync(), true, reason: 'one baseline per component and OS');
    expect(((jsonDecode(baseline.readAsStringSync()) as Map)['browsers'] as Map).keys, browsers);
    final capture = File('${root.path}/captures/fixture.chrome.json');
    expect(capture.existsSync(), true);
    expect((jsonDecode(capture.readAsStringSync()) as Map)['tokens'], isNotEmpty);
    final record = File('${records.path}/fixture.json');
    final data = (jsonDecode(record.readAsStringSync()) as Map).cast<String, Object?>();
    expect(data['automated'], 'pass');
    for (final item in automatedItems) {
      final value = (data['items'] as Map)[item] as Map;
      expect(value['status'], 'pass', reason: item);
      expect((value['browsers'] as Map).keys, browsers);
    }
    (data['items'] as Map)['safari'] = {
      'status': 'pass',
      'evidence': ['Manual Safari result'],
    };
    record.writeAsStringSync(encodeRecord(data));
    print('CLI: compare and preserve manual result');
    final second = await run(defaults);
    expect(second.exitCode, 0, reason: '${second.stdout}${second.stderr}');
    final bytes = record.readAsBytesSync();
    print('CLI: deterministic repeat');
    final third = await run(defaults);
    expect(third.exitCode, 0, reason: '${third.stdout}${third.stderr}');
    expect(record.readAsBytesSync(), bytes);
    expect(record.readAsStringSync(), contains('Manual Safari result'));
    expect(record.readAsStringSync(), isNot(contains(server.baseUrl.origin)));
    expect(record.readAsStringSync(), isNot(contains(root.path)));
    final source = File('test/ui_gate_fixtures/pass.yaml')
        .readAsStringSync()
        .replaceFirst('name: fixture', 'name: second')
        .replaceFirst('file: LICENSE', 'file: ${Directory.current.path}/test/ui_gate_fixtures/LICENSE');
    final secondManifest = File('${root.path}/second.yaml')..writeAsStringSync(source);
    print('CLI: data-only second component');
    final additional = await run([
      '--record',
      '--browsers',
      'chrome',
      '--base',
      '${server.baseUrl}',
      secondManifest.path,
    ]);
    expect(additional.exitCode, 0, reason: '${additional.stdout}${additional.stderr}');
    expect((jsonDecode(File('${records.path}/second.json').readAsStringSync()) as Map)['automated'], 'pass');
    final unlicensed = File('${root.path}/unlicensed.yaml')
      ..writeAsStringSync(
        source.replaceFirst('name: second', 'name: unlicensed').replaceFirst('license: MIT', 'license: Proprietary'),
      );
    print('CLI: failing provenance only');
    final provenance = await run(['--record', '--browsers', 'chrome', '--base', '${server.baseUrl}', unlicensed.path]);
    expect(provenance.exitCode, 1, reason: '${provenance.stdout}${provenance.stderr}');
    final provenanceRecord = jsonDecode(File('${records.path}/unlicensed.json').readAsStringSync()) as Map;
    for (final item in automatedItems) {
      final value = (provenanceRecord['items'] as Map)[item] as Map;
      expect(value['status'], item == 'provenance' ? 'fail' : 'pass', reason: item);
    }
    expect(provenanceRecord['automated'], 'fail');
    expect(provenanceRecord.toString(), contains('Proprietary'));
    expect(provenanceRecord.toString(), isNot(contains(Directory.current.path)));
    expect(provenanceRecord.toString(), isNot(contains(root.path)));
    final broken = File('${root.path}/broken.yaml')
      ..writeAsStringSync(
        source
            .replaceFirst('name: second', 'name: broken')
            .replaceFirst('page: /pass.html', 'page: /pass.html?defect=fine'),
      );
    final pidFile = File('${root.path}/server.pid');
    print('CLI: failing touch and server cleanup');
    final served = await run([
      '--record',
      '--browsers',
      'chrome',
      '--serve',
      "dart run test/ui_gate_fixtures/server.dart --pid '${pidFile.path}'",
      broken.path,
    ]);
    expect(served.exitCode, 1, reason: '${served.stdout}${served.stderr}');
    final failed = jsonDecode(File('${records.path}/broken.json').readAsStringSync()) as Map;
    expect(failed['automated'], 'fail');
    expect(((failed['items'] as Map)['touch-target'] as Map)['status'], 'fail');
    final process = await Process.run('ps', ['-p', pidFile.readAsStringSync(), '-o', 'pid=']);
    expect(process.exitCode, 1, reason: 'the --serve process must be stopped');
    print('CLI: unavailable browser and invalid inputs');
    final unavailable = await run(
      [...defaults, '--browsers', 'firefox'],
      environment: {'GECKODRIVER': '/missing', 'PATH': '/nonexistent'},
    );
    expect(unavailable.exitCode, 1);
    expect(unavailable.stdout, contains('not-run'));
    final unusableDriver = File('${root.path}/geckodriver')..writeAsStringSync('not an executable');
    final refused = await run(
      [...defaults, '--browsers', 'firefox'],
      environment: {'GECKODRIVER': unusableDriver.path},
    );
    expect(refused.exitCode, 1);
    expect(refused.stdout, contains('not-run'));
    expect(record.readAsStringSync(), isNot(contains(root.path)));
    final bad = File('${root.path}/bad.yaml')..writeAsStringSync('page: /pass.html\nroot: main\nunknown: true\n');
    final invalid = await run(['--base', '${server.baseUrl}', bad.path]);
    expect(invalid.exitCode, 1);
    expect(invalid.stderr, contains('unknown'));
    final ci = await run(['--record', ...defaults], environment: {'CI': 'true'});
    expect(ci.exitCode, 1);
    expect(ci.stderr, contains('refused'));
  }, timeout: Timeout(Duration(minutes: 8)));

  test('manifest', () async {
    final root = Directory.systemTemp.createTempSync('gate_manifest_');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/index.html').writeAsStringSync('<main><button>Test</button></main>');
    final file = File('${root.path}/test.yaml')..writeAsStringSync('page: /\nroot: main\nelements: {button: button}\n');
    final manifest = GateManifest.load(file);
    final server = await StaticSiteServer.serve(root);
    addTearDown(server.close);
    expect(await manifest.validatePage(server.baseUrl), contains('<button>'));
    file.writeAsStringSync('page: /\nroot: main\nunknown: true\n');
    expect(
      () => GateManifest.load(file),
      throwsA(isA<FormatException>().having((e) => e.message, 'field', contains('unknown'))),
    );
    file.writeAsStringSync('page: /missing\nroot: main\n');
    expect(
      () => GateManifest.load(file).validatePage(server.baseUrl),
      throwsA(isA<FormatException>().having((e) => e.message, 'field', contains('page'))),
    );
    file.writeAsStringSync("page: /\nroot: '['\n");
    expect(
      () => GateManifest.load(file),
      throwsA(isA<FormatException>().having((e) => e.message, 'field', contains('root'))),
    );
  });
}
