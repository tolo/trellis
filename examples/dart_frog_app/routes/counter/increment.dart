import 'package:dart_frog/dart_frog.dart';
import 'package:trellis_dart_frog/trellis_dart_frog.dart';
import 'package:trellis_dart_frog_example/counter_state.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  incrementCounter();
  return renderFragment(context, 'pages/index.html', 'counter', counterContext());
}
