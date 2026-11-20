import 'dart:io';

import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:test/test.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_ui/trellis_ui.dart';

void main() {
  final engine = Trellis(loader: TrellisUiLoader(), strict: true);
  DocumentFragment render(String source, [Map<String, dynamic> data = const {}]) {
    final output = engine.render(source, data);
    expect(output, isNot(contains('tl:')));
    return parseFragment(output);
  }

  test('text-entry fragments render native elements, defaults and pass attributes through', () {
    for (final name in ['input', 'textarea', 'native-select']) {
      final tag = name == 'native-select' ? 'select' : name;
      for (final extra in ['', ' class="app-x"']) {
        final doc = render(
          '''<$tag tl:replace="~{trellis-ui/$name :: $name}" name="email" type="email" required hx-post="/validate" hx-trigger="change" aria-describedby="email-hint"$extra></$tag>''',
        );
        final control = doc.querySelector(tag)!;
        expect(doc.querySelectorAll(tag), hasLength(1));
        expect(control.classes, contains('trellis-$name'));
        if (extra.isNotEmpty) expect(control.classes, contains('app-x'));
        for (final pair in {
          'name': 'email',
          'type': 'email',
          'required': '',
          'hx-post': '/validate',
          'hx-trigger': 'change',
          'aria-describedby': 'email-hint',
        }.entries) {
          expect(control.attributes[pair.key], pair.value, reason: '$name ${pair.key}');
          expect(doc.querySelectorAll('[${pair.key}]'), hasLength(1));
        }
        if (name == 'native-select') expect(doc.querySelector('svg')!.attributes['aria-hidden'], 'true');
      }
    }
  });

  test('text-only and select content use natural native slots', () {
    expect(
      render(
        '<textarea tl:replace="~{trellis-ui/textarea :: textarea}">Draft message</textarea>',
      ).querySelector('textarea')!.text,
      'Draft message',
    );
    final select = render(
      '<select tl:replace="~{trellis-ui/native-select :: native-select}"><optgroup label="Group"><option value="a">Alpha</option><option value="b">Beta</option></optgroup></select>',
    );
    expect(select.querySelectorAll('select option').map((e) => e.text), ['Alpha', 'Beta']);
    expect(select.querySelector('optgroup')!.attributes['label'], 'Group');
  });

  test('field wires label, hint and error and keeps ids unique when inserted twice', () {
    final normal = render(
      '''<div tl:replace="~{trellis-ui/field :: field('email', 'Email', 'Work address', null)}"></div>''',
    );
    expect(normal.querySelector('label')!.attributes['for'], 'email');
    final normalInput = normal.querySelector('input')!;
    expect(normalInput.attributes['id'], 'email');
    expect(normalInput.attributes['aria-describedby'], 'email-hint');
    expect(normal.querySelector('[role=alert]'), isNull);
    expect(normalInput.attributes.containsKey('aria-invalid'), isFalse);
    final error = render(
      '''<div tl:replace="~{trellis-ui/field :: field('email', 'Email', 'Work address', 'Invalid email')}"></div><div tl:replace="~{trellis-ui/field :: field('other', 'Other', 'Hint', 'Error')}"></div>''',
    );
    final errorInput = error.querySelector('input')!;
    expect(errorInput.attributes['aria-describedby'], 'email-hint email-error');
    expect(errorInput.attributes['aria-invalid'], 'true');
    expect(error.querySelector('[role=alert]')!.text, 'Invalid email');
    final ids = error.querySelectorAll('[id]').map((e) => e.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect(TemplateValidator().validate(File('assets/fragments/field.html').readAsStringSync()), isEmpty);
  });

  test('choice controls render native inputs, defaults and pass attributes through', () {
    for (final name in ['checkbox', 'radio', 'switch']) {
      for (final extra in ['', ' class="app-x"']) {
        final doc = render(
          '''<input tl:replace="~{trellis-ui/$name :: $name}" name="option" value="yes" checked disabled aria-describedby="hint" hx-post="/save"$extra>''',
        );
        final input = doc.querySelector('input')!;
        expect(doc.querySelectorAll('input'), hasLength(1));
        expect(input.attributes['type'], name == 'radio' ? 'radio' : 'checkbox');
        for (final pair in {
          'name': 'option',
          'value': 'yes',
          'checked': '',
          'disabled': '',
          'aria-describedby': 'hint',
          'hx-post': '/save',
        }.entries) {
          expect(input.attributes[pair.key], pair.value, reason: '$name ${pair.key}');
          expect(doc.querySelectorAll('[${pair.key}]'), hasLength(1));
        }
        if (extra.isNotEmpty) expect(input.classes, contains('app-x'));
        if (name == 'switch') expect(input.attributes['role'], 'switch');
        if (name == 'radio') expect(doc.querySelector('fieldset legend'), isNotNull);
      }
    }
  });

  test('display fragments render their semantic elements and fall back to the default variant', () {
    for (final name in ['badge', 'alert']) {
      final doc = render('<div tl:replace="~{trellis-ui/$name :: $name(\'unknown\')}">Body</div>');
      final root = doc.querySelector('[data-slot=$name]')!;
      expect(root.localName, name == 'badge' ? 'span' : 'div');
      expect(root.classes, contains('trellis-$name-variant-default'));
      expect(root.classes.any((c) => c.contains('unknown')), isFalse);
      expect(root.attributes.containsKey('role'), isFalse);
      for (final variant
          in name == 'badge'
              ? ['default', 'secondary', 'destructive', 'outline', 'ghost', 'link']
              : ['default', 'destructive']) {
        expect(
          render(
            '<div tl:replace="~{trellis-ui/$name :: $name(\'$variant\')}"></div>',
          ).querySelector('[data-slot=$name]')!.classes,
          contains('trellis-$name-variant-$variant'),
        );
      }
    }
    expect(
      render('<div tl:replace="~{trellis-ui/card :: card}"></div>').querySelector('h2[data-slot=card-title]'),
      isNotNull,
    );
    expect(render('<hr tl:replace="~{trellis-ui/separator :: separator}">').querySelector('hr'), isNotNull);
    expect(
      render(
        '''<div tl:replace="~{trellis-ui/separator :: separator('vertical')}"></div>''',
      ).querySelector('[role=separator]')!.attributes['aria-orientation'],
      'vertical',
    );
  });

  test('a natural table header slot can render a sortable column control', () {
    final table = render(
      '''
<table tl:replace="~{trellis-ui/table :: table('Users', columns, rows)}">
  <thead tl:slot="header">
    <tr class="trellis-table-row">
      <th scope="col" class="trellis-table-head" aria-sort="ascending">
        <button tl:replace="~{trellis-ui/button :: button('ghost', 'sm')}" hx-get="/users?dir=desc">Name</button>
      </th>
    </tr>
  </thead>
  <tbody tl:slot="row"><tr><td>Row content</td></tr></tbody>
</table>
''',
      {
        'columns': ['Fallback'],
        'rows': ['Row'],
      },
    );
    expect(table.querySelectorAll('thead'), hasLength(1));
    final header = table.querySelector('thead.trellis-table-header th[scope=col][aria-sort=ascending]')!;
    expect(header.querySelector('button[hx-get="/users?dir=desc"]')!.text.trim(), 'Name');
    expect(table.querySelector('tbody td')!.text, 'Row content');
    expect(table.text, isNot(contains('Fallback')));
  });

  test('table, pagination and breadcrumb render their structure from app data', () {
    final table = render(
      r'''<table tl:replace="~{trellis-ui/table :: table('Users', columns, rows)}"><tbody tl:slot="row"><tr><td class="trellis-table-cell" tl:text="${row.name}">Name</td></tr></tbody></table>''',
      {
        'columns': ['Name'],
        'rows': [
          {'name': 'Ada'},
          {'name': 'Grace'},
          {'name': 'Katherine'},
        ],
      },
    );
    final region = table.querySelector('[role=region]')!;
    expect(region.attributes['aria-label'], 'Users');
    expect(region.attributes['tabindex'], '0');
    expect(table.querySelector('caption')!.text, 'Users');
    expect(table.querySelector('th')!.attributes['scope'], 'col');
    expect(table.querySelectorAll('tbody tr').map((e) => e.text.trim()), ['Ada', 'Grace', 'Katherine']);
    final pagination = render(
      '''<nav tl:replace="~{trellis-ui/pagination :: pagination(pages, null, '/next')}"></nav>''',
      {
        'pages': [
          for (var i = 1; i <= 3; i++) {'label': '$i', 'href': '/$i', 'current': i == 3, 'ellipsis': false},
          {'label': '', 'href': '', 'current': false, 'ellipsis': true},
        ],
      },
    );
    final currentLinks = pagination.querySelectorAll('[aria-current=page]');
    expect(currentLinks, hasLength(1));
    expect(currentLinks.single.text, '3');
    expect(pagination.querySelector('span[aria-disabled=true]')!.text, 'Previous');
    expect(pagination.querySelector('[data-slot=pagination-ellipsis]')!.attributes['aria-hidden'], 'true');
    final crumb = render('<nav tl:replace="~{trellis-ui/breadcrumb :: breadcrumb(items)}"></nav>', {
      'items': [
        {'label': 'Home', 'href': '/', 'current': false},
        {'label': 'Here', 'href': '', 'current': true},
      ],
    });
    expect(crumb.querySelector('nav')!.attributes['aria-label'], 'Breadcrumb');
    expect(crumb.querySelectorAll('ol li'), hasLength(2));
    expect(crumb.querySelector('[aria-current=page]')!.localName, 'span');
    expect(crumb.querySelector('[data-slot=breadcrumb-separator]')!.attributes['aria-hidden'], 'true');
  });

  test('every CSS-only fragment renders bare under strict mode', () {
    for (final name in [
      'input',
      'textarea',
      'field',
      'native-select',
      'checkbox',
      'radio',
      'switch',
      'badge',
      'card',
      'alert',
      'table',
      'pagination',
      'breadcrumb',
      'separator',
    ]) {
      final doc = render('<div tl:replace="~{trellis-ui/$name :: $name}"></div>');
      expect(doc.querySelector('[data-slot]'), isNotNull, reason: name);
    }
  });
}
