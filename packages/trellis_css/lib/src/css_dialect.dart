import 'package:trellis/trellis.dart';

import 'scope_processor.dart';

/// Trellis CSS dialect — provides `tl:scope` processor for fragment-scoped CSS.
///
/// Register this dialect when creating a [Trellis] engine to enable CSS
/// scoping via the `tl:scope` attribute.
///
/// ```dart
/// import 'package:trellis/trellis.dart';
/// import 'package:trellis_css/trellis_css.dart';
///
/// // With warning forwarding:
/// final engine = Trellis(
///   dialects: [CssDialect(onWarning: (msg) => print('CSS: $msg'))],
/// );
///
/// // Silent (default):
/// final engine = Trellis(dialects: [CssDialect()]);
/// ```
class CssDialect extends Dialect {
  /// Called when a misplaced `tl:scope` attribute is encountered.
  ///
  /// Forwarded to [OrphanScopeProcessor]. If `null`, warnings are silently
  /// dropped.
  final void Function(String message)? onWarning;

  CssDialect({this.onWarning});

  @override
  String get name => 'CSS';

  @override
  List<Processor> get processors => [ScopeProcessor(), OrphanScopeProcessor(onWarning: onWarning)];
}
