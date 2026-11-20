import 'package:html/parser.dart';
import 'package:test/test.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_ui/trellis_ui.dart';

void main() {
  test('out-of-scale values fall back and no style attribute is written', () {
    final engine = Trellis(loader: TrellisUiLoader(), strict: true);
    for (final name in ['stack', 'cluster', 'grid', 'container']) {
      final args = name == 'grid' ? "'arbitrary', '1px'" : "'arbitrary'";
      final doc = parseFragment(
        engine.render(
          '<div tl:replace="~{trellis-ui/$name :: $name($args)}" class="app-layout"><p>First</p><p>Second</p></div>',
          {},
        ),
      );
      final root = doc.querySelector('div')!;
      expect(
        root.classes,
        containsAll(['trellis-$name', 'app-layout', 'trellis-$name-${name == 'container' ? 'size-lg' : 'gap-md'}']),
      );
      if (name == 'grid') expect(root.classes, contains('trellis-grid-minimum-md'));
      expect(doc.querySelectorAll('[style]'), isEmpty);
      expect(root.querySelectorAll('p').map((e) => e.text), ['First', 'Second']);
      expect(root.classes.any((c) => c.contains('arbitrary') || c.contains('1px')), isFalse);
    }
  });
}
