import 'package:trellis/trellis.dart';

Future<void> main() async {
  final engine = Trellis(loader: MapLoader({'greeting.html': r'<h1 tl:text="${title}">Hello</h1>'}));

  final html = await engine.renderFile('greeting.html', {'title': 'Hello Trellis'});

  print(html);
}
