import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:trellis_shelf/trellis_shelf.dart';

void main() {
  Request makeRequest({Map<String, String>? headers}) {
    return Request('GET', Uri.parse('http://localhost/'), headers: headers);
  }

  group('isHtmxRequest', () {
    test('returns true when HX-Request header is "true"', () {
      expect(isHtmxRequest(makeRequest(headers: {'hx-request': 'true'})), isTrue);
    });

    test('returns false when HX-Request header is absent', () {
      expect(isHtmxRequest(makeRequest()), isFalse);
    });

    test('returns false when HX-Request header has wrong value', () {
      expect(isHtmxRequest(makeRequest(headers: {'hx-request': 'false'})), isFalse);
    });
  });

  group('htmxTarget', () {
    test('returns target ID when HX-Target header is present', () {
      expect(htmxTarget(makeRequest(headers: {'hx-target': '#content'})), '#content');
    });

    test('returns null when HX-Target header is absent', () {
      expect(htmxTarget(makeRequest()), isNull);
    });
  });

  group('htmxTrigger', () {
    test('returns trigger ID when HX-Trigger header is present', () {
      expect(htmxTrigger(makeRequest(headers: {'hx-trigger': 'my-button'})), 'my-button');
    });

    test('returns null when HX-Trigger header is absent', () {
      expect(htmxTrigger(makeRequest()), isNull);
    });
  });

  group('isHtmxBoosted', () {
    test('returns true when HX-Boosted header is "true"', () {
      expect(isHtmxBoosted(makeRequest(headers: {'hx-boosted': 'true'})), isTrue);
    });

    test('returns false when HX-Boosted header is absent', () {
      expect(isHtmxBoosted(makeRequest()), isFalse);
    });

    test('returns false when HX-Boosted header has wrong value', () {
      expect(isHtmxBoosted(makeRequest(headers: {'hx-boosted': 'false'})), isFalse);
    });
  });

  group('combined headers', () {
    test('all HTMX headers work together on a single request', () {
      final request = makeRequest(
        headers: {'hx-request': 'true', 'hx-target': '#main', 'hx-trigger': 'nav-link', 'hx-boosted': 'true'},
      );

      expect(isHtmxRequest(request), isTrue);
      expect(htmxTarget(request), '#main');
      expect(htmxTrigger(request), 'nav-link');
      expect(isHtmxBoosted(request), isTrue);
    });
  });
}
