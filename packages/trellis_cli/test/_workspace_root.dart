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
