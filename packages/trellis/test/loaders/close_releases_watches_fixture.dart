// Fixture for `file_loader_test.dart`'s "close() releases every watch" test — run as a subprocess.
//
// An active `Directory.watch` subscription keeps the Dart VM alive, so a watch that `close()` failed
// to cancel is observable exactly here: this process would never exit. Nothing inside the test
// process can see that, since `close()` also drops the controller and silences leaked watches.
//
// Usage: dart run <this file> <template-root>
import 'dart:io';

import 'package:trellis/trellis.dart';

Future<void> main(List<String> args) async {
  final loader = FileSystemLoader(args.single, devMode: true);
  // Force a second round of watches: on Linux the subtree created here is discovered through a
  // create event, so its watches are installed after the initial walk.
  Directory('${args.single}/late/deeper').createSync(recursive: true);
  File('${args.single}/late/deeper/page.html').writeAsStringSync('<p>Late</p>');
  await loader.changes!.first.timeout(const Duration(seconds: 10));

  await loader.close();
  stdout.writeln('closed');
}
