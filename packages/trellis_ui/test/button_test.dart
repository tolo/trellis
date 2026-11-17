import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' show parseFragment;
import 'package:test/test.dart';
import 'package:trellis/trellis.dart';
import 'package:trellis_ui/trellis_ui.dart';

void main() {
  final engine = Trellis(loader: CompositeLoader([MapLoader({}), TrellisUiLoader()]));
  test('the button renders variants, sizes, slot content and pass-through attributes', () {
    final output = engine.render(
      '''<button tl:replace="~{trellis-ui/button :: button('destructive', 'sm')}" type="submit" hx-post="/save" class="app-save" disabled>Save</button>''',
      {},
    );
    final doc = parseFragment(output);
    expect(doc.querySelectorAll('button'), hasLength(1));
    final button = doc.querySelector('button')!;
    expect(button.attributes['data-slot'], 'button');
    expect(
      button.classes,
      containsAll(['trellis-button', 'trellis-button-variant-destructive', 'trellis-button-size-sm', 'group/button']),
    );
    expect(button.classes, contains('app-save'));
    expect(button.attributes['type'], 'submit');
    expect(button.attributes['hx-post'], '/save');
    expect(button.attributes['disabled'], '');
    expect(button.text.trim(), 'Save');
    expect(output, isNot(contains('tl:')));
    final defaults = parseFragment(
      engine.render('<button tl:replace="~{trellis-ui/button :: button}">Default</button>', {}),
    ).querySelector('button')!;
    expect(defaults.classes, containsAll(['trellis-button-variant-default', 'trellis-button-size-default']));
  });

  test('every offered variant and size has a generated rule', () {
    final report = jsonDecode(File('generated/report.json').readAsStringSync()) as Map<String, dynamic>;
    final hooks = (report['hooks'] as List).cast<String>();
    final modifiers = hooks
        .where((s) => s.startsWith('trellis-button-variant-') || s.startsWith('trellis-button-size-'))
        .toList();
    expect(modifiers, isNotEmpty);
    final css = File('generated/trellis.css').readAsStringSync();
    for (final hook in modifiers) {
      final isVariant = hook.startsWith('trellis-button-variant-');
      final value = hook.replaceFirst(isVariant ? 'trellis-button-variant-' : 'trellis-button-size-', '');
      final args = isVariant ? "'$value', 'default'" : "'default', '$value'";
      final rendered = parseFragment(
        engine.render('<button tl:replace="~{trellis-ui/button :: button($args)}">Test</button>', {}),
      );
      expect(rendered.querySelector('button')!.classes, contains(hook));
      expect(RegExp('\\.${RegExp.escape(hook)}(?=[ :,{])').hasMatch(css), isTrue, reason: hook);
    }
  });
  test('a strict application engine renders defaults without a host class', () {
    final strict = Trellis(loader: TrellisUiLoader(), strict: true);
    for (final hostClass in ['', ' class="app-action"']) {
      final output = strict.render('<button tl:replace="~{trellis-ui/button :: button}"$hostClass>Save</button>', {});
      final button = parseFragment(output).querySelector('button')!;
      expect(
        button.classes,
        containsAll(['trellis-button', 'trellis-button-variant-default', 'trellis-button-size-default']),
      );
      if (hostClass.isNotEmpty) expect(button.classes, contains('app-action'));
    }
  });
}
