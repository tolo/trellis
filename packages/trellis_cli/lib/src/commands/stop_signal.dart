import 'dart:async';
import 'dart:io';

/// Completes on the first SIGINT (Ctrl-C) or SIGTERM (`kill`, a process manager, an IDE stop button), so a
/// long-running command can clean up before it exits.
///
/// Both subscriptions are cancelled once one signal arrives, so a second signal gets the default handling and
/// terminates a shutdown that hangs.
Future<void> processStopSignal() {
  final stopped = Completer<void>();
  final subscriptions = <StreamSubscription<ProcessSignal>>[];
  void stop(ProcessSignal _) {
    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }
    if (!stopped.isCompleted) stopped.complete();
  }

  subscriptions.add(ProcessSignal.sigint.watch().listen(stop));
  // Windows supports watching SIGINT only; `ProcessSignal.sigterm.watch()` throws there.
  if (!Platform.isWindows) subscriptions.add(ProcessSignal.sigterm.watch().listen(stop));
  return stopped.future;
}
