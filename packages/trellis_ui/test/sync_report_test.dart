import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../tool/src/sync_report.dart';

void main() {
  late Directory scratch;
  late String skeleton;

  setUp(() {
    scratch = Directory('../../.agent_temp').createTempSync('sync-report-test-');
    addTearDown(() => scratch.deleteSync(recursive: true));
    skeleton = buildSyncReport(_tree(scratch, 1), _tree(scratch, 2));
  });

  test('a fixture sync yields entries, breaking flag, token diff and revisit rows, identical twice', () {
    expect(buildSyncReport(_tree(scratch, 1), _tree(scratch, 2)), skeleton);
    expect(skeleton, contains('| `ui/button.tsx` | 1 | 1 | 1 | 1 |'));
    expect(skeleton, contains('BREAKING public class removed: `trellis-obsolete`'));
    expect(skeleton, contains('BREAKING public class removed: `trellis-old-hand`'));
    expect(skeleton, isNot(contains('BREAKING public class removed: `trellis-retained`')));
    expect(skeleton, contains('Slot added: `button-icon`'));
    expect(skeleton, contains('Data attribute added: `data-active`'));
    expect(skeleton, contains('Upstream component added: `slider`\n\nKind: new component\nTriage: pending'));
    expect(skeleton, contains('In-scope rule changed: `.cn-button`'));
    expect(skeleton, contains('Revisit structuralSkip `cn-button` (upstream changed)'));
    final tokenRows = skeleton.split('\n').where((line) => line.startsWith('| light') || line.startsWith('| dark'));
    expect(tokenRows, ['| light | `--primary` | #123 | #234 |', '| dark | `--primary` | #345 | #456 |']);
    expect(skeleton, isNot(contains('--radius')));
    expect(skeleton, isNot(contains(scratch.path)));
    final pending = RegExp(r'^### (U\d+)', multiLine: true).allMatches(skeleton).map((match) => match[1]!);
    expect(pending, hasLength(12));
    expect(syncReportIssues(skeleton), containsAll(pending.map((id) => '$id: unresolved triage')));
  });

  test(
    'check-report rejects pending triage, blank dispositions, reasonless deferrals and unexplained over-range edits',
    () {
      final valid = skeleton
          .replaceAll('Kind: new component\nTriage: pending', 'Kind: new component\nTriage: defer')
          .replaceAll('Triage: pending', 'Triage: mechanical')
          .replaceAll('Disposition: pending\nReason:', 'Disposition: expected\nReason: Reviewed the source change.')
          .replaceAll('Result: pending', 'Result: pass');
      expect(syncReportIssues(valid), isEmpty);
      expect(
        syncReportIssues(valid.replaceFirst('### Gate parity\n\nResult: pass', '### Gate parity\n\nResult: fail')),
        contains('Gate parity: unresolved disposition'),
      );
      expect(
        syncReportIssues(
          valid.replaceFirst(
            'Disposition: expected\nReason: Reviewed the source change.',
            'Disposition: deferred\nReason:',
          ),
        ),
        contains('U001: missing reason'),
      );
      for (final (label, count) in [('Template lines', 5), ('Hand CSS lines', 4), ('Config entries', 2)]) {
        final outOfRange = valid.replaceFirst('$label: 0', '$label: $count');
        expect(syncReportIssues(outOfRange).single, startsWith('$label: $count exceeds '));
        expect(
          syncReportIssues(outOfRange.replaceFirst('$label: $count', '$label: $count | Replaced changed hooks.')),
          isEmpty,
        );
      }
      final missing = valid.replaceFirst(RegExp(r'^### U001 [\s\S]*?(?=^### U002 )', multiLine: true), '');
      expect(syncReportIssues(missing), contains('Upstream entries: count or numbering does not match entries'));
      final unknown = valid.replaceFirst('Owner review: release-prep', 'Owner review: pending');
      expect(syncReportIssues(unknown), contains('Owner review: missing status'));
      final appearance = valid.replaceFirst(
        'Appearance entries: 0',
        'Appearance entries: 1\n\n### A001 button / firefox / hover / .trellis-button / color\n\n'
            'Disposition: expected\nReason: Upstream changed the hover paint.',
      );
      expect(syncReportIssues(appearance), isEmpty);
      expect(
        syncReportIssues(
          appearance.replaceFirst('Disposition: expected\nReason: Upstream', 'Disposition:\nReason: Upstream'),
        ),
        contains('A001: unresolved disposition'),
      );
    },
  );
}

SyncTree _tree(Directory scratch, int version) {
  final root = Directory('${scratch.path}/$version');
  final first = version == 1;
  final tag = 'shadcn@1.0.$version';
  final vendor = 'vendor/shadcn/$tag';
  void write(String path, String text) {
    final file = File('${root.path}/$path');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('$text\n');
  }

  write(
    'tool/pins.json',
    jsonEncode({
      'style': 'vega',
      'shadcn': {'tag': tag, 'commit': 'build-$version'},
      'components': ['button'],
      'structuralSkip': {
        'cn-button': {'from': 'shadcn@1.0.1', 'reason': 'Incompatible layout'},
      },
    }),
  );
  write(
    '$vendor/ui/button.tsx',
    first
        ? '<button data-slot="button" className={cn("cn-button cn-obsolete gap-2")} />'
        : '<button data-slot="button-icon" data-active="true" className={cn("cn-button gap-3")} />',
  );
  write('$vendor/style-vega.css', '.style-vega { .cn-button { @apply gap-$version; } }');
  write('$vendor/LICENSE.md', 'MIT');
  write('tool/parity-ignore.json', '[]');
  write(
    'generated/report.json',
    jsonEncode({
      'slots': ['button', if (!first) 'button-icon'],
      'dataAttrs': ['data-slot', if (!first) 'data-active'],
      'hooks': ['trellis-button', if (first) 'trellis-obsolete'],
    }),
  );
  write(
    'generated/entry.css',
    ':root { --radius: 4px; --primary: ${first ? '#123' : '#234'}; }\n'
        '.dark { --radius: 4px; --primary: ${first ? '#345' : '#456'}; }',
  );
  final css = '.trellis-button, .trellis-retained${first ? ', .trellis-obsolete' : ''} { color: var(--primary); }';
  write('generated/trellis.css', css);
  write('generated/trellis.min.css', css);
  write('assets/css/hand/button.css', first ? '.trellis-old-hand {}' : '/* .trellis-old-hand {} */');
  return SyncTree(root, {'button', if (!first) 'slider'});
}
