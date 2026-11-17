import 'dart:io';

import '../browser_reflow_probe.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.contains('--failed-launch')) {
    try {
      await BrowserProbe.launch();
      throw StateError('the invalid endpoint unexpectedly connected');
    } on SocketException {
      stdout.writeln('launch failed');
      await stdout.flush();
      return;
    }
  }
  final browser = await BrowserProbe.launch();
  stdout.writeln('probe launched');
  await stdout.flush();
  if (arguments.contains('--stalled-browser')) {
    Process.killPid(
      int.parse(File(Platform.environment['BROWSER_MAIN_PID']!).readAsStringSync()),
      ProcessSignal.sigstop,
    );
  }
  await browser.close();
  stdout.writeln('probe closed');
  await stdout.flush();
}
