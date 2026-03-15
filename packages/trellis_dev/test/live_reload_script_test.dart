import 'package:test/test.dart';
import 'package:trellis_dev/trellis_dev.dart';

void main() {
  group('liveReloadScript', () {
    test('uses default SSE path', () {
      final script = liveReloadScript();
      expect(script, contains("EventSource('/_dev/reload')"));
    });

    test('uses custom SSE path', () {
      final script = liveReloadScript(ssePath: '/custom/sse');
      expect(script, contains("EventSource('/custom/sse')"));
    });

    test('contains script tags', () {
      final script = liveReloadScript();
      expect(script, startsWith('<script>'));
      expect(script, endsWith('</script>'));
    });

    test('contains addEventListener for reload event', () {
      final script = liveReloadScript();
      expect(script, contains("addEventListener('reload'"));
    });

    test('contains location.reload()', () {
      final script = liveReloadScript();
      expect(script, contains('location.reload()'));
    });

    test('contains onerror handler', () {
      final script = liveReloadScript();
      expect(script, contains('onerror'));
    });

    test('uses IIFE pattern', () {
      final script = liveReloadScript();
      expect(script, contains('(function()'));
      expect(script, contains('})()'));
    });
  });
}
