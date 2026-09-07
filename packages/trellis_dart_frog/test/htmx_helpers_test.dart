// ignore_for_file: deprecated_member_use_from_same_package

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:trellis_dart_frog/trellis_dart_frog.dart';

class _MockRequestContext extends Mock implements RequestContext {}

class _MockRequest extends Mock implements Request {}

RequestContext makeContext({Map<String, String> headers = const {}}) {
  final request = _MockRequest();
  final context = _MockRequestContext();
  when(() => request.headers).thenReturn(headers);
  when(() => context.request).thenReturn(request);
  return context;
}

void main() {
  group('isHtmxRequest', () {
    test('returns true when HX-Request header is "true"', () {
      expect(isHtmxRequest(makeContext(headers: {'hx-request': 'true'})), isTrue);
    });

    test('returns false when HX-Request header is absent', () {
      expect(isHtmxRequest(makeContext()), isFalse);
    });

    test('returns false when HX-Request header has wrong value', () {
      expect(isHtmxRequest(makeContext(headers: {'hx-request': 'false'})), isFalse);
    });
  });

  group('htmxTarget', () {
    test('returns target ID when HX-Target header is present', () {
      expect(htmxTarget(makeContext(headers: {'hx-target': '#content'})), '#content');
    });

    test('returns null when HX-Target header is absent', () {
      expect(htmxTarget(makeContext()), isNull);
    });

    test('extracts the id from the HTMX 4 tag#id value', () {
      expect(htmxTarget(makeContext(headers: {'hx-source': 'button#save', 'hx-target': 'main#content'})), 'content');
    });

    test('returns null when the HTMX 4 target has no id', () {
      expect(htmxTarget(makeContext(headers: {'hx-source': 'button#save', 'hx-target': 'form'})), isNull);
    });

    test('decodes the encodeURI-encoded HTMX 4 id', () {
      expect(htmxTarget(makeContext(headers: {'hx-source': 'button', 'hx-target': 'div#r%C3%A4knare'})), 'räknare');
    });

    test('returns the raw id when the HTMX 4 value is not valid percent-encoding', () {
      expect(htmxTarget(makeContext(headers: {'hx-source': 'button', 'hx-target': 'div#%zz'})), '%zz');
      expect(htmxTarget(makeContext(headers: {'hx-source': 'button', 'hx-target': 'div#%C3'})), '%C3');
    });
  });

  group('htmxSource', () {
    test('returns the HX-Trigger request header under HTMX 2', () {
      expect(htmxSource(makeContext(headers: {'hx-trigger': 'my-button'})), 'my-button');
    });

    test('extracts the id from HX-Source under HTMX 4', () {
      expect(htmxSource(makeContext(headers: {'hx-source': 'button#my-button'})), 'my-button');
    });

    test('returns null when the HTMX 4 source has no id', () {
      expect(htmxSource(makeContext(headers: {'hx-source': 'button'})), isNull);
    });

    test('returns null when neither header is present', () {
      expect(htmxSource(makeContext()), isNull);
    });
  });

  group('htmxTrigger', () {
    test('is a deprecated alias of htmxSource on both HTMX versions', () {
      expect(htmxTrigger(makeContext(headers: {'hx-trigger': 'my-button'})), 'my-button');
      expect(htmxTrigger(makeContext(headers: {'hx-source': 'a#nav-link'})), 'nav-link');
      expect(htmxTrigger(makeContext()), isNull);
    });
  });

  group('isHtmxBoosted', () {
    test('returns true when HX-Boosted header is "true"', () {
      expect(isHtmxBoosted(makeContext(headers: {'hx-boosted': 'true'})), isTrue);
    });

    test('returns false when HX-Boosted header is absent', () {
      expect(isHtmxBoosted(makeContext()), isFalse);
    });

    test('returns false when HX-Boosted header has wrong value', () {
      expect(isHtmxBoosted(makeContext(headers: {'hx-boosted': 'false'})), isFalse);
    });
  });

  group('combined headers', () {
    test('all HTMX headers work together on a single request', () {
      final context = makeContext(
        headers: {'hx-request': 'true', 'hx-target': '#main', 'hx-trigger': 'nav-link', 'hx-boosted': 'true'},
      );
      expect(isHtmxRequest(context), isTrue);
      expect(htmxTarget(context), '#main');
      expect(htmxSource(context), 'nav-link');
      expect(isHtmxBoosted(context), isTrue);
    });

    test('all HTMX 4 headers work together on a single request', () {
      final context = makeContext(
        headers: {'hx-request': 'true', 'hx-target': 'main#main', 'hx-source': 'a#nav-link', 'hx-boosted': 'true'},
      );
      expect(isHtmxRequest(context), isTrue);
      expect(htmxTarget(context), 'main');
      expect(htmxSource(context), 'nav-link');
      expect(isHtmxBoosted(context), isTrue);
    });
  });
}
