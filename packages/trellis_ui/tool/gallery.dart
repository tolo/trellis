import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;

import 'src/gallery.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2 || args.first != '--port') {
    throw ArgumentError('usage: dart run tool/gallery.dart --port <port>');
  }
  final port = int.parse(args[1]);
  final root = Directory.fromUri(Platform.script.resolve('../'));
  final server = await shelf_io.serve(galleryHandler(root), InternetAddress.loopbackIPv4, port);
  stdout.writeln('Serving http://127.0.0.1:${server.port}');
}
