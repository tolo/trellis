import 'package:html/parser.dart';
import 'package:test/test.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_ui/trellis_ui.dart';

void main() {
  final engine = Trellis(loader: TrellisUiLoader(), strict: true);
  const options = [
    {'value': 'acme', 'label': 'Acme & Sons'},
    {'value': 'apex', 'label': 'Apex'},
  ];
  test('combobox options render by bare name from the context', () async {
    final inline = parseFragment(
      engine.render(
        '''
<label tl:replace="~{trellis-ui/field :: label('company')}">Company</label>
<div tl:replace="~{trellis-ui/combobox :: combobox('company', 'companyId', 'Find a company', 'acme', \${options}, 'Acme & Sons')}"
 class="app-combobox" hx-get="/companies" name="q"></div>
''',
        {'options': options},
      ),
    );
    final response = parseFragment(
      await engine.renderFileFragment(
        'trellis-ui/combobox',
        fragment: 'comboboxOptions',
        context: {'id': 'company', 'options': options},
      ),
    );
    final input = inline.querySelector('#company[role=combobox]')!;
    expect(input.classes, containsAll(['trellis-input', 'app-combobox']));
    expect(input.attributes['name'], 'q');
    expect(input.attributes['hx-get'], '/companies');
    expect(input.attributes['value'], 'Acme & Sons');
    expect(input.attributes['aria-controls'], 'company-listbox');
    expect(inline.querySelector('label[for=company]')?.text, 'Company');
    expect(inline.querySelector('input[type=hidden][name=companyId]')?.attributes['value'], 'acme');
    expect(inline.querySelector('#company-results')!.outerHtml, response.querySelector('#company-results')!.outerHtml);
    expect(response.querySelector('#company-option-0')?.text, 'Acme & Sons');
    expect(response.querySelector('#company-option-0')?.attributes['data-value'], 'acme');
    expect(response.querySelector('#company-option-1')?.text, 'Apex');
  });

  test('fragments inserted twice keep unique ids and resolving references', () {
    String components(String id) =>
        '''
<div tl:replace="~{trellis-ui/dialog :: dialog('$id-edit', 'Edit', 'Project name')}"></div>
<div tl:replace="~{trellis-ui/alert-dialog :: alertDialog('$id-delete', 'Delete', 'Permanently removes the project')}"></div>
<div tl:replace="~{trellis-ui/dropdown-menu :: dropdownMenu('$id-menu')}">
  <button tl:replace="~{trellis-ui/dropdown-menu :: menuItem}">Edit</button>
</div>
<div tl:replace="~{trellis-ui/tabs :: tabs('$id-tabs', 'list')}">
  <div tl:replace="~{trellis-ui/tabs :: tabList}"><button tl:replace="~{trellis-ui/tabs :: tabTrigger('list')}">List</button></div>
  <div tl:replace="~{trellis-ui/tabs :: tabPanel('list')}">List of projects</div>
</div>
<label tl:replace="~{trellis-ui/field :: label('$id-search')}">Search</label>
<div tl:replace="~{trellis-ui/combobox :: combobox('$id-search', '$id-value', 'Search', null, \${options})}"></div>
<div tl:replace="~{trellis-ui/toast :: toastViewport('$id-notices')}"></div>
''';
    final document = parseFragment(engine.render(components('first') + components('second'), {'options': options}));
    final ids = document.querySelectorAll('[id]').map((element) => element.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    for (final attribute in ['aria-labelledby', 'aria-describedby', 'aria-controls', 'for', 'popovertarget']) {
      final elements = document.querySelectorAll('[$attribute]');
      expect(elements, hasLength(greaterThanOrEqualTo(2)), reason: attribute);
      for (final element in elements) {
        for (final id in element.attributes[attribute]!.split(RegExp(r'\s+'))) {
          expect(ids, contains(id), reason: '${element.localName} $attribute="$id"');
        }
      }
    }
  });
}
