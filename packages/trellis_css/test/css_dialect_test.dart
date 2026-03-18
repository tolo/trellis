import 'package:test/test.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_css/trellis_css.dart';

void main() {
  group('CssDialect', () {
    test('T16: name returns "CSS"', () {
      expect(CssDialect().name, 'CSS');
    });

    test('T17: processors contains ScopeProcessor and OrphanScopeProcessor', () {
      final processors = CssDialect().processors;
      expect(processors, hasLength(2));
      expect(processors[0], isA<ScopeProcessor>());
      expect(processors[1], isA<OrphanScopeProcessor>());
    });

    test('T18: filters returns empty map', () {
      expect(CssDialect().filters, isEmpty);
    });

    test('T19: engine with CssDialect renders simple template cleanly', () {
      final engine = Trellis(loader: MapLoader({}), cache: false, dialects: [CssDialect()]);
      final result = engine.render('<p tl:text="\${msg}">old</p>', {'msg': 'Hello'});
      expect(result, contains('Hello'));
      expect(result, isNot(contains('old')));
    });

    test('ScopeProcessor handles tl:fragment attribute at highest priority', () {
      final processor = ScopeProcessor();
      expect(processor.attribute, 'fragment');
      expect(processor.priority, ProcessorPriority.highest);
    });

    test('OrphanScopeProcessor handles tl:scope attribute at afterContent priority', () {
      final processor = OrphanScopeProcessor();
      expect(processor.attribute, 'scope');
      expect(processor.priority, ProcessorPriority.afterContent);
    });
  });
}
