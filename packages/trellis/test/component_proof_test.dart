// The ADR-014 / ADR-012 prerequisite proof: all six candidate components are plain fragments built from tl:slot,
// tl:attrs and a rest parameter. The fixtures are authored as they would ship to a user; nothing here lives in lib/.
import 'dart:io';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:test/test.dart';
import 'package:trellis/testing.dart';

import 'test_paths.dart';

String _fixture(String name) => File('${packageRoot.path}/test/fixtures/components/$name').readAsStringSync();

void main() {
  final components = _fixture('components.html');
  final application = _fixture('application.html');

  // Strict mode, no processors, no dialects, default includeStandard.
  final engine = testEngine(templates: {'ui/components.html': components});

  final context = <String, dynamic>{
    'item': {'id': 7},
    'countries': [
      {'code': 'se', 'name': 'Sweden'},
      {'code': 'no', 'name': 'Norway'},
    ],
    'people': [
      {'name': 'Ada'},
      {'name': 'Grace'},
    ],
  };

  late Document rendered;
  setUpAll(() => rendered = html_parser.parse(engine.render(application, context)));

  group('six ADR-012 candidates as plain fragments', () {
    test('the engine registers no custom processor or dialect', () {
      expect(engine.processors, anyOf(isNull, isEmpty));
      expect(engine.dialects, anyOf(isNull, isEmpty));
      expect(engine.includeStandard, isTrue);
      expect(engine.strict, isTrue);
    });

    test('leaves no tl:* attribute or expression text in the output', () {
      final html = engine.render(application, context);
      expect(html, isNot(contains('tl:')));
      expect(html, isNot(contains(r'${')));
    });

    test('field: caller attributes land on the input, the spread overwrites the literal type, hint fills its slot', () {
      final input = rendered.querySelector('label.trellis-field input')!;
      expect(input.attributes['type'], 'email'); // literal type="text" overwritten
      expect(input.attributes['required'], ''); // valueless boolean round-trips valueless
      expect(input.attributes['hx-post'], '/validate');
      expect(input.attributes['hx-trigger'], 'blur');
      expect(input.attributes['name'], 'email');
      expect(input.attributes['class'], 'trellis-field-input');
      expect(rendered.querySelector('.trellis-field-label')!.text, 'Email');
      expect(rendered.querySelector('.trellis-field-hint')!.text, 'We never share your email.');
    });

    test('dialog: id and caller attributes on the root, body and footer filled, footer expression resolved', () {
      final dialog = rendered.querySelector('dialog.trellis-dialog')!;
      expect(dialog.attributes['id'], 'confirm');
      expect(dialog.attributes['data-testid'], 'confirm');
      expect(dialog.querySelector('h2')!.text, 'Delete item?');
      expect(dialog.querySelector('.trellis-dialog-body p')!.text, 'This action cannot be undone.');
      final footerButtons = dialog.querySelectorAll('footer button');
      expect(footerButtons.map((b) => b.text), ['Delete', 'Cancel']);
      expect(footerButtons.first.attributes['hx-delete'], '/items?id=7');
    });

    test('dropdown: menu items fill the anonymous slot, footer fills its slot, trigger is wired to the menu', () {
      final dropdown = rendered.querySelector('.trellis-dropdown')!;
      expect(dropdown.attributes['data-align'], 'end');
      expect(dropdown.querySelector('button')!.attributes['aria-controls'], 'actions');
      final items = dropdown.querySelectorAll('.trellis-dropdown-menu a');
      expect(items.map((a) => a.attributes['href']), ['/items/edit?id=7', '/items/archive?id=7']);
      expect(dropdown.querySelector('.trellis-dropdown-menu')!.attributes['id'], 'actions');
      expect(dropdown.querySelector('.trellis-dropdown-footer small')!.text, '2 actions');
    });

    test('combobox: attributes land on the select, caller options replace the fallback option', () {
      final select = rendered.querySelector('.trellis-combobox select')!;
      expect(select.attributes['required'], '');
      expect(select.attributes['hx-get'], '/cities');
      expect(select.attributes['name'], 'country');
      expect(select.querySelectorAll('option').map((o) => '${o.attributes['value']}:${o.text}'), [
        ':Pick a country',
        'se:Sweden',
        'no:Norway',
      ]);
    });

    test('table: caller row markup is cloned per iteration and sees the loop variable', () {
      final body = rendered.querySelector('table#table tbody')!;
      expect(body.attributes['class'], 'trellis-table-body striped');
      expect(body.querySelectorAll('tr td').map((td) => td.text), ['Ada', 'Grace']);
      expect(body.querySelectorAll('tr'), hasLength(2));
    });

    test('toast: type becomes a modifier class, unmarked host text fills the body, actions fill their slot', () {
      final toast = rendered.querySelector('.trellis-toast')!;
      expect(toast.attributes['class'], 'trellis-toast error');
      expect(toast.attributes['aria-live'], 'polite');
      expect(toast.querySelector('.trellis-toast-title')!.text, 'Saved');
      expect(toast.querySelector('.trellis-toast-body')!.text.trim(), 'Everything went fine.');
      expect(toast.querySelector('.trellis-toast-actions button')!.text, 'Undo');
    });

    test('fallbacks apply when the caller supplies no content', () {
      final html = engine.render(
        '<div tl:replace="~{ui/components.html :: dialog(\'d\', \'T\')}"></div>'
        '<div tl:replace="~{ui/components.html :: field(\'L\', \'n\')}"></div>',
        {},
      );
      final doc = html_parser.parse(html);
      expect(doc.querySelector('.trellis-dialog-body')!.text, 'Body');
      expect(doc.querySelector('footer button')!.text, 'Close');
      expect(doc.querySelector('input')!.attributes['type'], 'text');
      expect(doc.querySelector('.trellis-field-hint')!.text, isEmpty);
    });

    test('table: an empty rows list renders an empty tbody', () {
      final html = engine.render(
        r'<table><tbody tl:replace="~{ui/components.html :: table(${people})}">'
        r'<tr tl:slot="row"><td tl:text="${row.name}">Name</td></tr></tbody></table>',
        {'people': <Object>[]},
      );
      expect(html_parser.parse(html).querySelectorAll('tbody tr'), isEmpty);
    });
  });

  group('natural templates', () {
    test('component and application files are valid trellis templates', () {
      expect(components, isValidTemplate());
      expect(application, isValidTemplate());
    });

    test('component fallbacks are present in the unprocessed DOM', () {
      final doc = html_parser.parse(components);
      final text = doc.body!.text;
      for (final fallback in ['Label', 'Title', 'Body', 'Close', 'Menu', 'Item', 'Choose', 'Name', 'Message']) {
        expect(text, contains(fallback), reason: 'fallback "$fallback"');
      }
    });

    test('caller placeholders are present in the unprocessed DOM', () {
      final text = html_parser.parse(application).body!.text;
      for (final placeholder in [
        'We never share your email.',
        'This action cannot be undone.',
        'Delete',
        'Cancel',
        'Edit',
        'Archive',
        '2 actions',
        'Pick a country',
        'Sweden',
        'Name',
        'Everything went fine.',
        'Undo',
      ]) {
        expect(text, contains(placeholder), reason: 'placeholder "$placeholder"');
      }
    });

    test('table and select markers stay inside their parents (no foster-parenting)', () {
      final componentDoc = html_parser.parse(components);
      expect(componentDoc.querySelectorAll('table > tbody[tl\\:fragment] > tr[tl\\:slot=row]'), hasLength(1));
      expect(componentDoc.querySelectorAll('select[tl\\:slot=options] > option'), hasLength(1));

      final appDoc = html_parser.parse(application);
      expect(appDoc.querySelectorAll('table#table > tbody[tl\\:replace] > tr[tl\\:slot=row] > td'), hasLength(1));
      expect(appDoc.querySelectorAll('div[tl\\:replace] > optgroup[tl\\:slot=options] > option'), hasLength(2));
      // No marker or slot element ended up outside the context it was written in.
      expect(appDoc.querySelectorAll('table > tl\\:block, tr > tl\\:block, select > tl\\:block'), isEmpty);
      for (final marker in appDoc.querySelectorAll('[tl\\:slot]')) {
        expect(marker.parent, isNotNull, reason: '<${marker.localName}> kept its parent');
      }
      expect(appDoc.querySelectorAll('[tl\\:slot]'), hasLength(6));
    });
  });
}
