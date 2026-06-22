import 'package:html/dom.dart';
import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

class _TooltipProcessor extends Processor {
  @override
  String get attribute => 'tooltip';

  @override
  ProcessorPriority get priority => ProcessorPriority.afterContent;

  @override
  bool process(Element element, String value, ProcessorContext context) => true;
}

void main() {
  group('TemplateValidator', () {
    test('valid template returns no issues', () {
      final validator = TemplateValidator();

      final errors = validator.validate('<p tl:text="\${user.name}">x</p>');

      expect(errors, isEmpty);
    });

    test('accepts same-file fragment references', () {
      final validator = TemplateValidator();

      final errors = validator.validate('<div tl:insert="card(\${title}, \${body})"></div>');

      expect(errors, isEmpty);
    });

    test('reports expression parse errors and empty expressions', () {
      final validator = TemplateValidator();

      final errors = validator.validate('<div><p tl:text="\${user.name">x</p><span tl:text=""></span></div>');

      expect(errors.where((error) => error.severity == ValidationSeverity.error), hasLength(2));
      expect(errors.map((error) => error.attribute), containsAll(['tl:text']));
      expect(errors.any((error) => error.message.contains('empty')), isTrue);
    });

    test('reports unknown attributes as warnings', () {
      final validator = TemplateValidator();

      final errors = validator.validate('<p tl:textt="\${name}">x</p>');

      expect(errors, [
        isA<ValidationError>()
            .having((error) => error.severity, 'severity', ValidationSeverity.warning)
            .having((error) => error.attribute, 'attribute', 'tl:textt'),
      ]);
    });

    test('validates binding, each, remove, fragment reference, and case attributes', () {
      final validator = TemplateValidator();
      const template = '''
<div
  tl:with="name=\${user.name"
  tl:attr="href=\${link}, title=\${title"
  tl:remove="bogus value"
  tl:insert="~{layout :: card(\${title)}"
>
  <p tl:each="item \${items}" tl:case="\${value">x</p>
</div>
''';

      final errors = validator.validate(template);

      expect(errors.where((error) => error.severity == ValidationSeverity.error).length, 6);
      expect(
        errors.map((error) => error.attribute),
        containsAll(['tl:with', 'tl:attr', 'tl:remove', 'tl:insert', 'tl:case']),
      );
    });

    test('validates inline keyword values and fragment definitions', () {
      final validator = TemplateValidator();

      final errors = validator.validate('<div tl:inline="bogus" tl:fragment="card(, body)"></div>');

      expect(errors.where((error) => error.severity == ValidationSeverity.error), hasLength(2));
      expect(errors.map((error) => error.attribute), containsAll(['tl:inline', 'tl:fragment']));
    });

    test('applies self-closing block normalization', () {
      final validator = TemplateValidator();

      final errors = validator.validate('<div><tl:block tl:text="\${name}" /><p>ok</p></div>');

      expect(errors, isEmpty);
    });

    test('does not flag registered custom processor attributes', () {
      final validator = TemplateValidator(processors: [_TooltipProcessor()]);

      final errors = validator.validate('<p tl:tooltip="help">x</p>');

      expect(errors, isEmpty);
    });

    test('includeStandard false flags built-ins as unknown', () {
      final validator = TemplateValidator(includeStandard: false);

      final errors = validator.validate('<p tl:text="\${name}">x</p>');

      expect(errors, hasLength(1));
      expect(errors.single.severity, ValidationSeverity.warning);
      expect(errors.single.attribute, 'tl:text');
    });

    test('respects custom prefixes', () {
      final validator = TemplateValidator(prefix: 'data-tl');

      final errors = validator.validate('<p data-tl-text="\${name}">x</p>');

      expect(errors, isEmpty);
    });

    test('validateFile returns loader failures as errors', () async {
      final validator = TemplateValidator();

      final errors = await validator.validateFile('missing', MapLoader({}));

      expect(errors, hasLength(1));
      expect(errors.single.severity, ValidationSeverity.error);
      expect(errors.single.message, contains('Failed to load template'));
    });

    group('HTML5 parse-error surfacing', () {
      test('warns when a duplicate tl:attr is silently dropped', () {
        final validator = TemplateValidator();

        final errors = validator.validate('<a tl:attr="href=\${u}" tl:attr="title=\${t}">x</a>');

        final warnings = errors.where((error) => error.message.contains('Duplicate attribute')).toList();
        expect(warnings, hasLength(1));
        expect(warnings.single.severity, ValidationSeverity.warning);
      });

      test('warns when a tl:each block is foster-parented out of a table', () {
        final validator = TemplateValidator();

        final errors = validator.validate(
          '<table><tl:block tl:each="r : \${rows}"><tr><td tl:text="\${r}"></td></tr></tl:block></table>',
        );

        // A single block-in-table mistake raises both start- and end-tag voodoo
        // parse errors; they must collapse into one warning, not two.
        final warnings = errors.where((error) => error.message.contains('foster-parented')).toList();
        expect(warnings, hasLength(1));
        expect(warnings.single.severity, ValidationSeverity.warning);
      });

      test('does not warn for tl:each on <tr> directly inside a table', () {
        final validator = TemplateValidator();

        final errors = validator.validate('<table><tr tl:each="r : \${rows}"><td tl:text="\${r}"></td></tr></table>');

        expect(errors, isEmpty);
      });

      test('does not surface non-curated parser noise on doctype-less fragments', () {
        final validator = TemplateValidator();

        // Fragment templates have no <html>/doctype, so the HTML5 parser always
        // emits expected-doctype-but-got-start-tag. That noise must stay
        // unsurfaced; only the curated codes become warnings.
        final errors = validator.validate('<div tl:text="\${name}">x</div>');

        expect(errors, isEmpty);
      });
    });
  });
}
