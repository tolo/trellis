import 'dart:io';

import 'package:test/test.dart';

import '../tool/ui_gate/appearance.dart';
import '../tool/ui_gate/checks.dart';
import '../tool/ui_gate/firefox.dart';
import '../tool/ui_gate/manifest.dart';
import 'browser_reflow_probe.dart';

void main() {
  for (final target in ['field', 'button', 'link']) {
    test('Firefox active capture keeps native $target pointer paint through backgrounding', () async {
      if (FirefoxDriver.locateFirefox() == null || FirefoxDriver.locateGeckodriver() == null) {
        markTestSkipped('Firefox or geckodriver not installed');
        return;
      }
      final root = Directory.systemTemp.createTempSync('gate_active_focus_');
      addTearDown(() => root.deleteSync(recursive: true));
      File('${root.path}/index.html').writeAsStringSync('''
<!doctype html>
<style>
.target { border: 1px solid blue; outline: 3px solid blue; }
.target:active { background-color: yellow; }
.target:focus { color: green; }
.target:focus-visible { border-color: red; outline: 1px solid red; box-shadow: 0 0 0 3px red; }
</style>
<main id="component">
  <input id="field" class="target" aria-label="Name">
  <button id="button" class="target">Run</button>
  <a id="link" class="target" href="?next">Next</a>
</main>
<script>
const component = document.querySelector('#component');
document.addEventListener('visibilitychange', () => {
  if (document.hidden && component.querySelector(':active')) component.classList.add('hidden-active');
});
component.addEventListener('pointerdown', () => {
  window.addEventListener('blur', () => {
    if (!document.hasFocus()) component.classList.add('backgrounded');
  }, {once: true});
  // A tab would hide this document and suspend RAF, unlike visible window focus loss.
  requestAnimationFrame(() => window.open('/contender.html', 'active-contender', 'popup,width=260,height=180'));
}, {once: true});
</script>
''');
      File('${root.path}/contender.html').writeAsStringSync('<!doctype html><title>Focus contender</title>');
      final manifest = GateManifest.load(
        File('${root.path}/active.yaml')..writeAsStringSync("""
page: /
root: '#component'
elements: {primary: '#$target'}
states: {default: []}
"""),
      );
      final server = await StaticSiteServer.serve(root);
      addTearDown(server.close);
      final driver = await FirefoxDriver.launch();
      addTearDown(driver.close);
      final capture = await captureAppearance(GateSession(manifest, driver, server.baseUrl));
      final states = capture['states'] as Map;
      final state = states['default/active:primary'] as Map;
      final component = (state['nodes'] as List).whereType<Map>().singleWhere((node) => node['i'] == 'component');
      expect(component['c'], contains('backgrounded'), reason: '$target was measured after the contender took focus');
      expect(component['c'], isNot(contains('hidden-active')), reason: 'The source must remain visible while pressed');
      final style = ((state['elements'] as Map)['primary'] as Map)['style'] as Map;
      expect(style['backgroundColor'], 'rgb(255, 255, 0)', reason: 'The native pointer must remain held');
      expect(style['color'], 'rgb(0, 128, 0)', reason: 'Native focus paint must return without focusing the target');
      expect(
        [style['borderColor'], style['outlineWidth'], style['boxShadow']],
        target == 'field'
            ? ['rgb(255, 0, 0)', '1px', 'rgb(255, 0, 0) 0px 0px 0px 3px']
            : ['rgb(0, 0, 255)', '3px', 'none'],
        reason: 'Only the text input receives a focus-visible ring under pointer activation',
      );
    }, timeout: Timeout(Duration(minutes: 2)));
  }
}
