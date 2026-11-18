import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('every command and path the skill names exists', () async {
    final root = Directory.current.parent.parent;
    final skill = File('${root.path}/.claude/skills/trellis-ui-sync/SKILL.md');
    final source = skill.readAsStringSync();
    final help = await Process.run(Platform.resolvedExecutable, ['run', 'tool/port.dart', '--help']);
    expect(help.exitCode, 0, reason: '${help.stderr}');
    final commands = RegExp(r'\bdart (?:run|test) ([\w/.-]+\.dart)(?: ([\w-]+))?').allMatches(source);
    expect(commands, hasLength(10));
    for (final command in commands) {
      final path = command[1]!;
      expect(File('${root.path}/$path').existsSync() || File(path).existsSync(), isTrue, reason: command[0]);
      if (path.endsWith('/port.dart')) {
        expect(help.stdout, contains(command[2]!), reason: command[0]);
      }
    }
    expect(help.stdout, contains('sync --check-report <file>'));
    for (final match in RegExp(r'`((?:packages|dev)/[\w/.-]+)`').allMatches(source)) {
      final path = match[1]!;
      expect(FileSystemEntity.typeSync('${root.path}/$path'), isNot(FileSystemEntityType.notFound), reason: path);
    }
    for (final match in RegExp(r'\]\((\.\./[^)#]+)').allMatches(source)) {
      expect(File('${skill.parent.path}/${match[1]}').existsSync(), isTrue, reason: match[1]);
    }
  });
}
