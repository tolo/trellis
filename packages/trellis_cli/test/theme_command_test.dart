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
    String? author,
    Map<String, dynamic>? params,
    bool inThemesDir = true,
  }) {
    final dir = inThemesDir ? Directory(p.join(tempDir.path, 'themes', name)) : Directory(p.join(tempDir.path, name));
    dir.createSync(recursive: true);

    final buf = StringBuffer('name: $name\nversion: $version\n');
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

  Future<int> run(List<String> args) => TrellisCli(workingDirectory: tempDir.path).run(args);

  Future<int> runSingleCommand(Command<int> command, List<String> args) {
    final runner = CommandRunner<int>('trellis', 'test')..addCommand(command);
    return runner.run(args).then((code) => code ?? 0);
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
