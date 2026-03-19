import 'package:dart_frog/dart_frog.dart';
import 'package:trellis_dart_frog/trellis_dart_frog.dart';
import 'package:trellis_dart_frog_example/counter_state.dart';

Future<Response> onRequest(RequestContext context) async {
  return renderPage(context, 'pages/index.html', homeContext(), htmxFragment: 'page-content');
}
