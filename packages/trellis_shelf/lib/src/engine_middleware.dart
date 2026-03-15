import 'package:shelf/shelf.dart';
import 'package:trellis/trellis.dart';

/// Context key for the Trellis engine instance.
const _engineContextKey = 'trellis_shelf.engine';

/// Middleware that injects a [Trellis] engine into the Shelf request context.
///
/// Downstream handlers retrieve the engine via [getEngine].
///
/// ```dart
/// final pipeline = const Pipeline()
///     .addMiddleware(trellisEngine(engine))
///     .addHandler(myHandler);
/// ```
Middleware trellisEngine(Trellis engine) {
  return (Handler innerHandler) {
    return (Request request) {
      return innerHandler(request.change(context: {_engineContextKey: engine}));
    };
  };
}

/// Retrieves the [Trellis] engine from the request context.
///
/// Throws [StateError] if [trellisEngine] middleware has not been applied.
Trellis getEngine(Request request) {
  final engine = request.context[_engineContextKey];
  if (engine == null) {
    throw StateError(
      'No Trellis engine found in request context. '
      'Did you forget to add trellisEngine() middleware?',
    );
  }
  return engine as Trellis;
}
