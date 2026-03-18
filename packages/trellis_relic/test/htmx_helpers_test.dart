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
      final req = makeRequest(headers: {'HX-Request': ['true']});
      expect(isHtmxRequest(req), isTrue);
    });

    test('returns false when HX-Request header is absent', () {
      final req = makeRequest();
      expect(isHtmxRequest(req), isFalse);
    });

    test('returns false when HX-Request has a different value', () {
      final req = makeRequest(headers: {'HX-Request': ['1']});
      expect(isHtmxRequest(req), isFalse);
    });
  });

  group('htmxTarget', () {
    test('returns target value when present', () {
      final req = makeRequest(headers: {'HX-Target': ['main-content']});
      expect(htmxTarget(req), equals('main-content'));
    });

    test('returns null when HX-Target is absent', () {
      final req = makeRequest();
      expect(htmxTarget(req), isNull);
    });
  });

  group('htmxTrigger', () {
    test('returns trigger value when present', () {
      final req = makeRequest(headers: {'HX-Trigger': ['submit-btn']});
      expect(htmxTrigger(req), equals('submit-btn'));
    });

    test('returns null when HX-Trigger is absent', () {
      final req = makeRequest();
      expect(htmxTrigger(req), isNull);
    });
  });

  group('isHtmxBoosted', () {
    test('returns true when HX-Boosted is "true"', () {
      final req = makeRequest(headers: {'HX-Boosted': ['true']});
      expect(isHtmxBoosted(req), isTrue);
    });

    test('returns false when HX-Boosted is absent', () {
      final req = makeRequest();
      expect(isHtmxBoosted(req), isFalse);
    });

    test('returns false when HX-Boosted has a different value', () {
      final req = makeRequest(headers: {'HX-Boosted': ['false']});
      expect(isHtmxBoosted(req), isFalse);
    });
  });

  group('combined HTMX headers', () {
    test('all HTMX headers work together on a single request', () {
      final req = makeRequest(headers: {
        'HX-Request': ['true'],
        'HX-Target': ['content'],
        'HX-Trigger': ['btn'],
        'HX-Boosted': ['true'],
      });
      expect(isHtmxRequest(req), isTrue);
      expect(htmxTarget(req), equals('content'));
      expect(htmxTrigger(req), equals('btn'));
      expect(isHtmxBoosted(req), isTrue);
    });
  });
}
