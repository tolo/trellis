import 'dart:io';

import 'package:html/dom.dart';
import 'package:test/test.dart';
import 'package:trellis/testing.dart';
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

    test('reports a misplaced, repeated or unnamed rest parameter, as rendering does', () {
      final validator = TemplateValidator();

      for (final def in ['card(...attrs, x)', 'card(...)', 'card(...a, ...b)']) {
        final errors = validator.validate('<div tl:fragment="$def"></div>');
        expect(
          errors.where((error) => error.severity == ValidationSeverity.error && error.attribute == 'tl:fragment'),
          [isA<ValidationError>().having((e) => e.message, 'message', startsWith('Fragment "card": rest parameter'))],
          reason: def,
        );
      }
      expect('<div tl:fragment="card(x, ...attrs)"></div>', isValidTemplate());
    });

    test('reports a trailing empty parameter once, not also as a misplaced rest parameter', () {
      final errors = TemplateValidator().validate('<div tl:fragment="card(...a,)"></div>');

      expect(errors.map((error) => error.message), ['Fragment parameters cannot be empty']);
    });

    test('reports an empty fragment name once, not also as a rest parameter of fragment ""', () {
      final errors = TemplateValidator().validate('<div tl:fragment="(...a, b)"></div>');

      expect(errors.map((error) => error.message), ['Fragment name cannot be empty']);
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

    group('tl:attrs', () {
      test('is a recognized attribute', () {
        expect('<input class="trellis-field-input" type="text" tl:attrs="\${attrs}">', isValidTemplate());
      });

      test('value is validated as a single expression', () {
        final errors = TemplateValidator().validate('<input tl:attrs="\${">');

        expect(errors.map((e) => e.attribute), contains('tl:attrs'));
        expect(errors.map((e) => e.message), isNot(contains(contains('Unknown trellis attribute'))));
      });
    });

    group('tl:slot', () {
      test('definition and caller sides validate with no findings', () {
        const component =
            '<label tl:fragment="field(label)"><span tl:slot="hint">Hint</span><div tl:slot>Body</div></label>';
        const caller = '<div tl:replace="field(\'Email\')"><span tl:slot="hint">Mine</span><b tl:slot>Body</b></div>';

        expect(component, isValidTemplate());
        expect(caller, isValidTemplate());
      });

      test('is not reported as an unknown attribute', () {
        final errors = TemplateValidator().validate('<div tl:slot="x">a</div><div tl:slot>b</div>');

        expect(errors.map((e) => e.message), isNot(contains(contains('Unknown trellis attribute'))));
      });

      group('markers that can never bind', () {
        List<ValidationError> slotWarnings(String source) =>
            TemplateValidator().validate(source).where((e) => e.message.contains('tl:slot')).toList();

        test('warns once, at the marker line, for a marker nested below the invocation host', () {
          final warnings = slotWarnings(
            '<div tl:replace="~{ui :: card}">\n<div>\n<span tl:slot="footer">x</span></div></div>',
          );

          expect(warnings, hasLength(1));
          expect(warnings.single.severity, ValidationSeverity.warning);
          expect(warnings.single.line, 3);
          expect(warnings.single.attribute, 'tl:slot');
        });

        test('does not look through a <tl:block> grouping wrapper', () {
          final warnings = slotWarnings(
            '<div tl:insert="~{ui :: card}"><tl:block><span tl:slot="footer">x</span></tl:block></div>',
          );

          expect(warnings, hasLength(1));
          expect(warnings.single.severity, ValidationSeverity.warning);
        });

        test('warns for a marker nested inside another marker', () {
          final warnings = slotWarnings('<div tl:replace="card"><b tl:slot="a"><i tl:slot="b">x</i></b></div>');

          expect(warnings, hasLength(1));
        });

        test('is silent for a literal direct child of the host, named or anonymous', () {
          expect(
            '<div tl:replace="~{ui :: card}"><span tl:slot="footer">x</span><b tl:slot>y</b></div>',
            isValidTemplate(),
          );
          expect('<div tl:insert="card"><tl:block tl:slot="footer">x</tl:block></div>', isValidTemplate());
        });

        test('is silent for a definition-side region, with or without a host in the document', () {
          expect('<label tl:fragment="field(label, name)"><span tl:slot="hint"></span></label>', isValidTemplate());
          expect('<div><span tl:slot="hint"><i tl:slot="inner"></i></span></div>', isValidTemplate());
        });

        test('is silent for a region re-marked inside a passed marker, which forwards a slot', () {
          const reMarked =
              '<section tl:fragment="confirm"><div tl:replace="dlg">'
              '<span tl:slot="footer"><em tl:slot="actions">default</em></span></div></section>';
          expect(reMarked, isValidTemplate());
          expect(reMarked.replaceAll('tl:replace', 'tl:insert'), isValidTemplate());
        });

        group('in a definition, a marker in a host\'s unmarked content', () {
          List<ValidationError> slotErrors(String source) => TemplateValidator()
              .validate(source)
              .where((e) => e.message.contains('tl:slot') && e.severity == ValidationSeverity.error)
              .toList();

          test('is an error mirroring the engine message', () {
            final errors = slotErrors(
              '<section tl:fragment="confirm">\n<div tl:replace="dlg"><p>\n'
              '<i tl:slot="footer">OK</i></p></div></section>',
            );

            expect(errors, hasLength(1));
            expect(errors.single.line, 3);
            expect(errors.single.attribute, 'tl:slot');
            expect(
              errors.single.message,
              'tl:slot="footer" in fragment "confirm" is inside the unmarked content of a tl:replace host, so it '
              'neither fills that invocation\'s slot nor declares a slot of "confirm". To fill the inner slot, make '
              'it a direct child of the host; to forward a slot of "confirm", put it inside a direct-child slot '
              'marker, e.g. <tl:block tl:slot>.',
            );
          });

          test('names a padded slot name trimmed, as the engine does', () {
            final errors = slotErrors(
              '<section tl:fragment="confirm"><div tl:replace="dlg"><p><i tl:slot=" footer ">OK</i></p></div>'
              '</section>',
            );

            expect(errors.single.message, startsWith('tl:slot="footer" in fragment "confirm" is inside'));
          });

          test('is an error when the fragment root is itself the host', () {
            final errors = slotErrors('<div tl:fragment="confirm" tl:insert="dlg"><p><i tl:slot="x">OK</i></p></div>');

            expect(errors, hasLength(1));
            expect(errors.single.message, contains('unmarked content of a tl:insert host'));
          });

          test('is an error inside a region\'s fallback content, as in the engine', () {
            for (final definition in [
              '<section tl:fragment="c"><div tl:slot="body"><div tl:insert="dlg"><p><i tl:slot="footer">X</i></p></div>'
                  '</div></section>',
              '<section tl:fragment="c"><div tl:slot="body" tl:insert="dlg"><p><i tl:slot="footer">X</i></p></div>'
                  '</section>',
            ]) {
              final errors = slotErrors(definition);

              expect(errors, hasLength(1), reason: definition);
              expect(errors.single.message, startsWith('tl:slot="footer" in fragment "c" is inside the unmarked'));
            }
          });

          test('stays a warning on a page, where the marker is merely inert', () {
            final findings = TemplateValidator().validate('<div tl:replace="dlg"><p><i tl:slot="x">OK</i></p></div>');

            expect(slotErrors('<div tl:replace="dlg"><p><i tl:slot="x">OK</i></p></div>'), isEmpty);
            expect(findings.where((e) => e.message.contains('tl:slot')).single.severity, ValidationSeverity.warning);
          });

          test('is clean for a region re-marked inside a nested host\'s direct-child marker', () {
            expect(
              '<section tl:fragment="confirm"><div tl:replace="dlg"><div><p tl:replace="dlg">'
              '<span tl:slot="footer"><em tl:slot="actions">d</em></span></p></div></div></section>',
              isValidTemplate(),
            );
          });
        });

        test('treats a definition nested under a host as definition-side', () {
          expect(
            '<div tl:replace="card"><section tl:fragment="inner(x)"><p tl:slot="body"></p></section></div>',
            isValidTemplate(),
          );
        });

        test('honours a custom prefix', () {
          final errors = TemplateValidator(
            prefix: 'data-tl',
          ).validate('<div data-tl-replace="card"><div><span data-tl-slot="a">x</span></div></div>');

          final warnings = errors.where((e) => e.message.contains('data-tl-slot'));
          expect(warnings, hasLength(1));
          expect(warnings.single.message, allOf(contains('data-tl-insert/data-tl-replace'), isNot(contains('tl:'))));
        });
      });
    });

    group('literal id in a parameterized fragment', () {
      List<ValidationError> idWarnings(String source) =>
          TemplateValidator().validate(source).where((e) => e.message.contains('id="')).toList();

      test('warns at the offending element, naming the id and the dynamic alternative', () {
        final warnings = idWarnings(
          '<div tl:fragment="card(title)">\n<h2 id="card-title" tl:text="\${title}">T</h2></div>',
        );

        expect(warnings, hasLength(1));
        expect(warnings.single.severity, ValidationSeverity.warning);
        expect(warnings.single.message, allOf(contains('card-title'), contains('tl:id'), contains('tl:attrs')));
        expect(warnings.single.line, 2);
        expect(warnings.single.element, 'h2');
      });

      test('names the configured prefix in its remedy', () {
        final warnings = TemplateValidator(
          prefix: 'data-tl',
        ).validate('<div data-tl-fragment="card(t)"><h2 id="x">T</h2></div>').where((e) => e.message.contains('id="'));

        expect(warnings.single.message, allOf(contains('data-tl-id or data-tl-attrs'), isNot(contains('tl:'))));
      });

      test('warns for an id on the fragment root and for each descendant id', () {
        final warnings = idWarnings(
          '<div tl:fragment="card(a, ...rest)" id="root"><i id="x"></i><b><u id="y"></u></b></div>',
        );

        expect(warnings.map((w) => w.element), ['div', 'i', 'u']);
      });

      test('stays silent for a parameterless fragment (HTMX swap-target idiom)', () {
        expect('<div tl:fragment="todo-list"><div id="todo-list"></div></div>', isValidTemplate());
        expect('<div tl:fragment="todo-list()" id="todo-list"></div>', isValidTemplate());
      });

      test('stays silent for a dynamic id and for a literal id overridden by tl:id or tl:attr', () {
        expect('<div tl:fragment="card(id)" tl:id="\${id}"><h2 tl:id="\${id}">T</h2></div>', isValidTemplate());
        expect('<div tl:fragment="card(id)"><h2 id="proto" tl:id="\${id}">T</h2></div>', isValidTemplate());
        expect(
          '<div tl:fragment="card(id)"><h2 id="proto" tl:attr="title=\'t\',id=\${id}">T</h2></div>',
          isValidTemplate(),
        );
      });

      test('stops at a nested fragment and leaves it to its own parameter list', () {
        final source =
            '<div tl:fragment="outer(a)"><section tl:fragment="inner" id="swap"><i id="s"></i></section>'
            '<p tl:fragment="deep(b)"><u id="d"></u></p></div>';

        final warnings = idWarnings(source);

        expect(warnings.map((w) => w.element), ['u']);
      });

      test('stays silent for an id outside any fragment', () {
        expect('<div id="a"><span id="b"></span></div>', isValidTemplate());
      });
    });

    group('<tl:block tl:slot> in a table', () {
      test('reports the foster-parenting warning once and no slot-specific warning', () {
        final errors = TemplateValidator().validate(
          '<table><tbody><tr tl:replace="~{ui :: row}"><tl:block tl:slot="cells"><td>x</td></tl:block></tr></tbody>'
          '</table>',
        );

        expect(errors.where((e) => e.message.contains('foster-parented')), hasLength(1));
        expect(errors.where((e) => e.message.contains('tl:slot')), isEmpty);
      });
    });

    group('component fixtures', () {
      for (final name in ['components.html', 'application.html']) {
        test('validate clean: $name', () {
          expect(File('test/fixtures/components/$name').readAsStringSync(), isValidTemplate());
        });
      }
    });

    group('real example and theme templates', () {
      // Run from packages/trellis (how `dart test` and Melos run it); the repo root is two levels up.
      // The paths are explicit because themes/<theme>/example/themes/<theme> links back to the theme.
      const templates = [
        'examples/todo_app/templates/app.html',
        'examples/relic_app/templates/index.html',
        'examples/dart_frog_app/templates/pages/index.html',
        'examples/shelf_app/templates/pages/index.html',
        'themes/arbor/layouts/base.html',
        'themes/lattice/layouts/base.html',
        'themes/folio/layouts/base.html',
        'themes/arbor/example/themes/arbor/layouts/base.html',
        'themes/lattice/example/themes/lattice/layouts/base.html',
        'themes/folio/example/themes/folio/layouts/base.html',
      ];

      for (final template in templates) {
        test('raises no composition warning for $template', () {
          final file = File('../../$template');
          if (!file.existsSync()) fail('$template not found: run from the packages/trellis directory');

          final errors = TemplateValidator().validate(file.readAsStringSync());

          expect(errors.where((e) => e.message.contains('tl:slot') || e.message.contains('id="')), isEmpty);
        });
      }
    });
  });
}
