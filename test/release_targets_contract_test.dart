import 'dart:io';

import 'package:test/test.dart';

// The binary release targets, as dev/DECISIONS.md "No macos-x64 release" sets them. The workflow matrix,
// tool/verify_release.sh and the rendered Homebrew formula must each name exactly these, so a target added or
// dropped in one place cannot ship half-published.
const _targets = {'macos-arm64', 'linux-x64', 'linux-arm64', 'windows-x64'};

void main() {
  final root = _workspaceRoot();
  String read(String path) => File('${root.path}/$path').readAsStringSync();

  test('the release matrix builds exactly the release targets', () {
    final matrix = RegExp(
      r'^\s+target: (\S+)$',
      multiLine: true,
    ).allMatches(read('.github/workflows/release-binaries.yml')).map((m) => m[1]!).toSet();
    expect(matrix, _targets);
  });

  test('verify_release.sh checks an archive and checksum for every release target and no other', () {
    final assets = RegExp(
      r'"trellis-\$\{TAG\}-([a-z0-9]+-[a-z0-9]+)\.(?:tar\.gz|zip)"',
    ).allMatches(read('tool/verify_release.sh')).map((m) => m[1]!).toSet();
    expect(assets, _targets);
  });

  test('the Homebrew formula refuses an Intel Mac instead of pointing at a missing archive', () async {
    final temp = Directory.systemTemp.createTempSync('trellis-formula-');
    addTearDown(() => temp.deleteSync(recursive: true));
    for (final target in _targets.where((t) => !t.startsWith('windows'))) {
      File('${temp.path}/trellis-v9.9.9-$target.tar.gz.sha256').writeAsStringSync('${'a' * 64}  x\n');
    }
    final output = '${temp.path}/trellis.rb';
    final render = await Process.run(Platform.resolvedExecutable, [
      'run',
      'tool/render_homebrew_formula.dart',
      '--version',
      '9.9.9',
      '--checksums-dir',
      temp.path,
      '--repo',
      'owner/repo',
      '--output',
      output,
    ], workingDirectory: root.path);
    expect(render.exitCode, 0, reason: '${render.stdout}${render.stderr}');

    final formula = File(output).readAsStringSync();
    expect(formula, matches(RegExp(r'on_macos do\s*\n\s*depends_on arch: :arm64')));
    expect(formula, isNot(contains('macos-x64')));
    expect(formula, contains('trellis-v9.9.9-macos-arm64.tar.gz'));
  });
}

Directory _workspaceRoot() {
  var dir = Directory.current.absolute;
  while (!File('${dir.path}/.github/workflows/release-binaries.yml').existsSync()) {
    if (dir.parent.path == dir.path) throw StateError('workspace root not found from ${Directory.current.path}');
    dir = dir.parent;
  }
  return dir;
}
