import 'package:dart_frog/dart_frog.dart';
import 'package:trellis/trellis.dart';

import 'htmx_helpers.dart';
import 'request_context_utils.dart';

/// Renders a full page template, or a specific fragment for HTMX requests.
///
/// Retrieves the Trellis engine via `context.read<Trellis>()`.
/// Automatically merges CSRF token (if present) into the template context.
///
/// When [htmxFragment] is provided and the request is an HTMX request,
/// renders only the named fragment instead of the full page.
///
/// ```dart
/// Future<Response> onRequest(RequestContext context) async {
///   return renderPage(context, 'index', {'title': 'Home'},
///       htmxFragment: 'content');
/// }
/// ```
Future<Response> renderPage(
  RequestContext context,
  String template,
  Map<String, dynamic> templateContext, {
  String? htmxFragment,
}) async {
  final engine = context.read<Trellis>();
  final merged = mergeRequestContext(context, templateContext);
  if (htmxFragment != null && isHtmxRequest(context)) {
    final html = await engine.renderFileFragment(template, fragment: htmxFragment, context: merged);
    return _htmlResponse(html);
  }
  final html = await engine.renderFile(template, merged);
  return _htmlResponse(html);
}

/// Renders a single named fragment from a template.
///
/// Retrieves the Trellis engine via `context.read<Trellis>()`.
/// Automatically merges CSRF token (if present) into the template context.
///
/// ```dart
/// Future<Response> onRequest(RequestContext context) async {
///   return renderFragment(context, 'todos', 'todo-list', {'items': todos});
/// }
/// ```
Future<Response> renderFragment(
  RequestContext context,
  String template,
  String fragment,
  Map<String, dynamic> templateContext,
) async {
  final engine = context.read<Trellis>();
  final merged = mergeRequestContext(context, templateContext);
  final html = await engine.renderFileFragment(template, fragment: fragment, context: merged);
  return _htmlResponse(html);
}

/// Renders multiple named fragments concatenated for HTMX out-of-band swaps.
///
/// Retrieves the Trellis engine via `context.read<Trellis>()`.
/// Automatically merges CSRF token (if present) into the template context.
///
/// ```dart
/// Future<Response> onRequest(RequestContext context) async {
///   return renderOobFragments(context, 'todos', ['todo-list', 'todo-count'],
///       {'items': todos, 'count': todos.length});
/// }
/// ```
Future<Response> renderOobFragments(
  RequestContext context,
  String template,
  List<String> fragments,
  Map<String, dynamic> templateContext,
) async {
  final engine = context.read<Trellis>();
  final merged = mergeRequestContext(context, templateContext);
  final html = await engine.renderFileFragments(template, fragments: fragments, context: merged);
  return _htmlResponse(html);
}

Response _htmlResponse(String html) {
  return Response(body: html, headers: {'content-type': 'text/html; charset=utf-8'});
}
