// Pure-Dart internal link/asset integrity checker for a built static-site tree.
//
// Walks a `trellis build` output directory, parses every `.html` file with
// `package:html`, and verifies that each internal `href`/`src`/`srcset`
// reference resolves to a file that actually exists in the output tree — the
// way a static host serves it. A green `trellis build` is not proof of a
// working site: a wrong-base-path link produces valid HTML and no build error
// but a dead link in production. This checker is that gate.
//
// External references (`http(s):`, protocol-relative `//host`, `mailto:`,
// `tel:`, `data:`) and pure in-page anchors (`#frag`) are out of scope and are
// never reported.
//
// Known limitations: `srcset` candidates are split on commas, so a URL
// containing a literal comma will mis-split (this can only cause a false
// positive — a spurious "broken" report — never a false negative). CSS
// `url(...)` references (in `<style>` blocks or external stylesheets) and
// non-first `srcset` descriptors are out of scope by design.
//
// The check is deterministic — no network, no environment lookups — so it
// yields the same result locally and in CI.
//
// Usage:
//   dart run tool/link_check.dart <output-dir> [--base-path /trellis/]
//
// Options:
//   --base-path <prefix>  The URL sub-path the output tree is mounted at on the
//                         host (e.g. `/trellis/` for GitHub Project Pages). When
//                         set, every internal root-absolute reference MUST begin
//                         with this prefix; the prefix is stripped before
//                         filesystem resolution. A root-absolute reference that
//                         does NOT carry the prefix escaped the sub-path and is
//                         reported as broken — this is what makes the sub-path
//                         check a real regression guard rather than a no-op.
//                         When omitted, root-absolute references resolve
//                         directly against <output-dir> (root-served host).
//   -h, --help            Print this usage and exit 0.
//
// Exit codes:
//   0  no broken internal references (prints a summary count)
//   1  one or more broken references (prints each as `page -> target (reason)`)
//   2  usage error (bad arguments, missing output dir)

import 'dart:io';

import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;

const _usage = '''
Internal link/asset integrity checker for a Trellis build output tree.

Usage:
  dart run tool/link_check.dart <output-dir> [--base-path /trellis/]

Options:
  --base-path <prefix>  URL sub-path the output is mounted at (e.g. /trellis/).
                        Internal root-absolute refs must carry this prefix; a
                        root-absolute ref without it is reported as broken.
                        Omit for a root-served host.
  -h, --help            Print this usage and exit.

Exits 0 when every internal reference resolves, 1 when any is broken, 2 on a
usage error. External URLs (http(s):, //host, mailto:, tel:, data:) and pure
in-page anchors (#frag) are never reported.''';

/// A single broken reference: the page it was found on and the raw target.
class _Broken {
  _Broken(this.sourcePage, this.target, this.reason);

  final String sourcePage;
  final String target;
  final String reason;

  @override
  String toString() => '$sourcePage -> $target ($reason)';
}

void main(List<String> args) {
  // Argument parsing (hand-rolled to keep this a zero-extra-dependency tool).
  if (args.contains('-h') || args.contains('--help')) {
    stdout.writeln(_usage);
    exit(0);
  }

  String? outputDirArg;
  String? basePath;
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--base-path') {
      if (i + 1 >= args.length) {
        stderr.writeln('Error: --base-path requires a value.\n');
        stderr.writeln(_usage);
        exit(2);
      }
      basePath = args[++i];
    } else if (arg.startsWith('--base-path=')) {
      basePath = arg.substring('--base-path='.length);
    } else if (arg.startsWith('-')) {
      stderr.writeln('Error: unknown option "$arg".\n');
      stderr.writeln(_usage);
      exit(2);
    } else if (outputDirArg == null) {
      outputDirArg = arg;
    } else {
      stderr.writeln('Error: unexpected extra argument "$arg".\n');
      stderr.writeln(_usage);
      exit(2);
    }
  }

  if (outputDirArg == null) {
    stderr.writeln('Error: missing <output-dir>.\n');
    stderr.writeln(_usage);
    exit(2);
  }

  final outputDir = Directory(outputDirArg);
  if (!outputDir.existsSync()) {
    stderr.writeln('Error: output directory not found: $outputDirArg');
    exit(2);
  }

  final result = checkLinks(outputDir.path, basePath: basePath);

  if (result.broken.isEmpty) {
    stdout.writeln(
      'link_check: OK — ${result.pagesChecked} pages, '
      '${result.refsChecked} internal references, 0 broken.',
    );
    exit(0);
  }

  stderr.writeln('link_check: FAILED — ${result.broken.length} broken reference(s):');
  for (final b in result.broken) {
    stderr.writeln('  $b');
  }
  stderr.writeln('\nChecked ${result.pagesChecked} pages, ${result.refsChecked} internal references.');
  exit(1);
}

/// Outcome of a [checkLinks] run.
class LinkCheckResult {
  LinkCheckResult(this.broken, this.pagesChecked, this.refsChecked);

  /// Every broken internal reference found.
  final List<_Broken> broken;

  /// Number of `.html` files parsed.
  final int pagesChecked;

  /// Number of internal references classified and resolved (excludes skipped
  /// external refs and in-page anchors).
  final int refsChecked;
}

/// Walks [outputDirPath] for `.html` files, extracts `href`/`src`/`srcset`
/// references, and resolves each internal reference against the output
/// filesystem as a static host would serve it.
///
/// When [basePath] is non-null, the tree is treated as mounted at that URL
/// sub-path: root-absolute references must carry the prefix (which is stripped
/// before resolution), and a root-absolute reference lacking it is broken.
LinkCheckResult checkLinks(String outputDirPath, {String? basePath}) {
  final broken = <_Broken>[];
  final root = Directory(outputDirPath);

  // Normalize the base path to a leading+trailing-slash form, e.g. `/trellis/`.
  final normalizedBase = _normalizeBasePath(basePath);

  final htmlFiles =
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => p.extension(f.path).toLowerCase() == '.html')
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  var refsChecked = 0;

  for (final file in htmlFiles) {
    // The page's served URL path, relative to the output root, always starting
    // with `/` (e.g. `/docs/index.html`). Used to resolve relative references.
    final relFromRoot = p.relative(file.path, from: root.path);
    final pageUrlPath = '/${p.split(relFromRoot).join('/')}';
    final sourceLabel = relFromRoot; // human-friendly source page label

    final document = html_parser.parse(file.readAsStringSync());

    for (final ref in _extractRefs(document.querySelectorAll('*'))) {
      final classified = _classify(ref);
      if (classified == _RefKind.external) continue;

      refsChecked++;

      final reason = _resolveBroken(
        ref: ref,
        kind: classified,
        pageUrlPath: pageUrlPath,
        outputRoot: root.path,
        basePath: normalizedBase,
      );
      if (reason != null) {
        broken.add(_Broken(sourceLabel, ref, reason));
      }
    }
  }

  return LinkCheckResult(broken, htmlFiles.length, refsChecked);
}

/// Collects raw `href`/`src` values plus the first URL of each `srcset`
/// candidate, in document order, from [elements].
Iterable<String> _extractRefs(Iterable<dynamic> elements) sync* {
  for (final el in elements) {
    final attrs = el.attributes as Map<Object, String>;
    final href = attrs['href'];
    if (href != null && href.isNotEmpty) yield href;
    final src = attrs['src'];
    if (src != null && src.isNotEmpty) yield src;
    final srcset = attrs['srcset'];
    if (srcset != null && srcset.isNotEmpty) {
      for (final candidate in srcset.split(',')) {
        // Each candidate is `<url> [descriptor]`; take the first token (the URL).
        final url = candidate.trim().split(RegExp(r'\s+')).first;
        if (url.isNotEmpty) yield url;
      }
    }
  }
}

enum _RefKind { external, rootAbsolute, relative }

/// Classifies a raw reference. External refs (and pure in-page anchors) are
/// [_RefKind.external] and skipped by the caller.
_RefKind _classify(String ref) {
  // Pure in-page anchor.
  if (ref.startsWith('#')) return _RefKind.external;

  // Absolute URL with a scheme, or protocol-relative `//host`.
  final lower = ref.toLowerCase();
  if (lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('//') ||
      lower.startsWith('mailto:') ||
      lower.startsWith('tel:') ||
      lower.startsWith('data:')) {
    return _RefKind.external;
  }

  // Any other scheme-bearing ref (e.g. `ftp:`, `javascript:`) is external too.
  // A leading `/` (single slash — `//` handled above) is root-absolute.
  if (ref.startsWith('/')) return _RefKind.rootAbsolute;

  // A generic `scheme:` prefix (no slashes yet) — treat as external/non-internal.
  final schemeMatch = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').firstMatch(ref);
  if (schemeMatch != null) return _RefKind.external;

  return _RefKind.relative;
}

/// Resolves [ref] against the output filesystem and returns a human-readable
/// reason string if it is broken, or `null` if it resolves.
String? _resolveBroken({
  required String ref,
  required _RefKind kind,
  required String pageUrlPath,
  required String outputRoot,
  required String? basePath,
}) {
  // Strip query and fragment before resolving.
  final cleaned = _stripQueryAndFragment(ref);
  if (cleaned.isEmpty) return null; // was a pure `?query`/`#frag` — nothing to resolve.

  // Compute the served URL path (absolute, starting with `/`) the ref points at.
  final String servedPath;
  if (kind == _RefKind.rootAbsolute) {
    if (basePath != null) {
      // Under a sub-path, a root-absolute ref MUST carry the prefix.
      if (!_hasBasePrefix(cleaned, basePath)) {
        return 'root-absolute ref not under base-path $basePath (escaped the sub-path)';
      }
      // Strip the prefix to get the path relative to the served root.
      servedPath = '/${cleaned.substring(basePath.length)}';
    } else {
      servedPath = cleaned;
    }
  } else {
    // Relative ref: resolve against the current page's served URL path.
    servedPath = _resolveRelative(pageUrlPath, cleaned);
  }

  // Map the served path to a file on disk under outputRoot.
  final target = _servedPathToFile(servedPath, outputRoot);
  if (target == null) {
    return 'ref escapes the output root (contains unresolvable ".." segments)';
  }
  if (File(target).existsSync()) return null;

  return 'no file at $target';
}

/// Normalizes a base path to `/segment/` form (leading and trailing slash), or
/// returns `null` when [basePath] is null/empty/`/`.
String? _normalizeBasePath(String? basePath) {
  if (basePath == null) return null;
  var b = basePath.trim();
  if (b.isEmpty || b == '/') return null;
  if (!b.startsWith('/')) b = '/$b';
  if (!b.endsWith('/')) b = '$b/';
  return b;
}

/// Whether [servedRef] (a cleaned root-absolute ref) lies under [basePath].
/// `/trellis/` matches both the exact prefix path (`/trellis/`) and anything
/// beneath it (`/trellis/docs/`).
bool _hasBasePrefix(String servedRef, String basePath) {
  // basePath ends with `/`. `/trellis` (no trailing slash) also counts as being
  // the base root itself.
  if (servedRef == basePath.substring(0, basePath.length - 1)) return true;
  return servedRef.startsWith(basePath);
}

/// Strips a `?query` and/or `#fragment` from [ref], returning the path portion.
String _stripQueryAndFragment(String ref) {
  var s = ref;
  final hash = s.indexOf('#');
  if (hash >= 0) s = s.substring(0, hash);
  final q = s.indexOf('?');
  if (q >= 0) s = s.substring(0, q);
  return s;
}

/// Resolves a relative [ref] against the current page's served URL path.
///
/// The page path is a file path (e.g. `/docs/index.html`); a relative ref is
/// resolved against the page's directory (`/docs/`), then `.`/`..` segments are
/// collapsed. Returns an absolute served path starting with `/`.
String _resolveRelative(String pageUrlPath, String ref) {
  final pageDir = p.url.dirname(pageUrlPath); // e.g. `/docs`
  final joined = p.url.normalize(p.url.join(pageDir, ref));
  return joined.startsWith('/') ? joined : '/$joined';
}

/// Maps a served URL path (absolute, starting with `/`) to a file path under
/// [outputRoot], applying the static-host directory-index convention: a path
/// ending in `/`, or with no file extension, resolves to `<dir>/index.html`.
///
/// The resolved path is normalized and required to stay within [outputRoot]
/// (or equal it); returns `null` when a `../`-laden ref would otherwise
/// escape the output tree (e.g. `/../secret.html`), so the caller reports it
/// broken instead of resolving it against a file outside the served root.
String? _servedPathToFile(String servedPath, String outputRoot) {
  var rel = servedPath.startsWith('/') ? servedPath.substring(1) : servedPath;

  final endsWithSlash = servedPath.endsWith('/');
  final lastSegment = rel.isEmpty ? '' : p.url.basename(rel);
  final hasExtension = lastSegment.contains('.') && !endsWithSlash;

  if (servedPath == '/' || endsWithSlash || !hasExtension) {
    // Directory-style link → index.html.
    rel = rel.isEmpty ? 'index.html' : p.url.join(rel, 'index.html');
  }

  // Split the URL-style relative path into OS path segments.
  final segments = p.url.split(rel).where((s) => s.isNotEmpty).toList();
  final resolved = p.normalize(p.joinAll([outputRoot, ...segments]));
  final normalizedRoot = p.normalize(outputRoot);

  if (!p.equals(resolved, normalizedRoot) && !p.isWithin(normalizedRoot, resolved)) {
    return null; // Escaped the output tree (e.g. via `..` segments).
  }

  return resolved;
}
