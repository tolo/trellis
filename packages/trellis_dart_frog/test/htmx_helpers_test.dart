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
  });

  group('htmxTrigger', () {
    test('returns trigger ID when HX-Trigger header is present', () {
      expect(htmxTrigger(makeContext(headers: {'hx-trigger': 'my-button'})), 'my-button');
    });

    test('returns null when HX-Trigger header is absent', () {
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
      expect(htmxTrigger(context), 'nav-link');
      expect(isHtmxBoosted(context), isTrue);
    });
  });
}
