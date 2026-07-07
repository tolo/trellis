import 'dart:io';

/// Renders a Homebrew formula for the `trellis` binary tap from release checksums.
///
/// Usage:
///   `dart run tool/render_homebrew_formula.dart --version <v>`
///   `  --checksums-dir <dir> --repo <owner/repo> --output <path>`
///
/// `--checksums-dir` holds the `*.tar.gz.sha256` sidecars downloaded from the
/// GitHub release (macOS + Linux, arm64 + x64). `--repo` is the release repo
/// (`tolo/trellis`); the tap itself is `tolo/homebrew-trellis`.
void main(List<String> argv) {
  final opts = _parse(argv);
  final version = opts['version']!;
  final repo = opts['repo']!;
  final dir = opts['checksums-dir']!;
  final output = opts['output']!;

  final base = 'https://github.com/$repo/releases/download/v$version';
  String url(String os, String arch) => '$base/trellis-v$version-$os-$arch.tar.gz';
  String sha(String os, String arch) => _readSha('$dir/trellis-v$version-$os-$arch.tar.gz.sha256');

  final formula =
      '''
class Trellis < Formula
  desc "CLI for the Trellis template engine: scaffold, build, and serve sites"
  homepage "https://github.com/$repo"
  version "$version"
  license "MIT"

  on_macos do
    on_arm do
      url "${url('macos', 'arm64')}"
      sha256 "${sha('macos', 'arm64')}"
    end
    on_intel do
      url "${url('macos', 'x64')}"
      sha256 "${sha('macos', 'x64')}"
    end
  end

  on_linux do
    on_arm do
      url "${url('linux', 'arm64')}"
      sha256 "${sha('linux', 'arm64')}"
    end
    on_intel do
      url "${url('linux', 'x64')}"
      sha256 "${sha('linux', 'x64')}"
    end
  end

  def install
    bin.install "trellis"
  end

  test do
    assert_match "#{version}", shell_output("#{bin}/trellis --version")
  end
end
''';

  File(output).writeAsStringSync(formula);
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
