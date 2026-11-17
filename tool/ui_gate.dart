import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'ui_gate/checks.dart';
import 'ui_gate/manifest.dart';
import 'ui_gate/record.dart';
import 'ui_gate/run.dart';

Future<void> main(List<String> args) async {
  exitCode = await uiGate(args);
}

/// Validates recipes first, then owns the optional server and browser runs.
Future<int> uiGate(List<String> arguments) async {
  Process? server;
  StreamSubscription<String>? stdoutLines, stderrLines;
  final serverLog = <String>[];
  try {
    final args = _arguments(arguments);
    if (args['help'] == true) {
      stdout.writeln(
        'ui_gate --base <url> | --serve <command> [--manifests <dir>] [--records <dir>]\n'
        '[--baselines <dir>] [--captures <dir>] [--browsers chrome,firefox] [--record] [components or manifests]',
      );
      return 0;
    }
    if ((args['base'] == null) == (args['serve'] == null))
      throw const FormatException('exactly one of --base or --serve is required');
    if (args['record'] == true && Platform.environment['CI'] == 'true')
      throw const FormatException('--record is refused when CI=true');
    final directory = Directory(args['manifests'] as String);
    final names = args['components']! as List<String>;
    final files = names.isEmpty
        ? (directory.existsSync()
              ? directory.listSync().whereType<File>().where((f) => p.extension(f.path) == '.yaml').toList()
              : <File>[])
        : names.map((name) => File(name.endsWith('.yaml') ? name : p.join(directory.path, '$name.yaml'))).toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    if (files.isEmpty) throw const FormatException('manifests: no component manifests found');
    final manifests = files.map(GateManifest.load).toList();
    if (manifests.map((m) => m.name).toSet().length != manifests.length)
      throw const FormatException('manifests: duplicate component name');
    final browsers = (args['browsers'] as String).split(',');
    if (browsers.isEmpty || browsers.any((b) => !{'chrome', 'firefox'}.contains(b)))
      throw const FormatException('browsers: expected chrome,firefox');
    Uri base;
    if (args['serve'] != null) {
      server = await Process.start('/bin/sh', ['-c', 'exec ${args['serve']}']);
      final first = Completer<String>();
      void log(String line) {
        if (serverLog.length < 100) serverLog.add(line);
      }

      stdoutLines = server.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        log(line);
        if (!first.isCompleted) first.complete(line);
      });
      stderrLines = server.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen(log);
      final line = await first.future.timeout(const Duration(seconds: 30));
      if (!line.startsWith('Serving '))
        throw FormatException('--serve: first stdout line must be Serving <base-url>, actual $line');
      base = Uri.parse(line.substring(8).trim());
    } else {
      base = Uri.parse(args['base'] as String);
    }
    if (!{'http', 'https'}.contains(base.scheme) || !base.hasAuthority)
      throw const FormatException('base: expected an HTTP URL');
    for (final manifest in manifests) {
      await manifest.validatePage(base);
    }
    final recordDir = Directory(args['records'] as String)..createSync(recursive: true);
    var success = true;
    for (final manifest in manifests) {
      final runs = <String, Map<String, GateResult>>{};
      for (final browser in browsers) {
        runs[browser] = await runGate(
          manifest,
          base,
          browser,
          baselines: Directory(args['baselines'] as String),
          record: args['record'] as bool,
          captures: args['captures'] == null ? null : Directory(args['captures'] as String),
        );
      }
      final file = File(p.join(recordDir.path, '${manifest.name}.json'));
      final previous = file.existsSync() ? (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>() : null;
      final record = gateRecord(manifest.name, runs, previous: previous);
      file.writeAsStringSync(encodeRecord(record));
      stdout.writeln('${manifest.name}: ${record['automated']}');
      for (final item in (record['items'] as Map).entries) {
        final value = item.value as Map;
        if (value['status'] != 'pass' && value['status'] != 'release-prep')
          stdout.writeln('  ${item.key}: ${jsonEncode(value)}');
      }
      if (record['automated'] != 'pass') success = false;
    }
    return success ? 0 : 1;
  } on Object catch (error) {
    stderr.writeln('ui_gate: $error');
    if (serverLog.isNotEmpty) stderr.writeln(serverLog.join('\n'));
    return 1;
  } finally {
    if (server != null) {
      server.kill();
      await server.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          server!.kill(ProcessSignal.sigkill);
          return server.exitCode;
        },
      );
    }
    await stdoutLines?.cancel();
    await stderrLines?.cancel();
  }
}

Map<String, Object?> _arguments(List<String> values) {
  final result = <String, Object?>{
    'manifests': 'dev/ui-gate/manifests',
    'records': 'dev/ui-gate/records',
    'baselines': 'dev/ui-gate/baselines',
    'browsers': 'chrome,firefox',
    'record': false,
    'help': false,
  };
  final components = <String>[];
  for (var i = 0; i < values.length; i++) {
    final value = values[i];
    if (value == '--record' || value == '--help' || value == '-h') {
      result[value == '--record' ? 'record' : 'help'] = true;
      continue;
    }
    if (!value.startsWith('--')) {
      components.add(value);
      continue;
    }
    final parts = value.substring(2).split('=');
    final key = parts.first;
    if (!{'base', 'serve', 'manifests', 'records', 'baselines', 'captures', 'browsers'}.contains(key)) {
      throw FormatException('unknown option: --$key');
    }
    if (parts.length > 1) {
      result[key] = parts.skip(1).join('=');
    } else {
      if (++i >= values.length) throw FormatException('--$key requires a value');
      result[key] = values[i];
    }
  }
  result['components'] = components;
  return result;
}
