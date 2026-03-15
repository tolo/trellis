import 'dart:io';

/// Abstraction for writing files during project generation.
///
/// [DiskFileWriter] writes to the filesystem; [InMemoryFileWriter] captures
/// output in memory for testing without filesystem I/O.
abstract class FileWriter {
  /// Writes [content] to [relativePath] under the project root.
  Future<void> writeFile(String relativePath, String content);
}

/// Writes files to disk under [rootDir].
class DiskFileWriter implements FileWriter {
  /// Creates a writer rooted at [rootDir].
  DiskFileWriter(this.rootDir);

  /// The root directory for all generated files.
  final String rootDir;

  @override
  Future<void> writeFile(String relativePath, String content) async {
    final file = File('$rootDir/$relativePath');
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }
}

/// Captures written files in memory for testing.
class InMemoryFileWriter implements FileWriter {
  /// Map of relative path to file content.
  final Map<String, String> files = {};

  @override
  Future<void> writeFile(String relativePath, String content) async {
    files[relativePath] = content;
  }
}
