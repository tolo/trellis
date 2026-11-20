import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../packages/trellis_cli/test/_e2e_server.dart' show allocateFreePort, e2eLoopback;
import '../packages/trellis_cli/test/_workspace_root.dart' show workspaceDependencyOverrides;

const _templates = {'shelf': 'htmx', 'relic': 'relic', 'dart_frog': 'dart_frog'};
const _projectName = 'ui_gate_demo';

Future<void> main(List<String> args) async {
  if (args.length != 1 || !{'admin', ..._templates.keys}.contains(args.single)) {
    stderr.writeln('usage: dart run tool/serve_ui_surface.dart <admin|shelf|relic|dart_frog>');
    exitCode = 64;
    return;
  }

  final surface = args.single;
  final root = Directory.fromUri(Platform.script.resolve('../'));
  final commands = _OwnedCommand();
  final tempRoot = Directory.fromUri(root.uri.resolve('.agent_temp/'))..createSync(recursive: true);
  final temp = tempRoot.createTempSync('ui-surface-$surface-');
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 1);
  final subscriptions = [
    for (final signal in [ProcessSignal.sigterm, ProcessSignal.sigint])
      signal.watch().listen((_) {
        commands.stopping = true;
        client.close(force: true);
        unawaited(commands.stop());
      }),
  ];

  try {
    final Directory app;
    if (surface == 'admin') {
      app = Directory.fromUri(root.uri.resolve('examples/admin_app/'));
    } else {
      await commands.run(temp, [
        'run',
        root.uri.resolve('packages/trellis_cli/bin/trellis.dart').toFilePath(),
        'create',
        _projectName,
        '--template',
        _templates[surface]!,
        '--ui',
      ]);
      app = Directory.fromUri(temp.uri.resolve('$_projectName/'));
      await File.fromUri(
        app.uri.resolve('pubspec.yaml'),
      ).writeAsString(workspaceDependencyOverrides(root), mode: FileMode.append);
      await commands.run(app, ['pub', 'get']);
    }

    final appServer = File.fromUri(app.uri.resolve('bin/server.dart'));
    final source = surface == 'shelf' || surface == 'relic' ? await appServer.readAsString() : null;
    for (var attempt = 1; attempt <= 3; attempt++) {
      final port = await allocateFreePort();
      final base = Uri.parse('http://${e2eLoopback.address}:$port');
      final List<String> command;
      if (surface == 'dart_frog') {
        command = [
          'pub',
          'global',
          'run',
          'dart_frog_cli:dart_frog',
          'dev',
          '--hostname',
          e2eLoopback.address,
          '--port',
          '$port',
          '--dart-vm-service-port',
          '${await allocateFreePort()}',
        ];
      } else {
        if (source != null) {
          // The generated Shelf and Relic entry points have fixed bind addresses.
          // Change only the bind in this disposable project, leaving its middleware intact.
          final (from, to) = surface == 'shelf'
              ? ("'localhost', 8080", 'InternetAddress.loopbackIPv4, $port')
              : ('InternetAddress.anyIPv4, port: 8080', 'InternetAddress.loopbackIPv4, port: $port');
          if (!source.contains(from)) throw StateError('$surface scaffold no longer has its expected bind');
          await appServer.writeAsString(source.replaceFirst(from, to));
        }
        command = ['bin/server.dart'];
      }
      final child = await commands.start(app, command, environment: {'PORT': '$port', 'DEV': 'false'});
      var exited = false;
      unawaited(child.exitCode.then((_) => exited = true));
      final deadline = Stopwatch()..start();
      while (!commands.stopping && !exited && deadline.elapsed < const Duration(seconds: 8)) {
        try {
          final page = await (await client.getUrl(base.resolve(surface == 'admin' ? '/contacts' : '/ui'))).close();
          final body = await utf8.decodeStream(page);
          final marker = surface == 'admin' ? 'Contact directory' : 'components-dialog';
          if (page.statusCode == HttpStatus.ok && body.contains(marker)) {
            if (commands.stopping) return;
            stdout.writeln('Serving $base');
            final status = await child.exitCode;
            if (!commands.stopping) exitCode = status;
            return;
          }
        } on IOException {
          // The port may be unbound or claimed by another listener during this attempt.
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      await commands.stop();
      if (commands.stopping) return;
      stderr.writeln('$surface attempt $attempt on $port failed: ${commands.output}');
    }
    throw StateError('$surface could not serve its UI after three attempts');
  } on Object {
    if (!commands.stopping) rethrow;
  } finally {
    client.close(force: true);
    await commands.stop();
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    await temp.delete(recursive: true);
  }
}

/// Every child is registered before observing cancellation, including generators
/// and pub. Dart Frog adds a supervisor and VM, so stopping only its CLI leaks.
final class _OwnedCommand {
  Process? _child;
  Future<void>? _shutdown;
  Future<void>? _drained;
  bool stopping = false;
  StringBuffer _output = StringBuffer();
  String get output => _output.toString();

  Future<Process> start(Directory cwd, List<String> args, {Map<String, String>? environment}) async {
    if (stopping) throw StateError('UI surface launch interrupted');
    final child = await Process.start(
      Platform.resolvedExecutable,
      args,
      workingDirectory: cwd.path,
      environment: environment,
    );
    _child = child;
    _shutdown = null;
    final log = _output = StringBuffer();
    void remember(String chunk) {
      if (log.length < 8000) log.write(chunk);
    }

    _drained = Future.wait([
      child.stdout.transform(utf8.decoder).forEach(remember),
      child.stderr.transform(utf8.decoder).forEach(remember),
    ]).then((_) {});
    if (stopping) {
      await stop();
      throw StateError('UI surface launch interrupted');
    }
    return child;
  }

  Future<void> run(Directory cwd, List<String> args) async {
    final child = await start(cwd, args);
    final status = await child.exitCode;
    await _drained;
    if (status != 0) throw ProcessException(Platform.resolvedExecutable, args, output, status);
  }

  Future<void> stop() => _shutdown ??= _stopTree();

  Future<void> _stopTree() async {
    final child = _child;
    if (child == null) return;
    if (!child.kill(ProcessSignal.sigstop)) {
      await _drained;
      return;
    }
    // Freeze each level before finding the next so supervisors cannot respawn
    // workers or lose their parent identity partway through cleanup.
    final owned = <int>{child.pid};
    try {
      var added = true;
      while (added) {
        added = false;
        final listing = await Process.run('ps', ['-A', '-o', 'pid=,ppid=']);
        if (listing.exitCode != 0) {
          throw ProcessException('ps', const ['-A', '-o', 'pid=,ppid='], listing.stderr as String, listing.exitCode);
        }
        for (final line in (listing.stdout as String).trim().split('\n')) {
          final [processId, parentId] = line.trim().split(RegExp(r'\s+'));
          final pid = int.parse(processId);
          if (owned.contains(int.parse(parentId)) &&
              !owned.contains(pid) &&
              Process.killPid(pid, ProcessSignal.sigstop)) {
            owned.add(pid);
            added = true;
          }
        }
      }
    } finally {
      for (final pid in owned.toList().reversed) {
        Process.killPid(pid, ProcessSignal.sigkill);
      }
      await child.exitCode;
      await _drained;
    }
  }
}
