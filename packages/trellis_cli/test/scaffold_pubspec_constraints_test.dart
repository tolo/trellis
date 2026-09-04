import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';
import 'package:trellis_cli/trellis_cli.dart';

/// Every `trellis*` constraint a scaffold writes must admit the SDK version this CLI ships with, or the
/// generated project fails `dart pub get` on first run. The e2e suites cannot catch that: they override the
/// Trellis dependencies with workspace paths before resolving.
void main() {
  final lockstep = Version.parse(cliVersion);
  final trellisDependency = RegExp(r'^  (trellis\w*):\s*(\S+)$', multiLine: true);

  final scaffolds = <String, Future<void> Function(InMemoryFileWriter)>{
    'ProjectGenerator': (w) => ProjectGenerator(projectName: 'my_app', writer: w).generate(),
    'DartFrogProjectGenerator': (w) => DartFrogProjectGenerator(projectName: 'my_app', writer: w).generate(),
    'RelicProjectGenerator': (w) => RelicProjectGenerator(projectName: 'my_app', writer: w).generate(),
    'BlogProjectGenerator': (w) => BlogProjectGenerator(projectName: 'my_blog', writer: w).generate(),
  };

  for (final MapEntry(key: name, value: generate) in scaffolds.entries) {
    test('$name pubspec constraints admit trellis SDK $cliVersion', () async {
      final writer = InMemoryFileWriter();
      await generate(writer);

      final dependencies = trellisDependency.allMatches(writer.files['pubspec.yaml']!).toList();
      expect(dependencies, isNotEmpty, reason: 'no trellis* dependency line matched – regex or template drift');
      for (final dependency in dependencies) {
        final (package, constraint) = (dependency.group(1)!, dependency.group(2)!);
        expect(
          VersionConstraint.parse(constraint).allows(lockstep),
          isTrue,
          reason: '$package: $constraint does not admit $cliVersion (lockstep, ADR-009)',
        );
      }
    });
  }
}
