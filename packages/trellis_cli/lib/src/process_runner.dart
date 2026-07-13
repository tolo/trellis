import 'dart:io';

/// Runs an external process.
typedef ProcessRunner = Future<ProcessResult> Function(String executable, List<String> arguments);

/// [ProcessException.errorCode] for "file not found": `ENOENT` on POSIX and
/// `ERROR_FILE_NOT_FOUND` on Windows both surface as 2 — the signal that the
/// spawned executable (here, `git`) is missing from PATH.
const int fileNotFoundErrorCode = 2;

/// Default [ProcessRunner] backed by [Process.run].
Future<ProcessResult> runProcess(String executable, List<String> arguments) => Process.run(executable, arguments);
