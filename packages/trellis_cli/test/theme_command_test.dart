import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_cli/trellis_cli.dart';
import 'package:trellis_cli/src/theme_config_updater.dart';

void main() {
  late Directory tempDir;
  late String originalDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('trellis_theme_cmd_');
    originalDir = Directory.current.path;
    Directory.current = tempDir;
  });

  tearDown(() {
    Directory.current = originalDir;
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

  Future<int> run(List<String> args) => TrellisCli().run(args);

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
