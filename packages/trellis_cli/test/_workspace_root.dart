import 'dart:io';
import 'dart:isolate';

/// Resolves the monorepo root independent of the caller's current directory.
///
/// The E2E tests need absolute workspace paths to inject dependency overrides
/// into generated apps. Deriving the root from the installed `trellis_cli`
/// package location is more stable than relying on `PWD` or `Directory.current`.
Future<Directory> findWorkspaceRoot() async {
  final packageUri = await Isolate.resolvePackageUri(Uri.parse('package:trellis_cli/trellis_cli.dart'));

  if (packageUri == null || packageUri.scheme != 'file') {
    throw StateError('Could not resolve package:trellis_cli/trellis_cli.dart');
  }

  var dir = File(packageUri.toFilePath()).parent;
  while (true) {
    if (Directory('${dir.path}/packages/trellis').existsSync()) return dir;

    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Could not find workspace root from resolved package path ${packageUri.toFilePath()}');
    }
    dir = parent;
  }
}

/// A `dependency_overrides:` block pointing every workspace package at its local path.
///
/// Listing every package, not just a scaffold's direct dependencies, keeps transitive ones local too: when
/// `trellis_site` gained `trellis_css` in 0.13, a hand-written list missed it, and after the release bump the
/// generated app asked pub.dev for an unpublished `trellis_css ^0.13.0` and the E2E run on `main` went red.
/// Overrides for packages outside the app's graph are ignored by pub.
String workspaceDependencyOverrides(Directory workspaceRoot) {
  final packages =
      Directory('${workspaceRoot.path}/packages')
          .listSync()
          .whereType<Directory>()
          .where((dir) => File('${dir.path}/pubspec.yaml').existsSync())
          .map((dir) => dir.uri.pathSegments.where((s) => s.isNotEmpty).last)
          .toList()
        ..sort();
  final buffer = StringBuffer('\ndependency_overrides:\n');
  for (final name in packages) {
    buffer
      ..writeln('  $name:')
      ..writeln('    path: ${workspaceRoot.path}/packages/$name');
  }
  return buffer.toString();
}
