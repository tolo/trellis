import 'dart:io';

/// Runs an external process.
typedef ProcessRunner = Future<ProcessResult> Function(String executable, List<String> arguments);

/// Default [ProcessRunner] backed by [Process.run].
Future<ProcessResult> runProcess(String executable, List<String> arguments) => Process.run(executable, arguments);
