// ignore_for_file: deprecated_member_use_from_same_package

import 'package:mocktail/mocktail.dart';
import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:trellis_relic/trellis_relic.dart';

class MockRequest extends Mock implements Request {}

Request makeRequest({Map<String, Iterable<String>>? headers}) {
  final req = MockRequest();
  final h = Headers.fromMap(headers ?? {});
  when(() => req.headers).thenReturn(h);
  return req;
}

void main() {
  group('isHtmxRequest', () {
    test('returns true when HX-Request is "true"', () {
      final req = makeRequest(
        headers: {
          'HX-Request': ['true'],
        },
      );
      expect(isHtmxRequest(req), isTrue);
    });

    test('returns false when HX-Request header is absent', () {
      final req = makeRequest();
      expect(isHtmxRequest(req), isFalse);
    });

    test('returns false when HX-Request has a different value', () {
      final req = makeRequest(
        headers: {
          'HX-Request': ['1'],
        },
      );
      expect(isHtmxRequest(req), isFalse);
    });
  });

  group('htmxTarget', () {
    test('returns target value when present', () {
      final req = makeRequest(
        headers: {
          'HX-Target': ['main-content'],
        },
      );
      expect(htmxTarget(req), equals('main-content'));
    });

    test('returns null when HX-Target is absent', () {
      final req = makeRequest();
      expect(htmxTarget(req), isNull);
    });

    test('extracts the id from the HTMX 4 tag#id value', () {
      final req = makeRequest(
        headers: {
          'HX-Source': ['button#save'],
          'HX-Target': ['main#content'],
        },
      );
      expect(htmxTarget(req), equals('content'));
    });

    test('returns null when the HTMX 4 target has no id', () {
      final req = makeRequest(
        headers: {
          'HX-Source': ['button#save'],
          'HX-Target': ['form'],
        },
      );
      expect(htmxTarget(req), isNull);
    });

    test('decodes the encodeURI-encoded HTMX 4 id', () {
      final req = makeRequest(
        headers: {
          'HX-Source': ['button'],
          'HX-Target': ['div#r%C3%A4knare'],
        },
      );
      expect(htmxTarget(req), equals('räknare'));
    });

    test('returns the raw id when the HTMX 4 value is not valid percent-encoding', () {
      for (final raw in ['%zz', '%C3']) {
        final req = makeRequest(
          headers: {
            'HX-Source': ['button'],
            'HX-Target': ['div#$raw'],
          },
        );
        expect(htmxTarget(req), equals(raw));
      }
    });
  });

  group('htmxSource', () {
    test('returns the HX-Trigger request header under HTMX 2', () {
      final req = makeRequest(
        headers: {
          'HX-Trigger': ['submit-btn'],
        },
      );
      expect(htmxSource(req), equals('submit-btn'));
    });

    test('extracts the id from HX-Source under HTMX 4', () {
      final req = makeRequest(
        headers: {
          'HX-Source': ['button#submit-btn'],
        },
      );
      expect(htmxSource(req), equals('submit-btn'));
    });

    test('returns null when the HTMX 4 source has no id', () {
      final req = makeRequest(
        headers: {
          'HX-Source': ['button'],
        },
      );
      expect(htmxSource(req), isNull);
    });

    test('returns null when neither header is present', () {
      final req = makeRequest();
      expect(htmxSource(req), isNull);
    });
  });

  group('htmxTrigger', () {
    test('is a deprecated alias of htmxSource on both HTMX versions', () {
      expect(
        htmxTrigger(
          makeRequest(
            headers: {
              'HX-Trigger': ['submit-btn'],
            },
          ),
        ),
        equals('submit-btn'),
      );
      expect(
        htmxTrigger(
          makeRequest(
            headers: {
              'HX-Source': ['a#nav-link'],
            },
          ),
        ),
        equals('nav-link'),
      );
      expect(htmxTrigger(makeRequest()), isNull);
    });
  });

  group('isHtmxBoosted', () {
    test('returns true when HX-Boosted is "true"', () {
      final req = makeRequest(
        headers: {
          'HX-Boosted': ['true'],
        },
      );
      expect(isHtmxBoosted(req), isTrue);
    });

    test('returns false when HX-Boosted is absent', () {
      final req = makeRequest();
      expect(isHtmxBoosted(req), isFalse);
    });

    test('returns false when HX-Boosted has a different value', () {
      final req = makeRequest(
        headers: {
          'HX-Boosted': ['false'],
        },
      );
      expect(isHtmxBoosted(req), isFalse);
    });
  });

  group('combined HTMX headers', () {
    test('all HTMX headers work together on a single request', () {
      final req = makeRequest(
        headers: {
          'HX-Request': ['true'],
          'HX-Target': ['content'],
          'HX-Trigger': ['btn'],
          'HX-Boosted': ['true'],
        },
      );
      expect(isHtmxRequest(req), isTrue);
      expect(htmxTarget(req), equals('content'));
      expect(htmxSource(req), equals('btn'));
      expect(isHtmxBoosted(req), isTrue);
    });

    test('all HTMX 4 headers work together on a single request', () {
      final req = makeRequest(
        headers: {
          'HX-Request': ['true'],
          'HX-Target': ['main#content'],
          'HX-Source': ['button#btn'],
          'HX-Boosted': ['true'],
        },
      );
      expect(isHtmxRequest(req), isTrue);
      expect(htmxTarget(req), equals('content'));
      expect(htmxSource(req), equals('btn'));
      expect(isHtmxBoosted(req), isTrue);
    });
  });
}
