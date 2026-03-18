import 'package:dart_frog/dart_frog.dart';
import 'package:trellis/trellis.dart';

/// Middleware that makes a [Trellis] engine available via `context.read<Trellis>()`.
///
/// Use in `routes/_middleware.dart`:
/// ```dart
/// import 'package:trellis/trellis.dart';
/// import 'package:trellis_dart_frog/trellis_dart_frog.dart';
///
/// final _engine = Trellis();
///
/// Handler middleware(Handler handler) {
///   return handler.use(trellisProvider(_engine));
/// }
/// ```
Middleware trellisProvider(Trellis engine) {
  return provider<Trellis>((_) => engine);
}
