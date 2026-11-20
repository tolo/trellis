import 'dart:io';

import 'package:test/test.dart';

import '../tool/ui_gate/appearance.dart';
import '../tool/ui_gate/checks.dart';
import '../tool/ui_gate/firefox.dart';
import '../tool/ui_gate/manifest.dart';
import 'browser_reflow_probe.dart';

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
if (sessionStorage.visibleHoverBlurs) {
  const marker = document.createElement('div');
  marker.id = 'replayed-popup';
  marker.textContent = 'Replay after visible blur';
  popup.append(marker);
}
field.addEventListener('focusout',()=>popup.hidePopover());
document.getElementById('trigger').addEventListener('pointerover',()=>{
  if (mode==='dismiss') {
    if (document.hasFocus()) fetch('/dismiss-observed');
    popup.hidePopover();
    return;
  }
  if (!['once','always'].includes(mode) || (mode==='once' && sessionStorage.getItem('hoverContended'))) return;
  sessionStorage.setItem('hoverContended','true');
  window.addEventListener('blur',event=>{
    // Navigation can cancel a network marker. Keep the count in this browsing context.
    if (event.isTrusted && !document.hidden) {
      sessionStorage.visibleHoverBlurs = String(Number(sessionStorage.visibleHoverBlurs || 0) + 1);
    }
  }, {once:true});
  requestAnimationFrame(()=>window.open('/contender.html','_blank','popup,width=260,height=180'));
});
</script>
''');
      for (final marker in ['dismiss-observed', 'contender.html']) {
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
          throwsA(
            isA<VisualCaptureUnavailable>().having((error) => error.reason, 'reason', contains('three hover captures')),
          ),
        );
        expect(await driver.evaluate('Number(sessionStorage.visibleHoverBlurs)'), 3);
        expect(await driver.evaluate("Object.hasOwn(window, '__uiGateHoverFocus')"), isFalse);
        expect(await driver.listeners(), 0, reason: 'An exhausted replay must clean up its window blur listener');
        return;
      }
      final measured = await capture(mode);
      final state = (measured['states'] as Map)['open/hover:trigger'] as Map;
      if (mode == 'dismiss') {
        expect(observations('dismiss-observed'), isNotEmpty);
        expect(observations('contender.html'), isEmpty);
        final clean = await capture('control');
        expect(
          compareAppearance(clean, measured),
          contains(allOf(contains('open/hover:trigger'), contains('box no longer rendered'))),
        );
      } else {
        final rendered = (state['nodes'] as List).whereType<Map>().map((node) => node['i']);
        expect(rendered, containsAll(['popup', 'replayed-popup']));
        expect((((state['elements'] as Map)['trigger'] as Map)['style'] as Map)['color'], 'rgb(255, 0, 0)');
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  }

  for (final (mode, description) in [
    ('once', 'replays visible recipe blur and retains diagnostics'),
    ('dismiss', 'keeps an in-page recipe failure'),
    ('synthetic', 'ignores a synthetic blur'),
    ('script-error', 'keeps an evaluated script error after visible blur'),
    ('always', 'fails after three visible interruptions'),
  ]) {
    test('Firefox appearance $description', () async {
      if (FirefoxDriver.locateFirefox() == null || FirefoxDriver.locateGeckodriver() == null) {
        markTestSkipped('Firefox or geckodriver not installed');
        return;
      }
      final tmp = Directory('.agent_temp').absolute..createSync(recursive: true);
      final root = tmp.createTempSync('appearance-recipe-focus-');
      addTearDown(() => root.deleteSync(recursive: true));
      File('${root.path}/contender.html').writeAsStringSync('<!doctype html><title>Owned focus contender</title>');
      File('${root.path}/visible-blur').writeAsStringSync('Observed actual visible blur');
      File('${root.path}/index.html').writeAsStringSync('''
<!doctype html><title>Native End fixture</title>
<style>#last[data-highlighted] { color: green; }</style>
<main><button id="first">First</button><button id="last">Destructive</button></main>
<script>
const last = document.getElementById('last'), mode = '$mode';
last.addEventListener('focusin', () => last.setAttribute('data-highlighted', ''));
last.addEventListener('focusout', () => last.removeAttribute('data-highlighted'));
document.querySelector('main').addEventListener('keydown', event => {
  if (event.key !== 'End') return;
  event.preventDefault();
  last.focus();
  window.afterEnd = Promise.resolve(true);
  if (mode === 'dismiss' || mode === 'synthetic') {
    if (mode === 'synthetic') {
      const evidence = () => ({focused: document.hasFocus(), lostVisibleFocus: window.__uiGate.lostVisibleFocus});
      // Record what the synthetic event did before an unrelated native blur can change the marker.
      const before = evidence();
      window.dispatchEvent(new FocusEvent('blur'));
      window.syntheticBlurEvidence = {before, after: evidence()};
    }
    last.blur();
    return;
  }
  const attempt = Number(sessionStorage.recipeAttempts || 0) + 1;
  if (mode !== 'always' && attempt > 1) return;
  sessionStorage.recipeAttempts = String(attempt);
  const csp = new Promise(resolve => {
    window.addEventListener('securitypolicyviolation', () => resolve(true), {once:true});
    const image = document.body.appendChild(new Image());
    image.src = 'data:image/gif;base64,R0lGODlhAQABAIAAAAUEBA==#'+attempt;
  });
  if (mode !== 'script-error') queueMicrotask(() => { throw Error('interrupted recipe diagnostic'); });
  const blur = new Promise((resolve, reject) => {
    window.addEventListener('blur', event => {
      if (!event.isTrusted || document.hidden) {
        reject(Error('expected a trusted blur while the source stays visible'));
        return;
      }
      // A replay can navigate away before Firefox sends an unawaited marker.
      fetch('/visible-blur?attempt='+attempt).then(resolve, reject);
    }, {once:true});
    // Let the native End key sequence finish before switching windows.
    window.addEventListener('keyup', () => requestAnimationFrame(() => {
      if (!window.open('/contender.html','_blank','popup,width=260,height=180')) {
        reject(Error('Firefox blocked the focus contender window'));
      }
    }), {once:true});
  });
  window.afterEnd = Promise.all([csp, blur]).then(() => {
    if (mode === 'script-error') throw Error('interrupted recipe script error');
  });
});
</script>
''');
      final server = await StaticSiteServer.serve(
        root,
        headers: {'content-security-policy': "script-src 'self' 'unsafe-inline'; img-src 'self'"},
      );
      addTearDown(server.close);
      final driver = await FirefoxDriver.launch();
      addTearDown(driver.close);
      final manifest = GateManifest.load(
        File('${root.path}/recipe.yaml')..writeAsStringSync('''
page: /
root: main
elements: {destructive: '#last'}
states:
  destructive:
    - focus: '#first'
    - press: End
    - eval: window.afterEnd
    - expect: {expression: "document.activeElement.id === 'last' && document.activeElement.hasAttribute('data-highlighted')", equals: true}
'''),
      );
      final session = GateSession(manifest, driver, server.baseUrl);
      final result = captureAppearance(session);
      Iterable<String> interruptions() => driver.requests.where((url) => Uri.parse(url).path == '/visible-blur');
      if (mode != 'once') {
        final errorText = mode == 'script-error'
            ? 'interrupted recipe script error'
            : 'state destructive step 4 expect:';
        await expectLater(
          result,
          throwsA(isA<StateError>().having((error) => error.message, 'message', contains(errorText))),
        );
        expect(
          interruptions(),
          hasLength(switch (mode) {
            'always' => 3,
            'script-error' => 1,
            _ => 0,
          }),
        );
        if (mode == 'always') {
          expect(interruptions().map((url) => Uri.parse(url).queryParameters['attempt']), ['1', '2', '3']);
        }
        if (mode == 'synthetic') {
          expect(driver.requests.where((url) => Uri.parse(url).path == '/contender.html'), isEmpty);
          const focused = {'focused': true, 'lostVisibleFocus': false};
          expect(await driver.evaluate('window.syntheticBlurEvidence'), {'before': focused, 'after': focused});
        }
        return;
      }
      final measured = await result;
      expect(interruptions(), isNotEmpty);
      expect(session.violations, contains(contains('img-src')));
      expect(driver.console, contains(contains('interrupted recipe diagnostic')));
      final states = measured['states'] as Map;
      final elements = (states['destructive'] as Map)['elements'] as Map;
      expect((elements['destructive'] as Map)['style'], containsPair('color', 'rgb(0, 128, 0)'));
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}
