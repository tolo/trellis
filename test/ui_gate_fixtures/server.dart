import 'dart:io';

import '../../tool/ui_gate/checks.dart';
import '../browser_reflow_probe.dart';

Future<void> main(List<String> args) async {
  final server = await StaticSiteServer.serve(
    Directory('test/ui_gate_fixtures'),
    headers: {'content-security-policy': strictPolicy},
  );
  if (args.length == 2 && args.first == '--pid') File(args.last).writeAsStringSync('$pid');
  stdout.writeln('Serving ${server.baseUrl}');
}
