import 'dart:io';

import 'package:test/test.dart';

import 'browser_reflow_probe.dart';
import '../tool/ui_gate/checks.dart';
import '../tool/ui_gate/firefox.dart';
import '../tool/ui_gate/manifest.dart';
import '../tool/ui_gate/appearance.dart';

void main() {
  for (final (mode, description) in [
    ('once', 'replays a popup state invalidated by visible window blur'),
    ('dismiss', 'retains a true popup dismissal in the focused document'),
    ('always', 'fails after three external interruptions'),
  ]) {
    test('Firefox hover capture $description', () async {
      if (FirefoxDriver.locateFirefox() == null || FirefoxDriver.locateGeckodriver() == null) {
        markTestSkipped('Firefox or geckodriver not installed');
        return;
      }
      final root = Directory.systemTemp.createTempSync('gate_hover_context_');
      addTearDown(() => root.deleteSync(recursive: true));
      File('${root.path}/index.html').writeAsStringSync('''
<!doctype html>
<style>#trigger:hover { color: red; }</style>
<main id="component">
  <input id="field" aria-label="Name">
  <button id="trigger">Suggestions</button>
  <div id="popup" popover="manual">Options</div>
</main>
<script>
const field=document.getElementById('field'), popup=document.getElementById('popup');
const mode=new URLSearchParams(location.search).get('mode');
field.addEventListener('focusout',()=>popup.hidePopover());
document.getElementById('trigger').addEventListener('pointerover',()=>{
  if (mode==='dismiss') {
    if (document.hasFocus()) fetch('/dismiss-observed');
    popup.hidePopover();
    return;
  }
  if (!['once','always'].includes(mode) || (mode==='once' && sessionStorage.getItem('hoverContended'))) return;
  sessionStorage.setItem('hoverContended','true');
  window.addEventListener('blur',()=>{
    if (!document.hidden) fetch('/blur-observed');
  }, {once:true});
  requestAnimationFrame(()=>window.open('/contender.html','_blank','popup,width=260,height=180'));
});
</script>
''');
      for (final marker in ['blur-observed', 'dismiss-observed', 'contender.html']) {
        File('${root.path}/$marker').writeAsStringSync('<!doctype html><title>$marker</title>');
      }
      final server = await StaticSiteServer.serve(root);
      addTearDown(server.close);
      final driver = await FirefoxDriver.launch();
      addTearDown(driver.close);

      Future<Map<String, Object?>> capture(String mode) {
        final manifest = GateManifest.load(
          File('${root.path}/$mode.yaml')..writeAsStringSync('''
page: /?mode=$mode
root: '#component'
elements: {trigger: '#trigger'}
states:
  open:
    - hover: '#field'
    - focus: '#field'
    - eval: document.getElementById('popup').showPopover()
'''),
        );
        return captureAppearance(GateSession(manifest, driver, server.baseUrl));
      }

      Iterable<String> observations(String marker) => driver.requests.where((url) => Uri.parse(url).path == '/$marker');
      if (mode == 'always') {
        await expectLater(
          capture(mode),
          throwsA(isA<StateError>().having((error) => error.message, 'message', contains('three hover captures'))),
        );
        expect(observations('blur-observed'), hasLength(3));
        expect(await driver.evaluate("Object.hasOwn(window, '__uiGateHoverFocus')"), isFalse);
        expect(await driver.listeners(), 0, reason: 'An exhausted replay must clean up its window blur listener');
        return;
      }
      final measured = await capture(mode);
      final state = (measured['states'] as Map)['open/hover:trigger'] as Map;
      if (mode == 'dismiss') {
        expect(observations('dismiss-observed'), isNotEmpty);
        expect(observations('blur-observed'), isEmpty);
        final clean = await capture('control');
        expect(
          compareAppearance(clean, measured),
          contains(allOf(contains('open/hover:trigger'), contains('box no longer rendered'))),
        );
      } else {
        expect(observations('blur-observed'), isNotEmpty);
        expect((state['nodes'] as List).whereType<Map>().map((node) => node['i']), contains('popup'));
        expect((((state['elements'] as Map)['trigger'] as Map)['style'] as Map)['color'], 'rgb(255, 0, 0)');
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}
