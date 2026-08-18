/// Support for booting real HTTP servers in E2E tests without port collisions.
///
/// These suites used to hard-code their ports (19080/19081/19082). Two
/// concurrent `dart test` runs then shared one server: counters incremented
/// twice, and one run's port-based cleanup killed the other run's process.
/// Every server now gets its own OS-assigned port instead.
library;

import 'dart:convert';
import 'dart:io';

/// Asks the OS for an unused loopback port.
///
/// Inherently racy: the port is free when returned, but nothing holds it, so
/// another process can claim it before the server binds. Callers go through
/// [bootServer], whose retry absorbs that race.
Future<int> allocateFreePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  try {
    return socket.port;
  } finally {
    await socket.close();
  }
}

/// A running server process, the port it listens on, and everything it has
/// written to stdout/stderr.
typedef BootedServer = ({Process process, int port, StringBuffer output});

/// Boots a server on a free port, retrying on a fresh port if it never becomes
/// ready.
///
/// [start] launches the process for a given port; [isReady] polls until the
/// server answers. Throws with the captured server output when every attempt
/// fails — previously this output was discarded, so a failed boot reported only
/// "did not become ready" with no indication of why.
Future<BootedServer> bootServer({
  required String label,
  required Future<Process> Function(int port) start,
  required Future<bool> Function(int port) isReady,
  int attempts = 3,
}) async {
  final failures = <String>[];

  for (var attempt = 1; attempt <= attempts; attempt++) {
    final port = await allocateFreePort();
    final process = await start(port);
    final output = StringBuffer();
    process.stdout.transform(utf8.decoder).listen(output.write);
    process.stderr.transform(utf8.decoder).listen(output.write);

    if (await isReady(port)) {
      return (process: process, port: port, output: output);
    }

    await stopServer(process);
    final captured = output.toString().trim();
    failures.add('attempt $attempt (port $port): ${captured.isEmpty ? '<no server output>' : '\n$captured'}');
  }

  throw StateError('$label did not become ready after $attempts attempts.\n\n${failures.join('\n\n')}');
}

/// Terminates [process] and waits briefly for it to exit.
Future<void> stopServer(Process? process) async {
  if (process == null) return;
  process.kill();
  await process.exitCode.timeout(const Duration(seconds: 5), onTimeout: () => -1);
}
