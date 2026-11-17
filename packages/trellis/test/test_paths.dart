// Locates the package and repository roots so tests read files regardless of the working directory (`dart test` from
// packages/trellis, from the repository root, or from an IDE).
import 'dart:io';
import 'dart:isolate';

/// The `packages/trellis` directory, found through this package's own package URI (`<root>/lib/trellis.dart`).
final Directory packageRoot = () {
  final library = Isolate.resolvePackageUriSync(Uri.parse('package:trellis/trellis.dart'));
  if (library == null) throw StateError('package:trellis does not resolve; run through `dart test`');
  return File.fromUri(library).parent.parent;
}();

/// The workspace root, two levels above [packageRoot] (`packages/trellis`).
final Directory repoRoot = packageRoot.parent.parent;
