import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:trellis_admin_example/admin_app.dart';

Future<void> main() async {
  final root = File.fromUri(Platform.script).parent.parent;
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final random = Random.secure();
  final secret =
      Platform.environment['CSRF_SECRET'] ??
      List.generate(32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  final app = createAdminApp(root, csrfSecret: secret);
  final server = await shelf_io.serve(app.handler, InternetAddress.loopbackIPv4, port);
  stdout.writeln('Serving http://127.0.0.1:${server.port}');
  ProcessSignal.sigint.watch().take(1).listen((_) async {
    await server.close();
    await app.close();
  });
}
