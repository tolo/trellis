import 'package:shelf/shelf.dart';

import 'engine_middleware.dart';
import 'htmx_helpers.dart';
import 'request_context.dart';
import 'response_utils.dart';

/// Renders a full page template, or a specific fragment for HTMX requests.
///
/// Uses [getEngine] to retrieve the Trellis engine from the request context.
/// Automatically merges request-context values (e.g. CSRF token) into the
/// template context.
///
/// When [htmxFragment] is provided and the request is an HTMX request,
/// renders only the named fragment instead of the full page.
///
/// ```dart
/// return renderPage(request, 'index', {'title': 'Home'},
///     htmxFragment: 'content');
/// ```
Future<Response> renderPage(
  Request request,
  String template,
  Map<String, dynamic> context, {
  String? htmxFragment,
}) async {
  final engine = getEngine(request);
  final merged = mergeRequestContext(request, context);
  if (htmxFragment != null && isHtmxRequest(request)) {
    return htmlResponse(await engine.renderFileFragment(template, fragment: htmxFragment, context: merged));
  }
  return htmlResponse(await engine.renderFile(template, merged));
}

/// Renders a single named fragment from a template.
///
/// Uses [getEngine] to retrieve the Trellis engine from the request context.
/// Automatically merges request-context values (e.g. CSRF token) into the
/// template context.
///
/// ```dart
/// return renderFragment(request, 'todos', 'todo-list', {'items': todos});
/// ```
Future<Response> renderFragment(Request request, String template, String fragment, Map<String, dynamic> context) async {
  final engine = getEngine(request);
  final merged = mergeRequestContext(request, context);
  return htmlResponse(await engine.renderFileFragment(template, fragment: fragment, context: merged));
}

/// Renders multiple named fragments concatenated for HTMX out-of-band swaps.
///
/// Uses [getEngine] to retrieve the Trellis engine from the request context.
/// Automatically merges request-context values (e.g. CSRF token) into the
/// template context.
///
/// ```dart
/// return renderOobFragments(request, 'todos', ['todo-list', 'todo-count'],
///     {'items': todos, 'count': todos.length});
/// ```
Future<Response> renderOobFragments(
  Request request,
  String template,
  List<String> fragments,
  Map<String, dynamic> context,
) async {
  final engine = getEngine(request);
  final merged = mergeRequestContext(request, context);
  return htmlResponse(await engine.renderFileFragments(template, fragments: fragments, context: merged));
}
