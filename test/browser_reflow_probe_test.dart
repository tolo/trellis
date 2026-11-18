import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'browser_reflow_probe.dart';

void main() {
  test('close lets a standalone caller exit while descendants retain browser output pipes', () => _expectExit());
  test('failed launch reaps its browser and lets a standalone caller exit', () => _expectExit(failedLaunch: true));
  test('close bounds shutdown when the browser stops responding', () => _expectExit(stalledBrowser: true));
}

Future<void> _expectExit({bool failedLaunch = false, bool stalledBrowser = false}) async {
  final chrome = BrowserProbe.locateChrome();
  if (chrome == null) {
    requireChromeInCi('standalone browser probe shutdown');
    markTestSkipped('Chrome/Chromium not installed');
    return;
  }
  final root = Directory.systemTemp.createTempSync('browser_probe_shutdown_');
  addTearDown(() => root.deleteSync(recursive: true));
  final holderPid = File('${root.path}/holder.pid');
  final browserPid = File('${root.path}/browser.pid');
  final wrapper = File('${root.path}/chrome');
  // Keep real Chrome, but make a crash-handler-like writer outlive it until
  // teardown so pipe retention is deterministic rather than a platform race.
  wrapper.writeAsStringSync(r'''#!/bin/sh
sleep 120 &
printf '%s' "$!" > "$BROWSER_PIPE_HOLDER_PID"
printf '%s' "$$" > "$BROWSER_MAIN_PID"
if [ "$BROWSER_INVALID_ENDPOINT" = true ]; then
  printf 'ws://127.0.0.1:0/\n' >&2
fi
exec "$BROWSER_REAL_CHROME" "$@"
''');
  expect((await Process.run('chmod', ['+x', wrapper.path])).exitCode, 0);

  final child = await Process.start(
    Platform.resolvedExecutable,
    [
      'run',
      'test/fixtures/browser_probe_exit.dart',
      if (failedLaunch) '--failed-launch',
      if (stalledBrowser) '--stalled-browser',
    ],
    environment: {
      'CHROME_PATH': wrapper.path,
      'BROWSER_REAL_CHROME': chrome,
      'BROWSER_PIPE_HOLDER_PID': holderPid.path,
      'BROWSER_MAIN_PID': browserPid.path,
      'BROWSER_INVALID_ENDPOINT': '$failedLaunch',
    },
  );
  final log = StringBuffer();
  final launched = Completer<void>();
  final closed = Completer<void>();
  var browserReaped = false;
  final output = child.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
    log.writeln(line);
    if (line == 'probe launched' && !launched.isCompleted) {
      launched.complete();
    }
    if (line == (failedLaunch ? 'launch failed' : 'probe closed') && !closed.isCompleted) {
      closed.complete();
    }
  });
  final errors = child.stderr.transform(utf8.decoder).listen(log.write);
  addTearDown(() async {
    if (holderPid.existsSync()) {
      Process.killPid(int.parse(holderPid.readAsStringSync()), ProcessSignal.sigterm);
    }
    if (!browserReaped && browserPid.existsSync()) {
      Process.killPid(int.parse(browserPid.readAsStringSync()), ProcessSignal.sigkill);
    }
    child.kill(ProcessSignal.sigkill);
    await child.exitCode;
    await output.cancel();
    await errors.cancel();
  });

  if (stalledBrowser) {
    await launched.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw StateError('the probe did not launch:\n$log'),
    );
  }
  await closed.future.timeout(
    Duration(seconds: stalledBrowser ? 10 : 30),
    onTimeout: () => throw StateError('the probe did not complete shutdown:\n$log'),
  );
  expect(Process.killPid(int.parse(holderPid.readAsStringSync()), ProcessSignal.sigcont), isTrue);
  browserReaped = !Process.killPid(int.parse(browserPid.readAsStringSync()), ProcessSignal.sigcont);
  expect(browserReaped, isTrue, reason: 'the owned main browser process must be reaped:\n$log');
  final exit = await child.exitCode.timeout(const Duration(seconds: 5), onTimeout: () => -1);
  expect(exit, 0, reason: 'close returned, but inherited output pipes kept the standalone Dart VM alive:\n$log');
}
