import 'dart:io';

import 'package:trellis_ui/trellis_ui.dart';

void main(List<String> args) {
  if (args.length > 1) {
    stderr.writeln('Usage: dart run trellis_ui:materialize [dir]');
    exitCode = 64;
    return;
  }

  final path = args.isEmpty ? 'static/trellis-ui' : args.single;
  try {
    materializeTrellisUi(Directory(path));
  } on FileSystemException catch (error) {
    stderr.writeln('Could not materialize Trellis UI assets in "$path": $error');
    exitCode = 1;
  }
}
