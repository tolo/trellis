import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

const _recognizedArchetypes = <String>{'docs', 'landing', 'blog'};
const _regenerationCommand = 'dart run tool/generate_theme_gallery.dart';
const _manifestRulesDoc = 'see docs/guides/theme-authoring.md, "Name and archetype rules"';

/// Header written into `site/data/themes.yaml`, so a contributor who edits the
/// file by hand reads why CI rejected it before they read the CI log.
const _generatedHeader =
    '# GENERATED FILE – do not edit by hand.\n'
    '# Generator: tool/generate_theme_gallery.dart\n'
    '# Source:    themes/<name>/theme.yaml\n'
    '# Regenerate with: $_regenerationCommand\n';

const _usage = '''
Generate committed theme-gallery metadata and screenshot copies.

Usage:
  dart run tool/generate_theme_gallery.dart [--check] [project-root]

Options:
  --check      Report drift without changing files.
  -h, --help   Print this usage and exit.
''';

/// A deterministic gallery-generation failure caused by an invalid theme manifest.
final class ThemeGalleryException implements Exception {
  /// Creates an exception with an actionable [message].
  const ThemeGalleryException(this.message);

  /// The failure detail.
  final String message;

  @override
  String toString() => message;
}

/// The result of comparing committed gallery outputs with installed themes.
final class ThemeGalleryCheckResult {
  /// Creates a result from the collected [problems].
  const ThemeGalleryCheckResult(this.problems);

  /// Every stale or missing output found.
  final List<String> problems;

  /// Whether every generated output is current.
  bool get isFresh => problems.isEmpty;
}

/// Generates the site-owned gallery inventory from installed theme manifests.
final class ThemeGalleryGenerator {
  /// Creates a generator rooted at a Trellis checkout.
  ThemeGalleryGenerator(this.projectRoot, {void Function(String)? warningSink})
    : warningSink = warningSink ?? stderr.writeln;

  /// Repository root containing `themes/` and `site/`.
  final String projectRoot;

  /// Receives warnings for declared screenshot sources that are unavailable.
  final void Function(String) warningSink;

  String get _themesDir => p.join(projectRoot, 'themes');
  String get _dataPath => p.join(projectRoot, 'site', 'data', 'themes.yaml');
  String get _screenshotsDir => p.join(projectRoot, 'site', 'static', 'themes');

  /// Reconciles metadata, screenshot copies, and orphaned prior outputs.
  void write() {
    final model = _buildModel();
    _validateGeneratedOutputs();
    final dataFile = File(_dataPath);
    dataFile.parent.createSync(recursive: true);
    dataFile.writeAsStringSync(model.yaml);

    final screenshotsDir = Directory(_screenshotsDir)..createSync(recursive: true);
    final expectedPaths = model.screenshots.keys.toSet();
    for (final file in screenshotsDir.listSync(recursive: true, followLinks: false).whereType<File>()) {
      if (!expectedPaths.contains(p.normalize(file.path))) {
        file.deleteSync();
      }
    }
    for (final entry in model.screenshots.entries) {
      final destination = File(entry.key);
      destination.parent.createSync(recursive: true);
      destination.writeAsBytesSync(entry.value);
    }
    _removeEmptyDirectories(screenshotsDir);
  }

  /// Checks generated outputs without changing the working tree.
  ThemeGalleryCheckResult check() {
    final model = _buildModel();
    final problems = <String>[];
    try {
      _validateGeneratedOutputs();
    } on ThemeGalleryException catch (error) {
      return ThemeGalleryCheckResult(<String>[error.message, 'Regenerate with: $_regenerationCommand']);
    }
    final dataFile = File(_dataPath);
    if (!dataFile.existsSync() || dataFile.readAsStringSync() != model.yaml) {
      final names = {...model.themeNames, ..._generatedThemeNames(dataFile)}.toList()..sort();
      problems.add('site/data/themes.yaml is stale for installed themes: ${names.join(', ')}');
    }

    for (final entry in model.screenshots.entries) {
      final file = File(entry.key);
      if (!file.existsSync() || !_bytesEqual(file.readAsBytesSync(), entry.value)) {
        problems.add('${p.relative(entry.key, from: projectRoot)} is stale or missing');
      }
    }

    final screenshotsType = FileSystemEntity.typeSync(_screenshotsDir, followLinks: false);
    if (screenshotsType == FileSystemEntityType.link) {
      problems.add('site/static/themes must not be a symbolic link');
    } else if (screenshotsType == FileSystemEntityType.directory) {
      final expectedPaths = model.screenshots.keys.toSet();
      for (final entity in Directory(_screenshotsDir).listSync(recursive: true, followLinks: false)) {
        if (entity is Link) {
          problems.add('${p.relative(entity.path, from: projectRoot)} is an unsafe symbolic link');
        } else if (entity is File && !expectedPaths.contains(p.normalize(entity.path))) {
          problems.add('${p.relative(entity.path, from: projectRoot)} is an orphaned gallery copy');
        }
      }
    }
    if (problems.isNotEmpty) {
      problems.add('Regenerate with: $_regenerationCommand');
    }
    return ThemeGalleryCheckResult(List.unmodifiable(problems));
  }

  _GalleryModel _buildModel() {
    final themesDir = Directory(_themesDir);
    if (!themesDir.existsSync()) {
      throw ThemeGalleryException('Theme directory not found: $_themesDir');
    }

    final entries = <_ThemeEntry>[];
    final themeDirs =
        themesDir
            .listSync(followLinks: false)
            .whereType<Directory>()
            .where((dir) => File(p.join(dir.path, 'theme.yaml')).existsSync())
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final themeDir in themeDirs) {
      entries.add(_readTheme(themeDir));
    }
    entries.sort((a, b) => a.name.compareTo(b.name));

    final screenshots = <String, List<int>>{};
    for (final entry in entries) {
      for (final screenshot in entry.screenshots.entries) {
        final destination = p.normalize(p.join(_screenshotsDir, entry.name, '${screenshot.key}.png'));
        if (!p.isWithin(_screenshotsDir, destination)) {
          throw ThemeGalleryException('${entry.name}: generated screenshot path escapes $_screenshotsDir');
        }
        screenshots[destination] = screenshot.value.file.readAsBytesSync();
      }
    }

    return _GalleryModel(
      yaml: _encodeYaml(entries),
      screenshots: Map.unmodifiable(screenshots),
      themeNames: List.unmodifiable(entries.map((entry) => entry.name)),
    );
  }

  _ThemeEntry _readTheme(Directory themeDir) {
    final manifestPath = p.join(themeDir.path, 'theme.yaml');
    final Object? document;
    try {
      document = loadYaml(File(manifestPath).readAsStringSync());
    } on YamlException catch (error) {
      // Unwrapped, this escapes main's catch clauses as an unhandled exception
      // with no theme name — useless when one of several manifests is broken.
      throw ThemeGalleryException('${p.basename(themeDir.path)}: theme.yaml is not valid YAML: ${error.message}');
    }
    if (document is! YamlMap) {
      throw ThemeGalleryException('${p.basename(themeDir.path)}: theme.yaml must contain a map');
    }

    final name = _requiredString(document, 'name', themeDir);
    final directoryName = p.basename(themeDir.path);
    final portableName = RegExp(r'^[a-z0-9][a-z0-9_-]*$');
    if (name != directoryName || !portableName.hasMatch(name)) {
      throw ThemeGalleryException(
        '$name: theme name must equal its containing directory name "$directoryName" and be a portable path segment '
        'matching ${portableName.pattern} ($_manifestRulesDoc)',
      );
    }
    if (!File(p.join(themeDir.path, 'README.md')).existsSync()) {
      // Every gallery card links to themes/<name>/README.md, so a theme without
      // one ships a dead link that no link checker sees (the URL is external).
      throw ThemeGalleryException('$name: themes/$directoryName/README.md is missing; every gallery card links to it');
    }
    final description = _requiredString(document, 'description', themeDir);
    if (description.contains('`')) {
      // The gallery renders description with tl:text, so backticks would reach
      // the card as literal characters rather than as code formatting.
      throw ThemeGalleryException(
        '$name: theme.yaml description must be plain prose; the gallery renders it as text, so `backticks` show up '
        'literally on the card',
      );
    }
    final features = _stringList(document['features'], name, 'features');
    final occurrences = features.where(_recognizedArchetypes.contains).toList();
    if (occurrences.length != 1) {
      throw ThemeGalleryException(
        '$name: recognized archetype occurrences found [${occurrences.join(', ')}]; '
        'features must contain exactly one occurrence from docs|landing|blog ($_manifestRulesDoc)',
      );
    }

    final screenshots = <String, _Screenshot>{};
    final declaredScreenshots = document.containsKey('screenshots')
        ? _stringList(document['screenshots'], name, 'screenshots')
        : const <String>[];
    for (final relativePath in declaredScreenshots) {
      final variant = p.basenameWithoutExtension(relativePath).toLowerCase();
      if (variant != 'light' && variant != 'dark') {
        warningSink(
          'theme_gallery: WARNING – $name declared screenshot $relativePath with an unrecognized variant '
          '"$variant"; only light and dark reach the gallery, so it is ignored',
        );
        continue;
      }
      final sourcePath = p.normalize(p.join(themeDir.path, relativePath));
      if (!p.isWithin(themeDir.path, sourcePath)) {
        throw ThemeGalleryException('$name: screenshot path escapes the theme directory: $relativePath');
      }
      final source = File(sourcePath);
      if (!source.existsSync()) {
        warningSink('theme_gallery: WARNING – $name declared missing screenshot $relativePath; omitting it');
        continue;
      }
      final canonicalTheme = themeDir.resolveSymbolicLinksSync();
      final canonicalSource = source.resolveSymbolicLinksSync();
      if (!p.isWithin(canonicalTheme, canonicalSource)) {
        throw ThemeGalleryException('$name: screenshot resolves outside the theme directory: $relativePath');
      }
      screenshots[variant] = _Screenshot(file: source, relativePath: p.posix.normalize(relativePath));
    }

    return _ThemeEntry(
      name: name,
      directoryName: directoryName,
      description: description,
      archetype: occurrences.single,
      screenshots: Map.unmodifiable(screenshots),
    );
  }

  void _validateGeneratedOutputs() {
    _rejectSymlinkComponents(_dataPath);
    _rejectSymlinkComponents(_screenshotsDir);
    final canonicalRoot = Directory(projectRoot).resolveSymbolicLinksSync();
    for (final parent in <String>[p.dirname(_dataPath), p.dirname(_screenshotsDir)]) {
      var existingParent = parent;
      while (FileSystemEntity.typeSync(existingParent, followLinks: false) == FileSystemEntityType.notFound) {
        existingParent = p.dirname(existingParent);
      }
      final canonicalParent = Directory(existingParent).resolveSymbolicLinksSync();
      if (!p.isWithin(canonicalRoot, canonicalParent)) {
        throw ThemeGalleryException('Generated output parent resolves outside the project root: $parent');
      }
    }
    if (FileSystemEntity.typeSync(_dataPath, followLinks: false) == FileSystemEntityType.link) {
      throw ThemeGalleryException('site/data/themes.yaml must not be a symbolic link');
    }
    final screenshotsType = FileSystemEntity.typeSync(_screenshotsDir, followLinks: false);
    if (screenshotsType == FileSystemEntityType.link) {
      throw ThemeGalleryException('site/static/themes must not be a symbolic link');
    }
    if (screenshotsType == FileSystemEntityType.directory) {
      final links = Directory(_screenshotsDir).listSync(recursive: true, followLinks: false).whereType<Link>();
      if (links.isNotEmpty) {
        final link = links.first;
        throw ThemeGalleryException(
          '${p.relative(link.path, from: projectRoot)} is an unsafe symbolic link in generated outputs',
        );
      }
    }
  }

  void _rejectSymlinkComponents(String outputPath) {
    var current = p.normalize(projectRoot);
    for (final component in p.split(p.relative(outputPath, from: current))) {
      current = p.join(current, component);
      if (FileSystemEntity.typeSync(current, followLinks: false) == FileSystemEntityType.link) {
        throw ThemeGalleryException(
          '${p.relative(current, from: projectRoot)} must not be a symbolic link in a generated output path',
        );
      }
    }
  }
}

final class _ThemeEntry {
  const _ThemeEntry({
    required this.name,
    required this.directoryName,
    required this.description,
    required this.archetype,
    required this.screenshots,
  });

  final String name;
  final String directoryName;
  final String description;
  final String archetype;
  final Map<String, _Screenshot> screenshots;
}

final class _Screenshot {
  const _Screenshot({required this.file, required this.relativePath});

  final File file;
  final String relativePath;
}

final class _GalleryModel {
  const _GalleryModel({required this.yaml, required this.screenshots, required this.themeNames});

  final String yaml;
  final Map<String, List<int>> screenshots;
  final List<String> themeNames;
}

String _requiredString(YamlMap document, String key, Directory themeDir) {
  final value = document[key];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  throw ThemeGalleryException('${p.basename(themeDir.path)}: theme.yaml requires a non-empty $key');
}

List<String> _stringList(Object? value, String themeName, String field) {
  if (value is! YamlList || value.any((item) => item is! String)) {
    throw ThemeGalleryException('$themeName: theme.yaml $field must be a list of strings');
  }
  return value.cast<String>().toList(growable: false);
}

String _encodeYaml(List<_ThemeEntry> entries) {
  final buffer = StringBuffer(_generatedHeader)..write('themes:\n');
  for (final entry in entries) {
    buffer
      ..writeln('  - name: ${jsonEncode(entry.name)}')
      ..writeln('    archetype: ${jsonEncode(entry.archetype)}')
      ..writeln('    description: ${jsonEncode(entry.description)}')
      ..writeln('    config_hint: ${jsonEncode('theme: ${entry.name}')}')
      ..writeln(
        '    readme_url: '
        '${jsonEncode('https://github.com/tolo/trellis/tree/main/themes/${entry.directoryName}/README.md')}',
      );
    if (entry.screenshots.containsKey('light')) {
      buffer.writeln('    screenshot_light: ${jsonEncode('themes/${entry.name}/light.png')}');
      buffer.writeln('    screenshot_light_source: ${jsonEncode(entry.screenshots['light']!.relativePath)}');
    }
    if (entry.screenshots.containsKey('dark')) {
      buffer.writeln('    screenshot_dark: ${jsonEncode('themes/${entry.name}/dark.png')}');
      buffer.writeln('    screenshot_dark_source: ${jsonEncode(entry.screenshots['dark']!.relativePath)}');
    }
  }
  return buffer.toString();
}

Set<String> _generatedThemeNames(File dataFile) {
  if (!dataFile.existsSync()) {
    return <String>{};
  }
  try {
    final document = loadYaml(dataFile.readAsStringSync());
    if (document is! YamlMap || document['themes'] is! YamlList) {
      return <String>{};
    }
    return {
      for (final entry in document['themes'] as YamlList)
        if (entry is YamlMap && entry['name'] is String) entry['name'] as String,
    };
  } on YamlException {
    return <String>{};
  }
}

bool _bytesEqual(List<int> first, List<int> second) {
  if (first.length != second.length) {
    return false;
  }
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) {
      return false;
    }
  }
  return true;
}

void _removeEmptyDirectories(Directory root) {
  final directories = root.listSync(recursive: true, followLinks: false).whereType<Directory>().toList()
    ..sort((a, b) => b.path.length.compareTo(a.path.length));
  for (final directory in directories) {
    if (directory.listSync().isEmpty) {
      directory.deleteSync();
    }
  }
}

void main(List<String> args) {
  if (args.contains('-h') || args.contains('--help')) {
    stdout.write(_usage);
    return;
  }
  final unknownOptions = args.where((arg) => arg.startsWith('-') && arg != '--check').toList();
  final positional = args.where((arg) => !arg.startsWith('-')).toList();
  if (unknownOptions.isNotEmpty || positional.length > 1) {
    stderr.write(_usage);
    exitCode = 2;
    return;
  }

  final root = p.normalize(p.absolute(positional.isEmpty ? Directory.current.path : positional.single));
  try {
    final generator = ThemeGalleryGenerator(root);
    if (args.contains('--check')) {
      final result = generator.check();
      if (!result.isFresh) {
        stderr.writeln('theme_gallery: FAILED – generated gallery outputs are stale:');
        for (final problem in result.problems) {
          stderr.writeln('  $problem');
        }
        exitCode = 1;
        return;
      }
      stdout.writeln('theme_gallery: OK – generated gallery outputs are current.');
      return;
    }

    generator.write();
    stdout.writeln('theme_gallery: generated site/data/themes.yaml and site/static/themes/.');
  } on ThemeGalleryException catch (error) {
    stderr.writeln('theme_gallery: FAILED – $error');
    exitCode = 1;
  } on FileSystemException catch (error) {
    stderr.writeln('theme_gallery: FAILED – ${error.message}: ${error.path}');
    exitCode = 1;
  }
}
