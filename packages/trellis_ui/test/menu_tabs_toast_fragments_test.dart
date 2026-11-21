import 'dart:io';

import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:test/test.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_ui/trellis_ui.dart';

void main() {
  final engine = Trellis(loader: TrellisUiLoader(), strict: true);

  DocumentFragment render(String template) {
    final output = engine.render(template, const {});
    expect(output, isNot(contains('tl:')));
    return parseFragment(output);
  }

  test('dropdown menu renders its contract markup and passes attributes to items', () {
    final document = render('''
      <div tl:replace="~{trellis-ui/dropdown-menu :: dropdownMenu('account')}" class="app-popup">
        <span tl:slot="trigger">Account actions</span>
        <button tl:replace="~{trellis-ui/dropdown-menu :: menuItem}" class="app-action"
          hx-get="/profile" hx-target="#profile">Profile</button>
        <button tl:replace="~{trellis-ui/dropdown-menu :: menuItem('destructive')}" disabled>Delete</button>
        <div tl:replace="~{trellis-ui/dropdown-menu :: menuSeparator}"></div>
        <button tl:replace="~{trellis-ui/dropdown-menu :: menuCheckboxItem(true)}">Show status</button>
      </div>''');
    final menu = document.querySelector('#account')!;
    final trigger = document.querySelector('#account-trigger')!;
    expect(trigger.localName, 'button');
    expect(trigger.text.trim(), 'Account actions');
    expect(trigger.attributes['aria-haspopup'], 'menu');
    expect(trigger.attributes['aria-expanded'], 'false');
    expect(trigger.attributes['aria-controls'], menu.id);
    expect(trigger.attributes['popovertarget'], menu.id);
    expect(menu.attributes['aria-labelledby'], trigger.id);
    expect(menu.attributes['role'], 'menu');
    expect(menu.attributes['popover'], 'auto');
    expect(menu.attributes.containsKey('data-closed'), isTrue);
    expect(menu.classes, containsAll(['trellis-dropdown-menu-content', 'app-popup']));
    final items = menu.querySelectorAll('[role=menuitem]');
    expect(items, hasLength(2));
    expect(items.first.classes, containsAll(['trellis-dropdown-menu-item', 'app-action']));
    expect(items.first.attributes['tabindex'], '-1');
    expect(items.first.attributes['hx-get'], '/profile');
    expect(items.first.attributes['hx-target'], '#profile');
    expect(items.last.attributes['data-variant'], 'destructive');
    expect(items.last.attributes.containsKey('disabled'), isTrue);
    expect(menu.querySelector('[role=separator]'), isNotNull);
    final checkbox = menu.querySelector('[role=menuitemcheckbox]')!;
    expect(checkbox.attributes['aria-checked'], 'true');
    expect(checkbox.attributes.containsKey('data-checked'), isTrue);

    final nativeDisabled = render('''
      <button tl:replace="~{trellis-ui/dropdown-menu :: menuItem}" disabled>Unavailable</button>''');
    expect(nativeDisabled.querySelector('button[role=menuitem][disabled]'), isNotNull);
  });

  test('a submenu labels and controls its own nested menu', () {
    final document = render("""
      <div tl:replace="~{trellis-ui/dropdown-menu :: dropdownMenu('account')}">
        <div tl:replace="~{trellis-ui/dropdown-menu :: menuSubmenu('services')}" class="app-services">
          <span tl:slot="trigger">Services</span>
          <button tl:replace="~{trellis-ui/dropdown-menu :: menuItem}" disabled>Unavailable</button>
          <button tl:replace="~{trellis-ui/dropdown-menu :: menuItem}">Invoices</button>
        </div>
      </div>""");
    final menu = document.querySelector('#services[role=menu][popover=auto]')!;
    final trigger = document.querySelector('#services-trigger[role=menuitem]')!;
    expect(trigger.text.trim(), 'Services');
    expect(trigger.attributes, containsPair('aria-haspopup', 'menu'));
    expect(trigger.attributes, containsPair('aria-expanded', 'false'));
    expect(trigger.attributes, containsPair('aria-controls', menu.id));
    expect(trigger.attributes, containsPair('popovertarget', menu.id));
    expect(menu.attributes, containsPair('aria-labelledby', trigger.id));
    expect(menu.classes, contains('app-services'));
    expect(menu.querySelectorAll('[role=menuitem]').map((element) => element.text), ['Unavailable', 'Invoices']);
    expect(menu.querySelector('button[disabled]')!.text, 'Unavailable');
  });

  test('tabs render roving tabindex, linked ids and hidden inactive panels', () {
    final document = render('''
      <div tl:replace="~{trellis-ui/tabs :: tabs('sample', 'one', true)}" class="app-tabs">
        <div tl:replace="~{trellis-ui/tabs :: tabList}" aria-label="Settings">
          <button tl:replace="~{trellis-ui/tabs :: tabTrigger('one')}">One</button>
          <button tl:replace="~{trellis-ui/tabs :: tabTrigger('two')}" disabled>Two</button>
        </div>
        <div tl:replace="~{trellis-ui/tabs :: tabPanel('one')}">First panel</div>
        <div tl:replace="~{trellis-ui/tabs :: tabPanel('two')}">Second panel</div>
      </div>''');
    final tabs = document.querySelector('#sample')!;
    expect(tabs.classes, containsAll(['trellis-tabs', 'app-tabs']));
    final list = tabs.querySelector('[role=tablist]')!;
    expect(list.attributes['aria-orientation'], 'vertical');
    expect(list.attributes['aria-label'], 'Settings');
    expect(list.querySelectorAll('[tabindex="0"]').map((tab) => tab.id), ['sample-tab-one']);
    for (final value in ['one', 'two']) {
      final active = value == 'one';
      final tab = list.querySelector('#sample-tab-$value')!;
      final panel = tabs.querySelector('#sample-panel-$value')!;
      expect(tab.attributes['role'], 'tab');
      expect(tab.attributes['aria-selected'], active.toString());
      expect(tab.attributes.containsKey('data-active'), active);
      expect(tab.attributes.containsKey('disabled'), !active);
      expect(tab.attributes['aria-controls'], panel.id);
      expect(panel.attributes['role'], 'tabpanel');
      expect(panel.attributes['aria-labelledby'], tab.id);
      expect(panel.attributes.containsKey('hidden'), !active);
    }
    expect(tabs.querySelector('#sample-panel-one')!.text.trim(), 'First panel');
  });

  test('toast renders in-page and out-of-band from one definition', () {
    final files = Directory('assets/fragments').listSync().whereType<File>().where((f) => f.path.endsWith('.html'));
    final declaration = RegExp(r'tl:fragment="toast(?:\(|")');
    expect(files.expand((file) => declaration.allMatches(file.readAsStringSync())), hasLength(1));
    final template = File('assets/fragments/toast.html').readAsStringSync();
    for (final type in ['error', 'success', 'warning', 'info']) {
      final inline = render('''
        <div tl:replace="~{trellis-ui/toast :: toast('$type', 'Result', 'More detail', 0, false)}"></div>''');
      final outOfBand = parseFragment(
        engine.renderFragment(
          template,
          fragment: 'toast',
          context: {'type': type, 'title': 'Result', 'description': 'More detail', 'duration': 0, 'outOfBand': true},
        ),
      );
      final toast = inline.children.single;
      expect(toast.localName, 'tl-toast');
      expect(toast.attributes['data-duration'], '0');
      expect(inline.querySelector('[hx-swap-oob]'), isNull);
      final wrapper = outOfBand.children.single;
      expect(wrapper.id, 'toaster');
      expect(wrapper.attributes['hx-swap-oob'], 'beforeend');
      expect(wrapper.children.single.outerHtml, toast.outerHtml);
      final panel = toast.querySelector('[data-slot=toast]')!;
      expect(panel.attributes['data-type'], type);
      expect(panel.attributes['role'], type == 'error' ? 'alert' : null);
      expect(panel.querySelector('[data-slot=toast-title]')!.text, 'Result');
      expect(panel.querySelector('[data-slot=toast-description]')!.text, 'More detail');
      expect(panel.querySelector('svg')!.children, isNotEmpty);
    }
    final defaults = render('''
      <div tl:replace="~{trellis-ui/toast :: toast(null, 'Result')}" class="app-toast" aria-label="Result"></div>''');
    expect(defaults.children.single.attributes['data-duration'], '5000');
    expect(defaults.querySelector('[data-slot=toast]')!.classes, containsAll(['trellis-toast', 'app-toast']));
    expect(defaults.querySelector('[data-slot=toast]')!.attributes['aria-label'], 'Result');
    expect(defaults.querySelector('[data-slot=toast-description]'), isNull);
  });
}
