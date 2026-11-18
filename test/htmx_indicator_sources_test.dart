import 'dart:io';

import 'package:test/test.dart';

import '../packages/trellis_cli/lib/src/templates/htmx_asset.dart';

void main() {
  test("the scaffolds' indicator rules equal the suite's htmx-indicator.css", () {
    final suite = File('packages/trellis_ui/assets/css/htmx-indicator.css').readAsStringSync();
    expect(_opacityBySelector(htmxIndicatorCss), {
      '.htmx-indicator': '0',
      '.htmx-request .htmx-indicator, .htmx-request.htmx-indicator': '1',
    });
    expect(_opacityBySelector(suite), _opacityBySelector(htmxIndicatorCss));
  });
}

// The suite also layers and animates the transition. The two sources agree on
// the selectors and visibility states required by the HTMX contract.
Map<String, String> _opacityBySelector(String css) => {
  for (final rule in RegExp(r'([^{}\n]+)\s*\{[^{}]*\bopacity:\s*([^;]+);[^{}]*\}').allMatches(css))
    rule.group(1)!.trim(): rule.group(2)!.trim(),
};
