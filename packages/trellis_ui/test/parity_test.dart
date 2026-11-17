import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../tool/src/parity.dart';

void main() {
  test('a missing slot fails unless an ignore entry with a reason covers it', () {
    final fixture = Directory.systemTemp.createTempSync('suite_parity_');
    addTearDown(() => fixture.deleteSync(recursive: true));
    for (final path in ['tool', 'assets/fragments', 'vendor/shadcn/test/ui']) {
      Directory('${fixture.path}/$path').createSync(recursive: true);
    }
    File('${fixture.path}/tool/pins.json').writeAsStringSync(
      jsonEncode({
        'shadcn': {'tag': 'test'},
        'components': ['button'],
      }),
    );
    File(
      '${fixture.path}/vendor/shadcn/test/ui/button.tsx',
    ).writeAsStringSync('<button data-slot="button" className={cn("cn-button group/button")} />');
    File(
      '${fixture.path}/assets/fragments/button.html',
    ).writeAsStringSync('<button class="trellis-button group/button"></button>');
    final ignore = File('${fixture.path}/tool/parity-ignore.json')..writeAsStringSync('[]');
    var result = checkParity(fixture);
    expect(result.failures, 1);
    expect(result.lines, contains('DRIFT slot missing: button'));
    Map<String, String> entry(String reason) => {
      'kind': 'slot',
      'direction': 'missing',
      'name': 'button',
      'reason': reason,
    };
    ignore.writeAsStringSync(jsonEncode([entry('The fixture deliberately omits its upstream slot.')]));
    expect(checkParity(fixture).failures, 0);
    ignore.writeAsStringSync(jsonEncode([entry(' ')]));
    result = checkParity(fixture);
    expect(result.failures, greaterThan(0));
    expect(result.lines.join('\n'), contains('button: blank reason'));
    ignore.writeAsStringSync(
      jsonEncode([
        {'kind': 'slot', 'direction': 'missing', 'name': 'not-used', 'reason': 'Stale fixture.'},
      ]),
    );
    expect(checkParity(fixture).lines.join('\n'), contains('STALE ignore not-used'));
  });
}
