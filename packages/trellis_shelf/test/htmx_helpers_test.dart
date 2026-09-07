// ignore_for_file: deprecated_member_use_from_same_package

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

    test('extracts the id from the HTMX 4 tag#id value', () {
      expect(htmxTarget(makeRequest(headers: {'hx-source': 'button#save', 'hx-target': 'main#content'})), 'content');
    });

    test('returns null when the HTMX 4 target has no id', () {
      expect(htmxTarget(makeRequest(headers: {'hx-source': 'button#save', 'hx-target': 'form'})), isNull);
    });

    test('decodes the encodeURI-encoded HTMX 4 id', () {
      expect(htmxTarget(makeRequest(headers: {'hx-source': 'button', 'hx-target': 'div#r%C3%A4knare'})), 'räknare');
    });

    test('returns the raw id when the HTMX 4 value is not valid percent-encoding', () {
      expect(htmxTarget(makeRequest(headers: {'hx-source': 'button', 'hx-target': 'div#%zz'})), '%zz');
      expect(htmxTarget(makeRequest(headers: {'hx-source': 'button', 'hx-target': 'div#%C3'})), '%C3');
    });
  });

  group('htmxSource', () {
    test('returns the HX-Trigger request header under HTMX 2', () {
      expect(htmxSource(makeRequest(headers: {'hx-trigger': 'my-button'})), 'my-button');
    });

    test('extracts the id from HX-Source under HTMX 4', () {
      expect(htmxSource(makeRequest(headers: {'hx-source': 'button#my-button'})), 'my-button');
    });

    test('returns null when the HTMX 4 source has no id', () {
      expect(htmxSource(makeRequest(headers: {'hx-source': 'button'})), isNull);
    });

    test('returns null when neither header is present', () {
      expect(htmxSource(makeRequest()), isNull);
    });
  });

  group('htmxTrigger', () {
    test('is a deprecated alias of htmxSource on both HTMX versions', () {
      expect(htmxTrigger(makeRequest(headers: {'hx-trigger': 'my-button'})), 'my-button');
      expect(htmxTrigger(makeRequest(headers: {'hx-source': 'a#nav-link'})), 'nav-link');
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
      expect(htmxSource(request), 'nav-link');
      expect(isHtmxBoosted(request), isTrue);
    });

    test('all HTMX 4 headers work together on a single request', () {
      final request = makeRequest(
        headers: {'hx-request': 'true', 'hx-target': 'main#main', 'hx-source': 'a#nav-link', 'hx-boosted': 'true'},
      );

      expect(isHtmxRequest(request), isTrue);
      expect(htmxTarget(request), 'main');
      expect(htmxSource(request), 'nav-link');
      expect(isHtmxBoosted(request), isTrue);
    });
  });
}
