import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';
import 'package:trellis_dev/trellis_dev.dart';
import 'package:trellis_site/trellis_site.dart';
import 'package:watcher/watcher.dart';

import 'build_command.dart';

/// The `trellis dev` command.
///
/// Builds the site for local preview, serves it, rebuilds when a source file changes, and reloads open browser tabs
/// after each successful rebuild. Runs until Ctrl-C (SIGINT) is received.
///
/// The preview build is served from the root (`pathPrefix` cleared), uses `http://localhost:<port>` as its base URL,
/// and goes to a temporary directory, never the site's output directory, so a preview build cannot be deployed by
/// mistake. Each rebuild writes a fresh directory and the server switches to it only when the build succeeds, so a
/// broken edit keeps the last good build on screen.
class DevCommand extends Command<int> {
  /// Optional stop signal. When this future completes the server shuts down.
  ///
  /// Defaults to `ProcessSignal.sigint.watch().first` (Ctrl-C). Tests inject their own future.
  final Future<void>? stopSignal;

  /// Base directory the site is loaded from. Defaults to the process current directory. Injected by tests so the
  /// command never depends on (or mutates) the process-global working directory.
  final String? workingDirectory;

  /// Quiet period after the last file event before a rebuild starts, so an editor's save burst builds once.
  final Duration debounce;

  DevCommand({this.stopSignal, this.workingDirectory, this.debounce = const Duration(milliseconds: 150)}) {
    argParser
      ..addOption('port', abbr: 'p', help: 'Port to listen on.', defaultsTo: '8080')
      ..addFlag('drafts', help: 'Include draft content.', defaultsTo: false)
      ..addFlag('verbose', abbr: 'v', help: 'Show detailed build log.', defaultsTo: false);
  }

  @override
  String get name => 'dev';

  @override
  String get description => 'Build, serve and watch a Trellis static site, reloading the browser on change.';

  @override
  String get invocation => 'trellis dev [options]';

  @override
  Future<int> run() async {
    final portStr = argResults!['port'] as String;
    final port = int.tryParse(portStr);
    if (port == null || port < 1 || port > 65535) {
      stderr.writeln('Error: Invalid port "$portStr". Port must be an integer between 1 and 65535.');
      return 1;
    }
    final includeDrafts = argResults!['drafts'] as bool;
    final verbose = argResults!['verbose'] as bool;
    final baseDir = workingDirectory ?? Directory.current.path;

    void reportFailure(String phase, Object error, StackTrace stackTrace) {
      stderr.writeln('$phase: $error');
      if (verbose) stderr.writeln(stackTrace);
    }

    SiteConfig? readConfig() {
      try {
        return loadSiteBuildConfig(baseDir);
      } catch (error, stackTrace) {
        reportFailure('Could not load preview config', error, stackTrace);
        return null;
      }
    }

    // Fail fast on a missing or invalid config: there is nothing to watch yet.
    final initialConfig = readConfig();
    if (initialConfig == null) return 1;

    final buildRoot = Directory.systemTemp.createTempSync('trellis_dev_');
    final rebuilt = StreamController<void>.broadcast();
    var generation = 0;
    Directory? servedDir;
    Handler? served;

    Future<void> rebuild(SiteConfig loaded) async {
      final outDir = Directory(p.join(buildRoot.path, 'build-${generation++}'));
      var code = 1;
      try {
        final config = overrideSiteBuildConfig(
          loaded,
          outputDir: outDir.path,
          baseUrl: 'http://localhost:$port',
          pathPrefix: '',
        );
        code = await buildSite(config, includeDrafts: includeDrafts, verbose: verbose);
      } catch (error, stackTrace) {
        // Preview is the recovery boundary: invalid inputs can also fail with Dart Errors.
        reportFailure('Build failed', error, stackTrace);
      }
      if (code != 0) {
        if (outDir.existsSync()) outDir.deleteSync(recursive: true);
        if (served != null) stderr.writeln('Still serving the last successful build.');
        return;
      }
      final previous = servedDir;
      servedDir = outDir;
      served = createStaticHandler(outDir.path, defaultDocument: 'index.html');
      if (previous != null && previous.existsSync()) previous.deleteSync(recursive: true);
      if (!rebuilt.isClosed) rebuilt.add(null);
    }

    final subscriptions = <String, StreamSubscription<WatchEvent>>{};
    final previewRoot = p.canonicalize(buildRoot.path);
    String? outputRoot;

    // One rebuild at a time; changes during a build queue exactly one more.
    Future<void>? building;
    var pending = false;
    var stopping = false;
    Timer? debounceTimer;

    Future<void> updateWatches(SiteConfig config, void Function(WatchEvent) onEvent) async {
      final roots = _watchRoots(config);
      final configuredOutput = p.canonicalize(config.outputDir);
      // An output path that covers a watch root would also hide the edits needed to correct it.
      final coversSource = roots.any((root) => root == configuredOutput || p.isWithin(configuredOutput, root));
      outputRoot = coversSource ? null : configuredOutput;
      for (final root in subscriptions.keys.toList()) {
        if (!roots.contains(root)) await subscriptions.remove(root)!.cancel();
      }
      for (final root in roots) {
        if (subscriptions.containsKey(root)) continue;
        final watcher = DirectoryWatcher(root);
        subscriptions[root] = watcher.events.listen(
          onEvent,
          onError: (Object error, StackTrace stackTrace) => reportFailure('Could not watch $root', error, stackTrace),
          onDone: () => subscriptions.remove(root),
        );
        // Watch the new sources before building so an edit during that build is queued.
        await watcher.ready;
      }
    }

    void onEvent(WatchEvent event) {
      if (stopping || _isIgnored(event.path, subscriptions.keys, [previewRoot, ?outputRoot])) return;
      debounceTimer?.cancel();
      debounceTimer = Timer(debounce, () {
        pending = true;
        building ??= Future<void>(() async {
          try {
            while (pending && !stopping) {
              pending = false;
              stdout.writeln('Change detected, rebuilding...');
              final config = readConfig();
              if (config == null) {
                if (served != null) stderr.writeln('Still serving the last successful build.');
                continue;
              }
              await updateWatches(config, onEvent);
              await rebuild(config);
            }
          } finally {
            building = null;
          }
        });
      });
    }

    stdout.writeln('Building site...');
    await rebuild(initialConfig);

    await updateWatches(initialConfig, onEvent);

    final handler = const Pipeline().addMiddleware(liveReloadMiddleware(rebuilt.stream)).addHandler((request) {
      final current = served;
      if (current != null) return current(request);
      // No successful build yet. The page still carries the reload script, so it refreshes once a build succeeds.
      return Response(
        503,
        body:
            '<!DOCTYPE html><html><body><p>The site has not built yet. See the terminal for the error.</p></body>'
            '</html>',
        headers: {'content-type': 'text/html; charset=utf-8'},
      );
    });

    final HttpServer server;
    try {
      server = await io.serve(handler, InternetAddress.loopbackIPv4, port);
    } on SocketException catch (e) {
      stderr.writeln('Error: Could not bind to port $port. ${e.message}');
      stderr.writeln('Try --port <another-port>.');
      stopping = true;
      debounceTimer?.cancel();
      await building;
      await _shutdown(subscriptions.values.toList(), rebuilt, buildRoot);
      return 1;
    }

    stdout.writeln('Serving http://localhost:$port, watching ${subscriptions.keys.join(', ')}');
    stdout.writeln('Press Ctrl-C to stop.');

    await (stopSignal ?? ProcessSignal.sigint.watch().first);
    stopping = true;
    // Open SSE connections never finish on their own, so close them rather than wait.
    await server.close(force: true);
    debounceTimer?.cancel();
    await building; // Let an in-flight build finish before its directory is deleted.
    await _shutdown(subscriptions.values.toList(), rebuilt, buildRoot);
    return 0;
  }
}

Future<void> _shutdown(
  Iterable<StreamSubscription<WatchEvent>> subscriptions,
  StreamController<void> rebuilt,
  Directory buildRoot,
) async {
  for (final subscription in subscriptions) {
    await subscription.cancel();
  }
  await rebuilt.close();
  if (buildRoot.existsSync()) buildRoot.deleteSync(recursive: true);
}

/// The site directory, plus the theme directory when it sits outside the site: a relative `theme: ../../themes/x`,
/// or a theme project's example, whose `example/themes/<name>` is a symlink back to the theme.
List<String> _watchRoots(SiteConfig config) {
  final siteDir = p.canonicalize(config.siteDir);
  final roots = [siteDir];
  final theme = config.themeConfig;
  if (theme != null) {
    // Same resolution as the site builder: themes resolve under `<site>/themes/`, `..` segments collapsed.
    final themeDir = Directory(p.normalize(p.join(config.siteDir, 'themes', theme.name)));
    if (themeDir.existsSync()) {
      // Compare real paths: p.canonicalize is lexical, and the watcher does not follow a symlinked directory.
      final realTheme = themeDir.resolveSymbolicLinksSync();
      final realSite = Directory(siteDir).resolveSymbolicLinksSync();
      if (!p.isWithin(realSite, realTheme)) roots.add(realTheme);
    }
  }
  return roots;
}

/// Whether a change at [path] cannot affect the build: build output, or anything under a dot directory (`.git`,
/// `.dart_tool`) or a dotfile, relative to its watch root.
bool _isIgnored(String path, Iterable<String> roots, List<String> ignored) {
  final canonical = p.canonicalize(path);
  for (final dir in ignored) {
    if (canonical == dir || p.isWithin(dir, canonical)) return true;
  }
  for (final root in roots) {
    if (!p.isWithin(root, canonical)) continue;
    return p.split(p.relative(canonical, from: root)).any((segment) => segment.startsWith('.'));
  }
  return false;
}
