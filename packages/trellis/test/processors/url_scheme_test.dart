/// URL-scheme blocking in dynamic URL attributes (ADR-015).
library;

import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

const _blocked = 'about:invalid#trellis-unsafe-url';

void main() {
  late Trellis engine;

  setUp(() => engine = Trellis(loader: MapLoader({}), cache: false));

  String render(String template, Map<String, dynamic> context) => engine.render(template, context);

  /// The value the rendered `<a>` carries in [attribute], read back through the parser so entity escaping does not
  /// leak into the assertion.
  String hrefOf(String template, Object? value, {String attribute = 'href'}) {
    final out = render(template, {'u': value});
    final match = RegExp('$attribute="([^"]*)"').firstMatch(out);
    expect(match, isNotNull, reason: out);
    return match!.group(1)!.replaceAll('&amp;', '&');
  }

  group('unsafe values are replaced', () {
    const unsafe = {
      'javascript': 'javascript:alert(1)',
      'mixed case': 'JaVaScRiPt:alert(1)',
      'vbscript': 'vbscript:msgbox(1)',
      'leading space': ' javascript:alert(1)',
      'leading control character': '\x01javascript:alert(1)',
      'leading NUL and trailing space': '\x00javascript:alert(1) ',
      'tab inside the scheme': 'java\tscript:alert(1)',
      'newline inside the scheme': 'java\nscript:alert(1)',
      'carriage return before the colon': 'javascript\r:alert(1)',
      'data: HTML': 'data:text/html,<script>alert(1)</script>',
      'data: SVG': 'data:image/svg+xml,<svg onload="alert(1)"/>',
      'data: no media type': 'data:,hello',
      'data: image prefix without a delimiter': 'data:image/pngx,abc',
      'data: application': 'data:application/javascript,alert(1)',
    };
    for (final MapEntry(key: name, value: url) in unsafe.entries) {
      test(name, () => expect(hrefOf(r'<a tl:href="${u}">x</a>', url), _blocked));
    }
  });

  group('safe values pass unchanged', () {
    const safe = [
      '/path?q=1',
      'relative/page.html',
      '#section',
      '?javascript:x',
      '/javascript:alert(1)',
      'java script:alert(1)',
      'https://example.com/a?b=c',
      'http://example.com',
      'mailto:a@example.com',
      'tel:+46123',
      'sms:+46123',
      'myapp://open',
      'data:image/png;base64,iVBORw0KGgo=',
      'data:IMAGE/PNG;base64,iVBORw0KGgo=',
      'data:image/jpeg;charset=utf-8;base64,abc',
      'data:image/gif,abc',
      'data:image/webp;base64,abc',
      'data:image/avif;base64,abc',
      '',
    ];
    for (final url in safe) {
      test('"$url"', () => expect(hrefOf(r'<a tl:href="${u}">x</a>', url), url));
    }

    test('a non-breaking space is not trimmed, so the scheme is not javascript to a browser either', () {
      // Browsers strip only U+0000–U+0020 around a URL; `String.trim()` would also strip U+00A0.
      final out = render(r'<a tl:href="${u}">x</a>', {'u': '\u00A0javascript:alert(1)'});
      expect(out, contains('href="&nbsp;javascript:alert(1)"'));
    });

    test('a non-string value is stringified and checked', () {
      expect(hrefOf(r'<a tl:href="${u}">x</a>', 42), '42');
    });
  });

  group('every directive path and checked attribute name', () {
    const js = 'javascript:alert(1)';

    test('tl:src', () => expect(hrefOf(r'<iframe tl:src="${u}"></iframe>', js, attribute: 'src'), _blocked));

    for (final name in ['href', 'src', 'action', 'formaction', 'data']) {
      test('tl:attr $name', () {
        expect(hrefOf('<object tl:attr="$name=\${u}"></object>', js, attribute: name), _blocked);
      });
    }

    test('tl:attr matches the attribute name ignoring ASCII case', () {
      final out = render(r'<a tl:attr="HREF=${u}">x</a>', {'u': js});
      expect(out, contains(_blocked));
      expect(out, isNot(contains('javascript')));
    });

    test('xlink:href on SVG', () {
      final out = render(r'<svg><a tl:attr="xlink:href=${u}"><text>x</text></a></svg>', {'u': js});
      expect(out, contains(_blocked));
      expect(out, isNot(contains('javascript')));
    });

    test('tl:attrs map values', () {
      final out = render(r'<a tl:attrs="${m}">x</a>', {
        'm': {'href': js, 'formaction': 'data:text/html,x'},
      });
      expect(out, contains('href="$_blocked"'));
      expect(out, contains('formaction="$_blocked"'));
    });

    test('a string literal expression is dynamic too', () {
      expect(hrefOf('<a tl:href="\'javascript:void(0)\'">x</a>', null), _blocked);
    });

    test('unchecked attribute names are written as before', () {
      final out = render(r'<video tl:attr="poster=${u},title=${u}"></video>', {'u': js});
      expect(out, contains('poster="$js"'));
      expect(out, contains('title="$js"'));
    });

    test('a literal attribute in the template is never checked', () {
      final out = render(r'<a href="javascript:void(0)" tl:text="${t}">x</a>', {'t': 'go'});
      expect(out, contains('href="javascript:void(0)"'));
    });

    test('null still removes the attribute', () {
      expect(render(r'<a href="/old" tl:href="${u}">x</a>', {'u': null}), contains('<a>x</a>'));
    });

    test('strict mode replaces rather than throws', () {
      final strict = Trellis(loader: MapLoader({}), cache: false, strict: true);
      expect(strict.render(r'<a tl:href="${u}">x</a>', {'u': js}), contains('href="$_blocked"'));
    });
  });

  group('TrustedUrl', () {
    test('is written as-is in a checked attribute', () {
      expect(hrefOf(r'<a tl:href="${u}">x</a>', const TrustedUrl('javascript:go()')), 'javascript:go()');
    });

    test('through tl:attr and tl:attrs', () {
      final out = render(r'<form tl:attr="action=${u}"><a tl:attrs="${m}">x</a></form>', {
        'u': const TrustedUrl('data:text/html,ok'),
        'm': {'href': const TrustedUrl('vbscript:ok')},
      });
      expect(out, contains('action="data:text/html,ok"'));
      expect(out, contains('href="vbscript:ok"'));
    });

    test('renders its URL as text and in an unchecked attribute', () {
      final out = render(r'<p tl:text="${u}" tl:attr="title=${u}">x</p>', {'u': const TrustedUrl('/a')});
      expect(out, contains('<p title="/a">/a</p>'));
    });

    test('loses trust when concatenated, so the result is checked', () {
      final out = render(r"""<a tl:href="${u + ''}">x</a>""", {'u': const TrustedUrl('javascript:go()')});
      expect(out, contains('href="$_blocked"'));
    });

    test('compares by value in Dart', () {
      expect(const TrustedUrl('/a'), const TrustedUrl('/a'));
      expect(const TrustedUrl('/a').hashCode, const TrustedUrl('/a').hashCode);
      expect(const TrustedUrl('/a'), isNot(const TrustedUrl('/b')));
      expect(const TrustedUrl('/a').toString(), '/a');
    });
  });

  group('...rest forwarding', () {
    const link = r'<a tl:fragment="link(label, ...attrs)" tl:attrs="${attrs}" tl:text="${label}">L</a>';

    test('a literal host attribute survives forwarding', () {
      final out = render('$link<span tl:replace="link(\'go\')" href="javascript:void(0)"></span>', {});
      expect(out, contains('<a href="javascript:void(0)">go</a>'));
    });

    test('a TrustedUrl on the host survives forwarding', () {
      final out = render('$link<span tl:replace="link(\'go\')" tl:attr="href=\${u}"></span>', {
        'u': const TrustedUrl('javascript:go()'),
      });
      expect(out, contains('<a href="javascript:go()">go</a>'));
    });

    test('an unsafe dynamic host value is replaced before it is forwarded', () {
      final out = render('$link<span tl:replace="link(\'go\')" tl:href="\${u}"></span>', {'u': 'javascript:alert(1)'});
      expect(out, contains('<a href="$_blocked">go</a>'));
    });

    test('a value read out of the rest map is an ordinary expression and is checked', () {
      const pick = r'<a tl:fragment="pick(...attrs)" tl:href="${attrs.href}">P</a>';
      final out = render('$pick<span tl:replace="pick()" href="javascript:void(0)"></span>', {});
      expect(out, contains('<a href="$_blocked">P</a>'));
    });
  });
}
