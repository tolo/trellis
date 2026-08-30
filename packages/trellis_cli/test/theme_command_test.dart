import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_cli/src/commands/theme_add_command.dart';
import 'package:trellis_cli/src/commands/theme_update_command.dart';
import 'package:trellis_cli/trellis_cli.dart';
import 'package:trellis_cli/src/theme_config_updater.dart';

/// Captures `dart:io` [stderr] writes during [body]. The theme commands write
/// error messages straight to stderr (no injectable sink), so `IOOverrides` is
/// the only capture seam. A minimal [Stdout] fake avoids implementing the full
/// interface via `noSuchMethod`.
Future<String> _captureStderr(Future<void> Function() body) async {
  final buffer = StringBuffer();
  await IOOverrides.runZoned(body, stderr: () => _BufferStdout(buffer));
  return buffer.toString();
}

/// Captures `dart:io` [stdout] writes during [body]. The theme commands write
/// notices (e.g. skipped-symlink warnings) straight to stdout, so `IOOverrides`
/// is the capture seam, mirroring [_captureStderr].
Future<String> _captureStdout(Future<void> Function() body) async {
  final buffer = StringBuffer();
  await IOOverrides.runZoned(body, stdout: () => _BufferStdout(buffer));
  return buffer.toString();
}

/// Redirects [Directory.systemTemp] into a sandbox and captures [stderr], so a
/// test can assert both the message and that no temporary clone survived.
final class _SandboxOverrides extends IOOverrides {
  _SandboxOverrides({required this.sandbox, required this.errorBuffer});

  final Directory sandbox;
  final StringBuffer errorBuffer;

  @override
  Directory getSystemTempDirectory() => sandbox;

  @override
  Stdout get stderr => _BufferStdout(errorBuffer);
}

class _BufferStdout implements Stdout {
  _BufferStdout(this._buffer);

  final StringBuffer _buffer;

  @override
  void writeln([Object? object = '']) => _buffer.writeln(object);

  @override
  void write(Object? object) => _buffer.write(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('trellis_theme_cmd_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  /// Creates a minimal `trellis_site.yaml` in the current temp directory.
  void writeConfig({String? theme, String? themeRef, Map<String, String>? themeParams}) {
    final buf = StringBuffer('title: Test Site\nbaseUrl: https://example.com\n');
    if (theme != null) buf.writeln('theme: $theme');
    if (themeRef != null) buf.writeln('theme_ref: $themeRef');
    if (themeParams != null) {
      buf.writeln('theme_params:');
      for (final entry in themeParams.entries) {
        buf.writeln('  ${entry.key}: ${entry.value}');
      }
    }
    File(p.join(tempDir.path, 'trellis_site.yaml')).writeAsStringSync(buf.toString());
  }

  /// Creates a minimal valid theme directory with a `theme.yaml`.
  Directory writeTheme(
    String name, {
    String version = '1.0.0',
    String? minTrellisVersion,
    String? author,
    Map<String, dynamic>? params,
    bool inThemesDir = true,
  }) {
    final dir = inThemesDir ? Directory(p.join(tempDir.path, 'themes', name)) : Directory(p.join(tempDir.path, name));
    dir.createSync(recursive: true);

    final buf = StringBuffer('name: $name\nversion: $version\n');
    if (minTrellisVersion != null) buf.writeln('min_trellis_version: $minTrellisVersion');
    if (author != null) buf.writeln('author: $author');
    if (params != null) {
      buf.writeln('params:');
      for (final entry in params.entries) {
        buf.writeln('  ${entry.key}: ${entry.value}');
      }
    }
    File(p.join(dir.path, 'theme.yaml')).writeAsStringSync(buf.toString());
    return dir;
  }

  /// Writes `<dir>/layouts/<relative>` — used to give a site or a theme layouts
  /// at colliding paths.
  void writeLayout(Directory dir, String relative) {
    final file = File(p.join(dir.path, 'layouts', relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('<html></html>');
  }

  Future<int> run(List<String> args) => TrellisCli(workingDirectory: tempDir.path).run(args);

  Future<int> runSingleCommand(Command<int> command, List<String> args) {
    final runner = CommandRunner<int>('trellis', 'test')..addCommand(command);
    return runner.run(args).then((code) => code ?? 0);
  }

  /// Runs `git` inside [repo], failing the test on a non-zero exit.
  Future<void> git(Directory repo, List<String> args) async {
    final result = await Process.run('git', <String>[
      '-c',
      'user.email=test@example.com',
      '-c',
      'user.name=Trellis Test',
      ...args,
    ], workingDirectory: repo.path);
    expect(result.exitCode, 0, reason: 'git ${args.join(' ')} failed: ${result.stderr}');
  }

  /// Builds a multi-theme repository (`themes/<name>/theme.yaml` per entry) and
  /// returns its `file://` URL, which `theme add` treats as a git remote.
  Future<String> writeMultiThemeRepo(List<String> names, {String marker = 'v1', String? minTrellisVersion}) async {
    final repo = Directory(p.join(tempDir.path, 'monorepo'))..createSync(recursive: true);
    await git(repo, <String>['init', '-b', 'main']);
    for (final name in names) {
      final themeDir = Directory(p.join(repo.path, 'themes', name))..createSync(recursive: true);
      File(p.join(themeDir.path, 'theme.yaml')).writeAsStringSync(
        'name: $name\nversion: 1.0.0\n'
        '${minTrellisVersion == null ? '' : 'min_trellis_version: $minTrellisVersion\n'}',
      );
      File(p.join(themeDir.path, 'marker.txt')).writeAsStringSync(marker);
    }
    File(p.join(repo.path, 'README.md')).writeAsStringSync('# monorepo\n');
    await git(repo, <String>['add', '-A']);
    await git(repo, <String>['commit', '-m', 'themes']);
    return Uri.file(repo.path).toString();
  }

  // ─── ThemeConfigUpdater ───────────────────────────────────────────────────

  group('ThemeConfigUpdater', () {
    test('setTheme() appends theme: when not present', () {
      writeConfig();
      final configPath = p.join(tempDir.path, 'trellis_site.yaml');
      final updater = ThemeConfigUpdater(configPath);
      updater.setTheme('verdant');

      final content = File(configPath).readAsStringSync();
      expect(content, contains('theme: verdant'));
    });

    test('setTheme() replaces existing theme: value', () {
      writeConfig(theme: 'old-theme');
      final configPath = p.join(tempDir.path, 'trellis_site.yaml');
      final updater = ThemeConfigUpdater(configPath);
      updater.setTheme('new-theme');

      final content = File(configPath).readAsStringSync();
      expect(content, contains('theme: new-theme'));
      expect(content, isNot(contains('theme: old-theme')));
    });

    test('setTheme() with ref adds theme_ref:', () {
      writeConfig();
      final configPath = p.join(tempDir.path, 'trellis_site.yaml');
      final updater = ThemeConfigUpdater(configPath);
      updater.setTheme('verdant', ref: 'v1.0.0');

      final content = File(configPath).readAsStringSync();
      expect(content, contains('theme: verdant'));
      expect(content, contains('theme_ref: v1.0.0'));
    });

    test('clearTheme() removes theme: and theme_ref: lines', () {
      writeConfig(theme: 'verdant', themeRef: 'v1.0.0');
      final configPath = p.join(tempDir.path, 'trellis_site.yaml');
      final updater = ThemeConfigUpdater(configPath);
      updater.clearTheme();

      final content = File(configPath).readAsStringSync();
      expect(content, isNot(contains('theme:')));
      expect(content, isNot(contains('theme_ref:')));
    });

    test('clearTheme() leaves theme_params: intact', () {
      writeConfig(theme: 'verdant', themeParams: {'primary_color': '#fff'});
      final configPath = p.join(tempDir.path, 'trellis_site.yaml');
      final updater = ThemeConfigUpdater(configPath);
      updater.clearTheme();

      final content = File(configPath).readAsStringSync();
      expect(content, isNot(contains('theme: verdant')));
      expect(content, contains('theme_params:'));
      expect(content, contains('primary_color: #fff'));
    });

    test('setTheme() preserves surrounding content and comments', () {
      File(p.join(tempDir.path, 'trellis_site.yaml')).writeAsStringSync('# My site\ntitle: Test\n# theme config\n');
      final configPath = p.join(tempDir.path, 'trellis_site.yaml');
      final updater = ThemeConfigUpdater(configPath);
      updater.setTheme('verdant');

      final content = File(configPath).readAsStringSync();
      expect(content, contains('# My site'));
      expect(content, contains('# theme config'));
      expect(content, contains('theme: verdant'));
    });
  });

  // ─── trellis theme add (local path) ──────────────────────────────────────

  group('trellis theme add (local path)', () {
    test('copies local theme directory into themes/', () async {
      writeConfig();
      final localTheme = writeTheme('my-theme', inThemesDir: false);

      final exitCode = await run(['theme', 'add', localTheme.path]);
      expect(exitCode, 0);
      expect(Directory(p.join(tempDir.path, 'themes', 'my-theme')).existsSync(), isTrue);
      expect(File(p.join(tempDir.path, 'themes', 'my-theme', 'theme.yaml')).existsSync(), isTrue);
    });

    test('sets theme: in trellis_site.yaml after local add', () async {
      writeConfig();
      final localTheme = writeTheme('my-theme', inThemesDir: false);

      await run(['theme', 'add', localTheme.path]);

      final content = File(p.join(tempDir.path, 'trellis_site.yaml')).readAsStringSync();
      expect(content, contains('theme: my-theme'));
    });

    test('already installed local theme produces error', () async {
      writeConfig();
      final localTheme = writeTheme('my-theme', inThemesDir: false);
      writeTheme('my-theme'); // already in themes/

      final exitCode = await run(['theme', 'add', localTheme.path]);
      expect(exitCode, 1);
    });

    test('nonexistent local path produces error', () async {
      writeConfig();
      final exitCode = await run(['theme', 'add', './nonexistent-path']);
      expect(exitCode, 1);
    });

    test('invalid manifest after copy cleans up and returns error', () async {
      writeConfig();
      // Create a local dir with invalid theme.yaml
      final badThemeDir = Directory(p.join(tempDir.path, 'bad-theme'))..createSync();
      File(p.join(badThemeDir.path, 'theme.yaml')).writeAsStringSync('not: valid: yaml: [');

      final exitCode = await run(['theme', 'add', badThemeDir.path]);
      expect(exitCode, 1);
      // Cleaned up
      expect(Directory(p.join(tempDir.path, 'themes', 'bad-theme')).existsSync(), isFalse);
    });

    test('no args produces usage error', () async {
      writeConfig();
      expect(() => run(['theme', 'add']), throwsA(isA<UsageException>()));
    });

    test('excludes .git directory from copy', () async {
      writeConfig();
      final localTheme = writeTheme('my-theme', inThemesDir: false);
      Directory(p.join(localTheme.path, '.git')).createSync();
      File(p.join(localTheme.path, '.git', 'HEAD')).writeAsStringSync('ref: refs/heads/main\n');

      await run(['theme', 'add', localTheme.path]);

      expect(Directory(p.join(tempDir.path, 'themes', 'my-theme', '.git')).existsSync(), isFalse);
    });

    test('no trellis_site.yaml produces error', () async {
      final localTheme = writeTheme('my-theme', inThemesDir: false);
      final exitCode = await run(['theme', 'add', localTheme.path]);
      expect(exitCode, 1);
    });

    test('invalid site config fails before installing or rewriting the theme', () async {
      final config = File(p.join(tempDir.path, 'trellis_site.yaml'))..writeAsStringSync('title: 2026\n');
      final originalConfig = config.readAsBytesSync();
      final localTheme = writeTheme('my-theme', inThemesDir: false);

      late int exitCode;
      final stderrText = await _captureStderr(() async {
        exitCode = await run(['theme', 'add', localTheme.path]);
      });

      expect(exitCode, 1);
      expect(stderrText, contains('title'));
      expect(config.readAsBytesSync(), originalConfig);
      expect(Directory(p.join(tempDir.path, 'themes')).existsSync(), isFalse);
    });

    test('config write failure removes the installed theme and preserves the config', () async {
      writeConfig();
      final config = File(p.join(tempDir.path, 'trellis_site.yaml'));
      final originalConfig = config.readAsBytesSync();
      Directory('${config.path}.trellis.tmp').createSync();
      final localTheme = writeTheme('my-theme', inThemesDir: false);

      late int exitCode;
      final stderrText = await _captureStderr(() async {
        exitCode = await run(['theme', 'add', localTheme.path]);
      });

      expect(exitCode, 1);
      expect(stderrText, contains('Could not update trellis_site.yaml'));
      expect(config.readAsBytesSync(), originalConfig);
      expect(Directory(p.join(tempDir.path, 'themes', 'my-theme')).existsSync(), isFalse);
    });

    test('missing git returns actionable error code for git URL', () async {
      writeConfig();
      var invokedGit = false;
      final command = ThemeAddCommand(
        workingDirectory: tempDir.path,
        processRunner: (executable, arguments) {
          invokedGit = executable == 'git';
          throw const ProcessException('git', ['clone'], 'No such file or directory', 2);
        },
      );

      late int exitCode;
      final stderrText = await _captureStderr(() async {
        exitCode = await runSingleCommand(command, ['add', 'https://github.com/example/trellis-theme-oak.git']);
      });

      expect(exitCode, 1);
      expect(invokedGit, isTrue);
      expect(stderrText, contains('git is required'));
      expect(Directory(p.join(tempDir.path, 'themes', 'oak')).existsSync(), isFalse);
    });

    test('rejects an unsafe theme name derived from a git URL before cloning', () async {
      writeConfig();
      var invokedGit = false;
      final command = ThemeAddCommand(
        workingDirectory: tempDir.path,
        processRunner: (executable, arguments) async {
          invokedGit = true;
          return ProcessResult(0, 0, '', '');
        },
      );

      late int exitCode;
      final stderrText = await _captureStderr(() async {
        exitCode = await runSingleCommand(command, ['add', r'git@evil.host:r/..\..\evil']);
      });

      expect(exitCode, 1);
      expect(invokedGit, isFalse, reason: 'the derived directory name must be validated before clone');
      expect(stderrText, contains('is not valid'));
      expect(Directory(p.join(tempDir.path, 'themes', r'..\..\evil')).existsSync(), isFalse);
    });

    test('warns when a locally added theme requires a newer Trellis version', () async {
      writeConfig();
      final localTheme = writeTheme('future-theme', minTrellisVersion: '99.0.0', inThemesDir: false);

      late int exitCode;
      final stderrText = await _captureStderr(() async {
        exitCode = await run(['theme', 'add', localTheme.path]);
      });

      expect(exitCode, 0, reason: 'compatibility is advisory at install time');
      expect(stderrText, allOf(contains('requires trellis_site >=99.0.0'), contains('installed version is')));
    });

    test('non-missing-git ProcessException returns 1 without escaping', () async {
      writeConfig();
      final command = ThemeAddCommand(
        workingDirectory: tempDir.path,
        // errorCode 13 == EACCES: a genuine spawn failure, not missing git.
        processRunner: (executable, arguments) {
          throw const ProcessException('git', ['clone'], 'Permission denied', 13);
        },
      );

      late int exitCode;
      final stderrText = await _captureStderr(() async {
        exitCode = await runSingleCommand(command, ['add', 'https://github.com/example/trellis-theme-oak.git']);
      });

      expect(exitCode, 1);
      expect(stderrText, contains('git command failed'));
    });

    test('skips self-referential symlinks when copying local theme', () async {
      writeConfig();
      final localTheme = writeTheme('my-theme', inThemesDir: false);
      // Mirror the official themes' example scaffolding: a self-referential
      // symlink (example/self → theme root) that would recurse unboundedly if
      // followed.
      final exampleDir = Directory(p.join(localTheme.path, 'example'))..createSync();
      try {
        Link(p.join(exampleDir.path, 'self')).createSync(localTheme.path);
      } on FileSystemException {
        markTestSkipped('symlink creation not permitted on this platform');
        return;
      }

      late int exitCode;
      final stdoutText = await _captureStdout(() async {
        exitCode = await run(['theme', 'add', localTheme.path]);
      });

      expect(exitCode, 0);
      final installed = Directory(p.join(tempDir.path, 'themes', 'my-theme'));
      expect(installed.existsSync(), isTrue);
      expect(File(p.join(installed.path, 'theme.yaml')).existsSync(), isTrue);
      // The cyclic symlink must not be materialized or recursed into.
      final copiedSelf = p.join(installed.path, 'example', 'self');
      expect(FileSystemEntity.isLinkSync(copiedSelf), isFalse);
      expect(Directory(copiedSelf).existsSync(), isFalse);
      // The skip is surfaced to the user, not silent.
      expect(stdoutText, contains('Skipped symlink:'));
    });

    // A blog scaffold ships the same layouts a theme does, so installing a theme
    // over it leaves the theme fully shadowed and the site unstyled. The install
    // must still succeed — overriding layouts is supported — but say so.
    test('warns and names every site layout that shadows the installed theme', () async {
      writeConfig();
      final localTheme = writeTheme('my-theme', inThemesDir: false);
      writeLayout(localTheme, 'base.html');
      writeLayout(localTheme, '_default/single.html');
      writeLayout(tempDir, 'base.html');
      writeLayout(tempDir, '_default/single.html');

      late int exitCode;
      final stderrText = await _captureStderr(() async {
        exitCode = await run(['theme', 'add', localTheme.path]);
      });

      expect(exitCode, 0, reason: 'shadowing is a warning, not an install failure');
      expect(Directory(p.join(tempDir.path, 'themes', 'my-theme')).existsSync(), isTrue);
      expect(stderrText, contains('Layouts resolve site-first'));
      expect(stderrText, contains(p.join('layouts', 'base.html')));
      expect(stderrText, contains(p.join('layouts', '_default', 'single.html')));
    });

    test('stays silent when no site layout collides with the theme', () async {
      writeConfig();
      final localTheme = writeTheme('my-theme', inThemesDir: false);
      writeLayout(localTheme, 'base.html');
      writeLayout(localTheme, '_default/single.html');
      // Site layout at a path the theme does not provide: nothing is shadowed.
      writeLayout(tempDir, 'posts/single.html');

      late int exitCode;
      final stderrText = await _captureStderr(() async {
        exitCode = await run(['theme', 'add', localTheme.path]);
      });

      expect(exitCode, 0);
      expect(stderrText, isEmpty);
    });
  });

  // ─── trellis theme add --theme (multi-theme source) ──────────────────────

  group('trellis theme add --theme', () {
    /// Runs `theme add` with [Directory.systemTemp] pointed at a sandbox, and
    /// asserts the sandbox is empty afterwards — the clone must not survive the
    /// command on any path.
    Future<({int exitCode, String errorOutput})> addSandboxed(List<String> args) async {
      final sandbox = Directory(p.join(tempDir.path, 'io-temp'))..createSync(recursive: true);
      final buffer = StringBuffer();
      late int exitCode;
      await IOOverrides.runWithIOOverrides(() async {
        exitCode = await run(<String>['theme', 'add', ...args]);
      }, _SandboxOverrides(sandbox: sandbox, errorBuffer: buffer));
      expect(sandbox.listSync(), isEmpty, reason: 'theme add left a temporary clone behind');
      return (exitCode: exitCode, errorOutput: buffer.toString());
    }

    test('installs only the named subdirectory from a multi-theme repository', () async {
      writeConfig();
      final url = await writeMultiThemeRepo(<String>['lattice', 'folio']);

      final result = await addSandboxed(<String>[url, '--theme', 'lattice']);

      expect(result.exitCode, 0);
      expect(File(p.join(tempDir.path, 'themes', 'lattice', 'theme.yaml')).existsSync(), isTrue);
      // The sibling theme and the repository root stay out of the site: the
      // install must be the theme, not the repo that carries it.
      expect(Directory(p.join(tempDir.path, 'themes', 'folio')).existsSync(), isFalse);
      expect(Directory(p.join(tempDir.path, 'themes', 'lattice', 'themes')).existsSync(), isFalse);
      expect(File(p.join(tempDir.path, 'themes', 'lattice', 'README.md')).existsSync(), isFalse);
      expect(File(p.join(tempDir.path, 'trellis_site.yaml')).readAsStringSync(), contains('theme: lattice'));
    });

    test('warns when a subdirectory theme requires a newer Trellis version', () async {
      writeConfig();
      final url = await writeMultiThemeRepo(<String>['future-theme'], minTrellisVersion: '99.0.0');

      final result = await addSandboxed(<String>[url, '--theme', 'future-theme']);

      expect(result.exitCode, 0, reason: 'compatibility is advisory at install time');
      expect(result.errorOutput, allOf(contains('requires trellis_site >=99.0.0'), contains('installed version is')));
    });

    test('--ref pins the subdirectory install to a tag', () async {
      writeConfig();
      final url = await writeMultiThemeRepo(<String>['lattice']);
      final repo = Directory(p.join(tempDir.path, 'monorepo'));
      await git(repo, <String>['tag', 'v1.0.0']);
      File(p.join(repo.path, 'themes', 'lattice', 'marker.txt')).writeAsStringSync('v2');
      await git(repo, <String>['add', '-A']);
      await git(repo, <String>['commit', '-m', 'second']);

      final result = await addSandboxed(<String>[url, '--theme', 'lattice', '--ref', 'v1.0.0']);

      expect(result.exitCode, 0);
      expect(File(p.join(tempDir.path, 'themes', 'lattice', 'marker.txt')).readAsStringSync(), 'v1');
      expect(File(p.join(tempDir.path, 'trellis_site.yaml')).readAsStringSync(), contains('theme_ref: v1.0.0'));
    });

    test('a subdirectory that does not exist fails with an actionable, theme-naming error', () async {
      writeConfig();
      final url = await writeMultiThemeRepo(<String>['lattice']);

      final result = await addSandboxed(<String>[url, '--theme', 'nosuch']);

      expect(result.exitCode, 1);
      expect(result.errorOutput, allOf(contains("'nosuch'"), contains('themes/nosuch/theme.yaml')));
      expect(Directory(p.join(tempDir.path, 'themes', 'nosuch')).existsSync(), isFalse);
    });

    test('a traversal or absolute --theme value is rejected before any clone', () async {
      Set<String> treeOf(Directory dir) => dir
          .listSync(recursive: true, followLinks: false)
          .map((entity) => p.relative(entity.path, from: dir.path))
          .toSet();

      for (final payload in <String>['../../etc', '/etc/passwd', 'a/../../b', '..']) {
        writeConfig();
        final before = treeOf(tempDir);
        var invokedGit = false;
        final command = ThemeAddCommand(
          workingDirectory: tempDir.path,
          processRunner: (executable, arguments) async {
            invokedGit = true;
            return ProcessResult(0, 0, '', '');
          },
        );

        late int exitCode;
        final stderrText = await _captureStderr(() async {
          exitCode = await runSingleCommand(command, <String>[
            'add',
            'https://github.com/tolo/trellis',
            '--theme',
            payload,
          ]);
        });

        expect(exitCode, 1, reason: payload);
        expect(invokedGit, isFalse, reason: 'cloning before validating $payload wastes work and widens the surface');
        expect(stderrText, contains('is not valid'), reason: payload);
        // Nothing materialized anywhere under the site — an empty `themes/` is
        // the only directory the command is allowed to have created.
        expect(treeOf(tempDir).difference(before).where((path) => path != 'themes'), isEmpty, reason: payload);
      }
    });

    test('installs from a local multi-theme checkout', () async {
      writeConfig();
      final checkout = Directory(p.join(tempDir.path, 'checkout'));
      final themeDir = Directory(p.join(checkout.path, 'themes', 'meadow'))..createSync(recursive: true);
      File(p.join(themeDir.path, 'theme.yaml')).writeAsStringSync('name: meadow\nversion: 1.0.0\n');

      final exitCode = await run(<String>['theme', 'add', checkout.path, '--theme', 'meadow']);

      expect(exitCode, 0);
      expect(File(p.join(tempDir.path, 'themes', 'meadow', 'theme.yaml')).existsSync(), isTrue);
      expect(File(p.join(tempDir.path, 'trellis_site.yaml')).readAsStringSync(), contains('theme: meadow'));
    });

    /// Builds `<root>/themes/<name>` as a symlink to [target] and returns
    /// `<root>`, or null when the platform refuses symlink creation.
    Directory? writeSymlinkedThemeSource(String root, String name, Directory target) {
      final source = Directory(p.join(tempDir.path, root, 'themes'))..createSync(recursive: true);
      try {
        Link(p.join(source.path, name)).createSync(target.path);
      } on FileSystemException {
        markTestSkipped('symlink creation not permitted on this platform');
        return null;
      }
      return source.parent;
    }

    /// A theme directory outside every install source, standing in for whatever
    /// an escaping symlink points at (`~/.ssh`, a sibling checkout, `/etc`).
    Directory writeOutsideTheme(String name) {
      final dir = Directory(p.join(tempDir.path, 'outside', 'themes', name))..createSync(recursive: true);
      File(p.join(dir.path, 'theme.yaml')).writeAsStringSync('name: $name\nversion: 1.0.0\n');
      File(p.join(dir.path, 'secret.txt')).writeAsStringSync('originated outside the source');
      return dir;
    }

    test('a themes/<name> symlink out of a local source is rejected, and copies nothing', () async {
      writeConfig();
      final outside = writeOutsideTheme('evil');
      final source = writeSymlinkedThemeSource('checkout', 'evil', outside);
      if (source == null) return;

      late int exitCode;
      final stderrText = await _captureStderr(() async {
        exitCode = await run(<String>['theme', 'add', source.path, '--theme', 'evil']);
      });

      expect(exitCode, 1);
      expect(stderrText, contains("Theme path 'themes/evil' escapes"));
      // The message is not the contract — nothing from outside the source may
      // reach the site, as a symlink or (worse) as a real file `trellis build`
      // would then publish out of `themes/evil/static/`.
      expect(Directory(p.join(tempDir.path, 'themes', 'evil')).existsSync(), isFalse);
      expect(File(p.join(tempDir.path, 'themes', 'evil', 'secret.txt')).existsSync(), isFalse);
      expect(File(p.join(tempDir.path, 'trellis_site.yaml')).readAsStringSync(), isNot(contains('theme: evil')));
    });

    test('a themes/<name> symlink out of a cloned repository is rejected, and copies nothing', () async {
      writeConfig();
      final outside = writeOutsideTheme('evil');
      // git stores the literal link target, so an absolute symlink survives the
      // clone and still points outside it wherever the clone lands.
      final source = writeSymlinkedThemeSource('monorepo', 'evil', outside);
      if (source == null) return;
      await git(source, <String>['init', '-b', 'main']);
      await git(source, <String>['add', '-A']);
      await git(source, <String>['commit', '-m', 'themes']);

      final result = await addSandboxed(<String>[Uri.file(source.path).toString(), '--theme', 'evil']);

      expect(result.exitCode, 1);
      expect(result.errorOutput, contains("Theme path 'themes/evil' escapes"));
      expect(Directory(p.join(tempDir.path, 'themes', 'evil')).existsSync(), isFalse);
      expect(File(p.join(tempDir.path, 'themes', 'evil', 'secret.txt')).existsSync(), isFalse);
    });

    test('a themes/<name> symlink that stays inside the source still installs', () async {
      writeConfig();
      // Containment is the rule, not "no symlinks": a multi-theme repo may well
      // point themes/<name> at a sibling directory it also ships.
      final vendored = Directory(p.join(tempDir.path, 'checkout', 'vendor', 'orchard'))..createSync(recursive: true);
      File(p.join(vendored.path, 'theme.yaml')).writeAsStringSync('name: orchard\nversion: 1.0.0\n');
      final source = writeSymlinkedThemeSource('checkout', 'orchard', vendored);
      if (source == null) return;

      final exitCode = await run(<String>['theme', 'add', source.path, '--theme', 'orchard']);

      expect(exitCode, 0);
      expect(File(p.join(tempDir.path, 'themes', 'orchard', 'theme.yaml')).existsSync(), isTrue);
    });
  });

  // ─── trellis theme update ─────────────────────────────────────────────────

  group('trellis theme update', () {
    test('no theme specified and no active theme → error', () async {
      writeConfig(); // no theme:
      final exitCode = await run(['theme', 'update']);
      expect(exitCode, 1);
    });

    test('theme not found → error', () async {
      writeConfig(theme: 'missing-theme');
      final exitCode = await run(['theme', 'update', 'missing-theme']);
      expect(exitCode, 1);
    });

    test('theme not a git repo → error', () async {
      writeConfig(theme: 'my-theme');
      writeTheme('my-theme'); // no .git directory

      final exitCode = await run(['theme', 'update', 'my-theme']);
      expect(exitCode, 1);
    });

    test('no trellis_site.yaml → error', () async {
      final exitCode = await run(['theme', 'update']);
      expect(exitCode, 1);
    });

    test('missing git returns actionable error code for git theme update', () async {
      writeConfig(theme: 'my-theme');
      final theme = writeTheme('my-theme');
      Directory(p.join(theme.path, '.git')).createSync();
      var invokedGit = false;
      final command = ThemeUpdateCommand(
        workingDirectory: tempDir.path,
        processRunner: (executable, arguments) {
          invokedGit = executable == 'git';
          throw const ProcessException('git', ['pull'], 'No such file or directory', 2);
        },
      );

      late int exitCode;
      final stderrText = await _captureStderr(() async {
        exitCode = await runSingleCommand(command, ['update', 'my-theme']);
      });

      expect(exitCode, 1);
      expect(invokedGit, isTrue);
      expect(stderrText, contains('git is required'));
    });

    test('non-missing-git ProcessException returns 1 without escaping', () async {
      writeConfig(theme: 'my-theme');
      final theme = writeTheme('my-theme');
      Directory(p.join(theme.path, '.git')).createSync();
      final command = ThemeUpdateCommand(
        workingDirectory: tempDir.path,
        // errorCode 13 == EACCES: a genuine spawn failure, not missing git.
        processRunner: (executable, arguments) {
          throw const ProcessException('git', ['pull'], 'Permission denied', 13);
        },
      );

      late int exitCode;
      final stderrText = await _captureStderr(() async {
        exitCode = await runSingleCommand(command, ['update', 'my-theme']);
      });

      expect(exitCode, 1);
      expect(stderrText, contains('git command failed'));
    });

    test('warns when an updated theme requires a newer Trellis version', () async {
      writeConfig(theme: 'future-theme');
      final theme = writeTheme('future-theme', minTrellisVersion: '99.0.0');
      Directory(p.join(theme.path, '.git')).createSync();
      final command = ThemeUpdateCommand(
        workingDirectory: tempDir.path,
        processRunner: (executable, arguments) async => ProcessResult(0, 0, '', ''),
      );

      late int exitCode;
      final stderrText = await _captureStderr(() async {
        exitCode = await runSingleCommand(command, ['update', 'future-theme']);
      });

      expect(exitCode, 0);
      expect(stderrText, allOf(contains('requires trellis_site >=99.0.0'), contains('installed version is')));
    });
  });

  // ─── trellis theme list ───────────────────────────────────────────────────

  group('trellis theme list', () {
    test('no themes directory prints "No themes installed."', () async {
      writeConfig();
      final exitCode = await run(['theme', 'list']);
      expect(exitCode, 0);
    });

    test('empty themes directory prints "No themes installed."', () async {
      writeConfig();
      Directory(p.join(tempDir.path, 'themes')).createSync();
      final exitCode = await run(['theme', 'list']);
      expect(exitCode, 0);
    });

    test('lists installed themes with versions', () async {
      writeConfig();
      writeTheme('alpha', version: '1.0.0');
      writeTheme('beta', version: '2.0.0');

      final exitCode = await run(['theme', 'list']);
      expect(exitCode, 0);
    });

    test('marks active theme with *', () async {
      writeConfig(theme: 'alpha');
      writeTheme('alpha', version: '1.0.0');
      writeTheme('beta', version: '2.0.0');

      final exitCode = await run(['theme', 'list']);
      expect(exitCode, 0);
    });

    test('works without trellis_site.yaml', () async {
      writeTheme('alpha', version: '1.0.0');
      final exitCode = await run(['theme', 'list']);
      expect(exitCode, 0);
    });
  });

  // ─── trellis theme info ───────────────────────────────────────────────────

  group('trellis theme info', () {
    test('shows manifest metadata', () async {
      writeConfig();
      writeTheme('verdant', version: '1.2.0', author: 'Trellis Team');

      final exitCode = await run(['theme', 'info', 'verdant']);
      expect(exitCode, 0);
    });

    test('shows params with default values', () async {
      writeConfig();
      writeTheme('verdant', params: {'primary_color': '#2563eb'});

      final exitCode = await run(['theme', 'info', 'verdant']);
      expect(exitCode, 0);
    });

    test('no theme name → usage error', () async {
      writeConfig();
      expect(() => run(['theme', 'info']), throwsA(isA<UsageException>()));
    });

    test('theme not found → error', () async {
      writeConfig();
      final exitCode = await run(['theme', 'info', 'missing']);
      expect(exitCode, 1);
    });

    test('shows current value from theme_params when active theme matches', () async {
      writeConfig(theme: 'verdant', themeParams: {'primary_color': '#e11d48'});
      writeTheme('verdant', params: {'primary_color': '#2563eb'});

      final exitCode = await run(['theme', 'info', 'verdant']);
      expect(exitCode, 0);
    });
  });

  // ─── trellis theme remove ─────────────────────────────────────────────────

  group('trellis theme remove', () {
    test('removes theme directory', () async {
      writeConfig();
      writeTheme('verdant');

      final exitCode = await run(['theme', 'remove', 'verdant']);
      expect(exitCode, 0);
      expect(Directory(p.join(tempDir.path, 'themes', 'verdant')).existsSync(), isFalse);
    });

    test('clears theme: from config when it is the active theme', () async {
      writeConfig(theme: 'verdant');
      writeTheme('verdant');

      await run(['theme', 'remove', 'verdant']);

      final content = File(p.join(tempDir.path, 'trellis_site.yaml')).readAsStringSync();
      expect(content, isNot(contains('theme: verdant')));
    });

    test('does not modify config when removing non-active theme', () async {
      writeConfig(theme: 'other-theme');
      writeTheme('verdant');
      writeTheme('other-theme');

      await run(['theme', 'remove', 'verdant']);

      final content = File(p.join(tempDir.path, 'trellis_site.yaml')).readAsStringSync();
      expect(content, contains('theme: other-theme'));
    });

    test('no theme name → usage error', () async {
      writeConfig();
      expect(() => run(['theme', 'remove']), throwsA(isA<UsageException>()));
    });

    test('theme not found → error', () async {
      writeConfig();
      final exitCode = await run(['theme', 'remove', 'missing']);
      expect(exitCode, 1);
    });

    test('warns about orphaned theme_params when removing active theme with params', () async {
      writeConfig(theme: 'verdant', themeParams: {'primary_color': '#fff'});
      writeTheme('verdant');

      // Should succeed and warn
      final exitCode = await run(['theme', 'remove', 'verdant']);
      expect(exitCode, 0);
    });
  });
}
