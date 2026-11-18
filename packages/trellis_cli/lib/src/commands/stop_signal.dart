import 'dart:async';
import 'dart:io';

/// Completes on the first SIGINT (Ctrl-C) or SIGTERM (`kill`, a process manager, an IDE stop button), so a
/// long-running command can clean up before it exits.
///
/// Both subscriptions are cancelled once one signal arrives, so a second signal gets the default handling and
/// terminates a shutdown that hangs.
({Future<void> stopped, Future<void> Function() cancel}) processStopSignal() {
  final stopped = Completer<void>();
  final subscriptions = <StreamSubscription<ProcessSignal>>[];

  Future<void> cancel() async {
    await Future.wait(subscriptions.map((subscription) => subscription.cancel()));
  }

  void stop(ProcessSignal _) {
    if (stopped.isCompleted) return;
    unawaited(cancel());
    stopped.complete();
  }

  subscriptions.add(ProcessSignal.sigint.watch().listen(stop));
  // Windows supports watching SIGINT only; `ProcessSignal.sigterm.watch()` throws there.
  if (!Platform.isWindows) subscriptions.add(ProcessSignal.sigterm.watch().listen(stop));
  return (stopped: stopped.future, cancel: cancel);
}
