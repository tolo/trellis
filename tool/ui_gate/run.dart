import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'appearance.dart';
import 'checks.dart';
import 'driver.dart';
import 'firefox.dart';
import 'manifest.dart';

/// All automated items on one browser; exceptions are retained as evidence.
Future<Map<String, GateResult>> runGate(
  GateManifest manifest,
  Uri base,
  String browser, {
  required Directory baselines,
  bool record = false,
  Directory? captures,
}) async {
  if (record && Platform.environment['CI'] == 'true') throw StateError('recording baselines is refused when CI=true');
  final results = <String, GateResult>{};
  GateDriver? driver;
  try {
    driver = await switch (browser) {
      'chrome' => ChromeDriver.launch(),
      'firefox' => FirefoxDriver.launch(),
      _ => throw FormatException('unknown browser: $browser'),
    };
    final session = GateSession(manifest, driver, base);
    results['provenance'] = _provenance(manifest);
    results['semantic-markup'] = await session.semantics();
    results['keyboard'] = await session.keyboard();
    results['wcag-axe'] = await session.accessibility();
    results['htmx-lifecycle'] = await session.lifecycle();
    results['forced-colors'] = await session.forcedColors();
    results['responsive'] = await session.reflow([390, 768, 1440]);
    results['zoom'] = await session.reflow([640, 320]);
    results['reduced-motion'] = await session.reducedMotion();
    results['touch-target'] = await session.touchTargets();
    try {
      final baseline = File('${baselines.path}/${manifest.name}.${Platform.operatingSystem}.json');
      final appearance = await captureAppearance(
        session,
        comparePartial: record
            ? null
            : (appearance) {
                try {
                  return _compareBaseline(baseline, manifest.name, browser, appearance, partial: true);
                } on Object catch (error) {
                  throw VisualCaptureUnavailable(
                    session.normalize(error is FormatException ? error.message : '$error'),
                  );
                }
              },
      );
      final issues = (appearance['invariants'] as List).cast<String>().toList();
      if (captures != null) {
        captures.createSync(recursive: true);
        File('${captures.path}/${manifest.name}.$browser.json').writeAsStringSync(encodeCapture(appearance));
      }
      var compared = true;
      if (record) {
        if (issues.isEmpty) {
          final existing = baseline.existsSync() ? jsonDecode(baseline.readAsStringSync()) as Map : null;
          baseline.parent.createSync(recursive: true);
          final browsers = existing?['platform'] == Platform.operatingSystem
              ? (existing!['browsers'] as Map).cast<String, Object?>()
              : <String, Object?>{};
          browsers[browser] = appearance;
          baseline.writeAsStringSync(encodeCapture({'platform': Platform.operatingSystem, 'browsers': browsers}));
        }
      } else {
        try {
          issues.addAll(_compareBaseline(baseline, manifest.name, browser, appearance));
        } on Object catch (error) {
          // An unavailable comparison cannot serve as evidence of a component defect.
          compared = false;
          issues.add(session.normalize(error is FormatException ? error.message : '$error'));
        }
      }
      results['visual'] = GateResult(
        compared ? (issues.isEmpty ? 'pass' : 'fail') : 'not-run',
        issues.isEmpty
            ? ['${(appearance['states'] as Map).length} states captured; no clipping, overlap or appearance differences']
            : issues,
      );
    } on UnsupportedCondition catch (error) {
      results['visual'] = GateResult('not-run', [error.reason], unsupported: true);
    } on VisualCaptureUnavailable catch (error) {
      results['visual'] = GateResult('not-run', [error.reason]);
    } on FileSystemException catch (error) {
      results['visual'] = GateResult('not-run', [session.normalize('$error')]);
    } on Object catch (error) {
      results['visual'] = GateResult('fail', [session.normalize('$error')]);
    }
    results['strict-csp'] = await session.security();
    results['self-hosting'] = session.selfHosting();
  } on Object catch (error) {
    for (final item in automatedItems) {
      results.putIfAbsent(item, () => GateResult('not-run', ['$browser unavailable: ${_portable(error)}']));
    }
  } finally {
    await driver?.close();
  }
  return results;
}

List<String> _compareBaseline(
  File baseline,
  String name,
  String browser,
  Map<String, Object?> appearance, {
  bool partial = false,
}) {
  final platform = Platform.operatingSystem;
  final Object? existing;
  try {
    existing = jsonDecode(baseline.readAsStringSync());
  } on PathNotFoundException {
    // A browser with unsupported emulation may never have completed a baseline.
    if (partial) return const [];
    throw FormatException('no baseline for $name/$browser on $platform');
  }
  if (existing is! Map<String, Object?>) throw FormatException('invalid baseline for $name/$browser');
  if (existing['platform'] != platform) throw FormatException('baseline platform does not match $platform');
  final browsers = existing['browsers'];
  if (browsers is! Map<String, Object?>) throw FormatException('invalid browser captures in baseline for $name');
  if (!browsers.containsKey(browser)) {
    if (partial) return const [];
    throw FormatException('no $browser capture in baseline for $name');
  }
  final recorded = browsers[browser];
  if (recorded is! Map<String, Object?> || recorded['browser'] != browser) {
    throw FormatException('invalid $browser capture in baseline for $name');
  }
  return compareAppearance(recorded, appearance, partial: partial);
}

GateResult _provenance(GateManifest manifest) {
  final evidence = <String>[];
  final notices = manifest.data['provenance'] as List? ?? const [];
  for (final raw in notices) {
    final notice = raw as Map, license = notice['license'] as String;
    final allowed =
        {'MIT', 'ISC', 'Apache-2.0', '0BSD'}.contains(license) || RegExp(r'^BSD-\d-Clause$').hasMatch(license);
    final file = File(manifest.resolveFile(notice['file'] as String));
    if (!allowed || !file.existsSync() || file.readAsStringSync().trim().isEmpty) {
      final declared = notice['file'] as String;
      final label = p.isAbsolute(declared) ? p.basename(declared) : declared;
      evidence.add('invalid/missing provenance $label ($license)');
    }
  }
  if (notices.isEmpty) evidence.add('no provenance notice declared');
  return GateResult(
    evidence.isEmpty ? 'pass' : 'fail',
    evidence.isEmpty ? ['${notices.length} declared permissive notices exist'] : evidence,
  );
}

String _portable(Object error) {
  final value = error is ProcessException
      ? 'could not start ${p.basename(error.executable)}: ${error.message}'
      : '$error';
  return value
      .replaceAll(Directory.current.path, '<project>')
      .replaceAll(RegExp(r'127\.0\.0\.1:\d+'), '127.0.0.1:<port>');
}

String encodeCapture(Map<String, Object?> value) => '${const JsonEncoder.withIndent('  ').convert(value)}\n';
