import 'dart:io';

import 'package:test/test.dart';

import '../../../tool/ui_gate/checks.dart';
import '../../../tool/ui_gate/manifest.dart';
import '../../../tool/ui_gate/record.dart';
import '../../../tool/ui_gate/release_policy.dart';

void main() {
  final root = Directory.current.parent.parent;
  final policy = ComponentReleasePolicy.read(root);
  final gate = '${root.path}/dev/ui-gate';

  Map<String, Object?> record(String name) {
    final pass = {
      for (final item in automatedItems) item: const GateResult('pass', ['Observed a passing check']),
    };
    return gateRecord(name, {'chrome': pass, 'firefox': pass});
  }

  ComponentReleasePolicy disposition(String lines) =>
      ComponentReleasePolicy.parse('#### Optional component release dispositions\n```text\n$lines\n```\n');

  void manualFailure(Map<String, Object?> data, {List<String> evidence = const ['Focus did not return']}) {
    (data['items'] as Map)['safari'] = {'status': 'fail', 'evidence': evidence};
  }

  void automatedFailure(
    Map<String, Object?> data,
    String item, {
    String status = 'fail',
    List<String> evidence = const ['Interaction did not complete'],
  }) {
    data['automated'] = 'fail';
    final result = (data['items'] as Map)[item] as Map;
    result['status'] = status;
    (result['browsers'] as Map)['firefox'] = {'status': status, 'evidence': evidence};
  }

  test('every gallery page has a loadable manifest', () {
    expect(policy.inventoryIssues(root), isEmpty);
    for (final name in policy.activeComponents) {
      final manifest = GateManifest.load(File('$gate/manifests/$name.yaml'));
      expect(manifest.name, name);
      expect(manifest.page, '/components/$name');
      expect(manifest.keyboard, isNotEmpty, reason: name);
      expect(manifest.data['semantics'], isNotEmpty, reason: name);
      expect(manifest.htmx?['region'], '#demo');
      expect(manifest.htmx?['swap'], isNotEmpty, reason: name);
      expect(manifest.htmx?['navigate'], isNotEmpty, reason: name);
    }
  });

  test('a required component cannot ship with a failed manual item', () {
    final required = record('dialog');
    manualFailure(required);
    expect(
      disposition('').recordIssues('dialog', required),
      contains('dialog: safari failed without a release disposition'),
    );
    expect(() => disposition('dialog | unsupported | safari'), throwsFormatException);
  });

  test('alert-dialog keeps both browser checks and can be withdrawn for an observed failure', () {
    const safariFailure = 'alert-dialog | unsupported | safari';
    final alert = record('alert-dialog');
    manualFailure(alert);
    expect(disposition(safariFailure).recordIssues('alert-dialog', alert), isEmpty);

    final item = (alert['items'] as Map)['forced-colors'] as Map;
    (item['browsers'] as Map)['firefox'] = {
      'status': 'not-run',
      'evidence': ['Forced colors unavailable'],
      'unsupported': true,
    };
    expect(disposition(safariFailure).recordIssues('alert-dialog', alert), isEmpty);
  });

  for (final (name, app) in [('dialog', false), ('alert-dialog', false), ('badge', false), ('shelf-ui', true)]) {
    test('$name release record uses the unsupported emulation fallback', () {
      final release = disposition('');
      final data = record(name);
      final item = (data['items'] as Map)['forced-colors'] as Map;
      final browsers = item['browsers'] as Map;
      const unsupported = {
        'status': 'not-run',
        'evidence': ['Forced colors unavailable'],
        'unsupported': true,
      };
      browsers['firefox'] = unsupported;
      expect(release.recordIssues(name, data, app: app), isEmpty, reason: name);

      data['automated'] = 'fail';
      item['status'] = 'not-run';
      browsers['chrome'] = unsupported;
      expect(release.recordIssues(name, data, app: app), contains('$name: forced-colors did not run'));
      browsers['chrome'] = {
        'status': 'not-run',
        'evidence': ['Chrome could not start'],
      };
      expect(release.recordIssues(name, data, app: app), contains('$name: forced-colors/chrome did not run'));
      browsers.remove('chrome');
      expect(release.recordIssues(name, data, app: app), isNotEmpty);

      item['status'] = 'fail';
      browsers['chrome'] = {
        'status': 'fail',
        'evidence': ['Focus indicator disappeared'],
      };
      expect(
        release.recordIssues(name, data, app: app),
        contains('$name: forced-colors failed without a release disposition'),
      );
    });
  }

  test('optional manual and automated failures require the same named items and their evidence', () {
    final badge = record('badge');
    manualFailure(badge);
    automatedFailure(badge, 'keyboard');
    expect(disposition('').recordIssues('badge', badge), [
      'badge: safari failed without a release disposition',
      'badge: keyboard failed without a release disposition',
    ]);
    final accepted = disposition('badge | unsupported | keyboard, safari');
    expect(accepted.recordIssues('badge', badge), isEmpty);
    expect(accepted.activeComponents, contains('badge'));
    expect(accepted.recordIssues('badge', record('badge')), everyElement(contains('has no matching failure')));
    expect(disposition('badge | unsupported | safari').recordIssues('badge', badge), [
      'badge: keyboard failed without a release disposition',
    ]);
    manualFailure(badge, evidence: ['']);
    expect(accepted.recordIssues('badge', badge), ['badge: safari missing failure evidence']);
  });

  test('unavailable browsers, incomplete records and inconsistent verdicts cannot be accepted', () {
    final accepted = disposition('badge | unsupported | keyboard');
    final missingBrowser = record('badge');
    automatedFailure(missingBrowser, 'keyboard', status: 'not-run');
    expect(accepted.recordIssues('badge', missingBrowser), contains('badge: keyboard/firefox did not run'));

    final lostEvidence = record('badge');
    automatedFailure(lostEvidence, 'keyboard', evidence: []);
    expect(accepted.recordIssues('badge', lostEvidence), contains('badge: keyboard/firefox missing evidence'));
    ((lostEvidence['items'] as Map)['keyboard'] as Map)['status'] = 'pass';
    expect(accepted.recordIssues('badge', lostEvidence), contains('badge: keyboard inconsistent browser results'));
    (lostEvidence['items'] as Map).remove('visual');
    expect(accepted.recordIssues('badge', lostEvidence), ['badge: invalid gate record']);
  });

  test('an unknown component, a duplicate decision or an invalid item cannot be accepted', () {
    for (final invalid in [
      'shelf-home | removed | visual',
      'badge | unsupported | safari\nbadge | removed | safari',
      'badge | removed | safari, safari',
      'badge | removed | unknown',
      'badge | removed | ',
      'badge | skip | safari',
    ]) {
      expect(() => disposition(invalid), throwsFormatException, reason: invalid);
    }
  });

  test('manual results distinguish release prep from malformed evidence', () {
    final current = record('badge');
    final items = current['items'] as Map;
    expect(disposition('').recordIssues('badge', current), isEmpty);
    items['safari'] = {'status': 'released', 'evidence': <String>[]};
    items['screen-reader-voiceover-safari'] = {
      'status': 'pass',
      'evidence': [42],
    };
    items['screen-reader-nvda-firefox'] = {
      'status': 'not-run',
      'evidence': ['NVDA not available'],
    };
    expect(disposition('').recordIssues('badge', current), [
      'badge: screen-reader-voiceover-safari invalid manual result',
      'badge: safari invalid manual result',
    ]);
  });

  test('removal needs a retained failed record and withdrawal of the runnable subject', () {
    final scratchParent = Directory('${root.path}/.agent_temp')..createSync(recursive: true);
    final scratch = scratchParent.createTempSync('qualification-retirement-');
    addTearDown(() => scratch.deleteSync(recursive: true));
    File fixture(String path) => File('${scratch.path}/$path');
    for (final (folder, extension) in [
      ('dev/ui-gate/records', '.json'),
      ('dev/ui-gate/manifests', '.yaml'),
      ('packages/trellis_ui/gallery/pages', '.html'),
      ('packages/trellis_ui/assets/fragments', '.html'),
    ]) {
      for (final component in releaseComponents) {
        fixture('$folder/$component$extension').createSync(recursive: true);
      }
    }
    final active = disposition('');
    expect(active.inventoryIssues(scratch), isEmpty);

    final removed = disposition('badge | removed | safari');
    expect(removed.inventoryIssues(scratch), hasLength(3));
    fixture('dev/ui-gate/manifests/badge.yaml').deleteSync();
    fixture('packages/trellis_ui/gallery/pages/badge.html').deleteSync();
    fixture('packages/trellis_ui/assets/fragments/badge.html').deleteSync();
    expect(removed.activeComponents, isNot(contains('badge')));
    expect(active.inventoryIssues(scratch), hasLength(3));
    expect(removed.inventoryIssues(scratch), isEmpty);

    final badge = record('badge');
    manualFailure(badge);
    expect(removed.recordIssues('badge', badge), isEmpty);
    fixture('dev/ui-gate/records/badge.json').deleteSync();
    expect(removed.inventoryIssues(scratch), ['dev/ui-gate/records/badge.json: missing']);
  });
}
