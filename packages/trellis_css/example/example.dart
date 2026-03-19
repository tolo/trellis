import 'package:trellis/trellis.dart';
import 'package:trellis_css/trellis_css.dart';

void main() {
  final css = TrellisCss.compileSassString(r'''
    $primary: #2563eb;

    .button {
      color: $primary;
    }
  ''');

  final engine = Trellis(dialects: [CssDialect()], loader: MapLoader({}));

  print(css);
  print(engine.runtimeType);
}
