import 'package:relic/relic.dart';
import 'package:trellis/trellis.dart';

import 'htmx_helpers.dart';
import 'response_utils.dart';

/// Renders a full page template, or a specific fragment for HTMX requests.
///
/// The [engine] is passed explicitly (Relic has no DI mechanism).
///
/// When [htmxFragment] is provided and the request is an HTMX request,
/// renders only the named fragment instead of the full page.
///
/// ```dart
/// return renderPage(request, engine, 'pages/index', {'title': 'Home'},
///     htmxFragment: 'content');
/// ```
Future<Response> renderPage(
  Request request,
  Trellis engine,
  String template,
  Map<String, dynamic> context, {
  String? htmxFragment,
}) async {
  if (htmxFragment != null && isHtmxRequest(request)) {
    return htmlResponse(
      await engine.renderFileFragment(
        template,
        fragment: htmxFragment,
        context: context,
      ),
    );
  }
  return htmlResponse(await engine.renderFile(template, context));
}

/// Renders a single named fragment from a template.
///
/// The [engine] is passed explicitly (Relic has no DI mechanism).
///
/// ```dart
/// return renderFragment(request, engine, 'todos', 'todo-list',
///     {'items': todos});
/// ```
Future<Response> renderFragment(
  Request request,
  Trellis engine,
  String template,
  String fragment,
  Map<String, dynamic> context,
) async {
  return htmlResponse(
    await engine.renderFileFragment(
      template,
      fragment: fragment,
      context: context,
    ),
  );
}

/// Renders multiple named fragments concatenated for HTMX out-of-band swaps.
///
/// The [engine] is passed explicitly (Relic has no DI mechanism).
///
/// ```dart
/// return renderOobFragments(request, engine, 'todos',
///     ['todo-list', 'todo-count'], {'items': todos, 'count': 5});
/// ```
Future<Response> renderOobFragments(
  Request request,
  Trellis engine,
  String template,
  List<String> fragments,
  Map<String, dynamic> context,
) async {
  return htmlResponse(
    await engine.renderFileFragments(
      template,
      fragments: fragments,
      context: context,
    ),
  );
}
