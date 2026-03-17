import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';
import 'package:trellis_site/trellis_site.dart';

/// The `trellis serve` command.
///
/// Starts a Shelf-based static file server with clean URL support, serving the
/// site's output directory. Runs until Ctrl-C (SIGINT) is received.
class ServeCommand extends Command<int> {
  /// Optional stop signal. When this future completes the server shuts down.
  ///
  /// Defaults to `ProcessSignal.sigint.watch().first` (Ctrl-C). Tests may
  /// inject their own [Completer.future] to shut the server down without
  /// sending SIGINT to the test process.
  final Future<void>? stopSignal;

  ServeCommand({this.stopSignal}) {
    argParser
      ..addOption('port', abbr: 'p', help: 'Port to listen on.', defaultsTo: '8080')
      ..addOption('output', abbr: 'o', help: 'Output directory to serve.', defaultsTo: 'output');
  }

  @override
  String get name => 'serve';

  @override
  String get description => 'Serve a built Trellis static site locally.';

  @override
  String get invocation => 'trellis serve [options]';

  @override
  Future<int> run() async {
    // Validate port
    final portStr = argResults!['port'] as String;
    final port = int.tryParse(portStr);
    if (port == null || port < 1 || port > 65535) {
      stderr.writeln('Error: Invalid port "$portStr". Port must be an integer between 1 and 65535.');
      return 1;
    }

    // Resolve output directory: honor config unless --output explicitly provided
    final outputOption = argResults!['output'] as String;
    final outputExplicit = argResults!.wasParsed('output');
    String outputDir;
    if (outputExplicit) {
      outputDir = p.isAbsolute(outputOption) ? outputOption : p.join(Directory.current.path, outputOption);
    } else {
      // Try loading config for default outputDir
      final configPath = p.join(Directory.current.path, 'trellis_site.yaml');
      if (File(configPath).existsSync()) {
        try {
          final siteConfig = SiteConfig.load(configPath);
          outputDir = siteConfig.outputDir;
        } on SiteConfigException {
          outputDir = p.join(Directory.current.path, outputOption);
        }
      } else {
        outputDir = p.join(Directory.current.path, outputOption);
      }
    }

    if (!Directory(outputDir).existsSync()) {
      stderr.writeln('Error: Output directory "$outputOption" does not exist. Run "trellis build" first.');
      return 1;
    }

    // Create static file handler with clean URL support
    final handler = createStaticHandler(outputDir, defaultDocument: 'index.html');

    // Start the server
    final HttpServer server;
    try {
      server = await io.serve(handler, InternetAddress.loopbackIPv4, port);
    } on SocketException catch (e) {
      stderr.writeln('Error: Could not bind to port $port. ${e.message}');
      stderr.writeln('Try --port <another-port>.');
      return 1;
    }

    stdout.writeln('Serving http://localhost:$port from "$outputOption/"');
    stdout.writeln('Press Ctrl-C to stop.');

    // Wait for stop signal (Ctrl-C in production, injected future in tests)
    await (stopSignal ?? ProcessSignal.sigint.watch().first);
    await server.close();

    return 0;
  }
}
