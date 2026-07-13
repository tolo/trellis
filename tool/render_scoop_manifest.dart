import 'dart:io';

/// Renders a Scoop manifest (Windows) for the `trellis` binary bucket from the
/// release checksum.
///
/// Usage:
///   `dart run tool/render_scoop_manifest.dart --version <v>`
///   `  --checksums-dir <dir> --repo <owner/repo> --output <path>`
///
/// `--checksums-dir` holds the `*.zip.sha256` sidecar downloaded from the
/// GitHub release (Windows x64). `--repo` is the release repo (`tolo/trellis`);
/// the bucket itself is `tolo/scoop-trellis`.
void main(List<String> argv) {
  final opts = _parse(argv);
  final version = opts['version']!;
  final repo = opts['repo']!;
  final dir = opts['checksums-dir']!;
  final output = opts['output']!;

  final url = 'https://github.com/$repo/releases/download/v$version/trellis-v$version-windows-x64.zip';
  final hash = _readSha('$dir/trellis-v$version-windows-x64.zip.sha256');

  final manifest =
      '''
{
  "version": "$version",
  "description": "CLI for the Trellis template engine: scaffold, build, and serve sites",
  "homepage": "https://github.com/$repo",
  "license": "MIT",
  "architecture": {
    "64bit": {
      "url": "$url",
      "hash": "$hash"
    }
  },
  "bin": "trellis.exe",
  "checkver": "github",
  "autoupdate": {
    "architecture": {
      "64bit": {
        "url": "https://github.com/$repo/releases/download/v\$version/trellis-v\$version-windows-x64.zip"
      }
    }
  }
}
''';

  File(output).writeAsStringSync(manifest);
  stdout.writeln('Wrote $output');
}

String _readSha(String path) {
  final file = File(path);
  if (!file.existsSync()) throw StateError('Missing checksum file: $path');
  return file.readAsStringSync().trim().split(RegExp(r'\s+')).first;
}

Map<String, String> _parse(List<String> argv) {
  final opts = <String, String>{};
  for (var i = 0; i < argv.length; i++) {
    final arg = argv[i];
    if (arg.startsWith('--')) {
      final key = arg.substring(2);
      if (i + 1 >= argv.length) throw ArgumentError('Missing value for --$key');
      opts[key] = argv[++i];
    }
  }
  for (final required in ['version', 'repo', 'checksums-dir', 'output']) {
    if (!opts.containsKey(required)) throw ArgumentError('Missing --$required');
  }
  return opts;
}
