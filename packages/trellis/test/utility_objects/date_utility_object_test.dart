import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

String renderTemplate(String html, Map<String, dynamic> context) =>
    Trellis(loader: MapLoader({}), cache: false).render(html, context);

void main() {
  late ExpressionEvaluator eval;
  final fixedDate = DateTime(2026, 3, 17, 14, 30, 45); // Tuesday

  setUp(() {
    eval = ExpressionEvaluator();
    ExpressionEvaluator.formattingDelegate = null;
  });

  tearDown(() {
    ExpressionEvaluator.formattingDelegate = null;
  });

  group('#dates', () {
    group('format', () {
      test("pattern 'yyyy-MM-dd'", () {
        expect(eval.evaluate(r"${#dates.format(d, 'yyyy-MM-dd')}", {'d': fixedDate}), equals('2026-03-17'));
      });

      test("pattern 'MMMM d, yyyy'", () {
        expect(eval.evaluate(r"${#dates.format(d, 'MMMM d, yyyy')}", {'d': fixedDate}), equals('March 17, 2026'));
      });

      test("pattern 'MMM d, yyyy'", () {
        expect(eval.evaluate(r"${#dates.format(d, 'MMM d, yyyy')}", {'d': fixedDate}), equals('Mar 17, 2026'));
      });

      test("pattern 'HH:mm:ss'", () {
        expect(eval.evaluate(r"${#dates.format(d, 'HH:mm:ss')}", {'d': fixedDate}), equals('14:30:45'));
      });

      test("pattern 'hh:mm a' (12-hour)", () {
        expect(eval.evaluate(r"${#dates.format(d, 'hh:mm a')}", {'d': fixedDate}), equals('02:30 PM'));
      });

      test("pattern 'EEE, MMM d'", () {
        expect(eval.evaluate(r"${#dates.format(d, 'EEE, MMM d')}", {'d': fixedDate}), equals('Tue, Mar 17'));
      });

      test("pattern 'EEEE'", () {
        expect(eval.evaluate(r"${#dates.format(d, 'EEEE')}", {'d': fixedDate}), equals('Tuesday'));
      });

      test("pattern 'yyyy-MM-dd HH:mm:ss'", () {
        expect(
          eval.evaluate(r"${#dates.format(d, 'yyyy-MM-dd HH:mm:ss')}", {'d': fixedDate}),
          equals('2026-03-17 14:30:45'),
        );
      });

      test("pattern 'MM/dd/yy'", () {
        expect(eval.evaluate(r"${#dates.format(d, 'MM/dd/yy')}", {'d': fixedDate}), equals('03/17/26'));
      });

      test('null returns null', () {
        expect(eval.evaluate(r"${#dates.format(d, 'yyyy-MM-dd')}", {'d': null}), isNull);
      });

      test('ISO 8601 string input', () {
        expect(eval.evaluate(r"${#dates.format(d, 'yyyy-MM-dd')}", {'d': '2026-03-17'}), equals('2026-03-17'));
      });

      test('AM for morning', () {
        final morning = DateTime(2026, 3, 17, 9, 0);
        expect(eval.evaluate(r"${#dates.format(d, 'hh:mm a')}", {'d': morning}), equals('09:00 AM'));
      });

      test('midnight (12 AM)', () {
        final midnight = DateTime(2026, 3, 17, 0, 0);
        expect(eval.evaluate(r"${#dates.format(d, 'hh:mm a')}", {'d': midnight}), equals('12:00 AM'));
      });

      test('noon (12 PM)', () {
        final noon = DateTime(2026, 3, 17, 12, 0);
        expect(eval.evaluate(r"${#dates.format(d, 'hh:mm a')}", {'d': noon}), equals('12:00 PM'));
      });
    });

    group('parse', () {
      test('parses ISO 8601 date', () {
        final result = eval.evaluate(r'${#dates.parse(s)}', {'s': '2026-03-17'});
        expect(result, isA<DateTime>());
        expect((result as DateTime).year, equals(2026));
        expect(result.month, equals(3));
        expect(result.day, equals(17));
      });

      test('parses ISO 8601 datetime', () {
        final result = eval.evaluate(r'${#dates.parse(s)}', {'s': '2026-03-17T14:30:00'});
        expect(result, isA<DateTime>());
        expect((result as DateTime).hour, equals(14));
      });

      test('null returns null', () {
        expect(eval.evaluate(r'${#dates.parse(s)}', {'s': null}), isNull);
      });

      test('invalid string throws', () {
        expect(() => eval.evaluate(r'${#dates.parse(s)}', {'s': 'not-a-date'}), throwsA(isA<ExpressionException>()));
      });
    });

    group('now', () {
      test('returns a DateTime close to current time', () {
        final before = DateTime.now().subtract(const Duration(seconds: 1));
        final result = eval.evaluate(r'${#dates.now()}', {});
        final after = DateTime.now().add(const Duration(seconds: 1));
        expect(result, isA<DateTime>());
        expect((result as DateTime).isAfter(before), isTrue);
        expect(result.isBefore(after), isTrue);
      });
    });

    group('year/month/day/hour/minute/second', () {
      test('year', () {
        expect(eval.evaluate(r'${#dates.year(d)}', {'d': fixedDate}), equals(2026));
      });

      test('month', () {
        expect(eval.evaluate(r'${#dates.month(d)}', {'d': fixedDate}), equals(3));
      });

      test('day', () {
        expect(eval.evaluate(r'${#dates.day(d)}', {'d': fixedDate}), equals(17));
      });

      test('hour', () {
        expect(eval.evaluate(r'${#dates.hour(d)}', {'d': fixedDate}), equals(14));
      });

      test('minute', () {
        expect(eval.evaluate(r'${#dates.minute(d)}', {'d': fixedDate}), equals(30));
      });

      test('second', () {
        expect(eval.evaluate(r'${#dates.second(d)}', {'d': fixedDate}), equals(45));
      });

      test('null input returns null', () {
        expect(eval.evaluate(r'${#dates.year(d)}', {'d': null}), isNull);
        expect(eval.evaluate(r'${#dates.month(d)}', {'d': null}), isNull);
        expect(eval.evaluate(r'${#dates.day(d)}', {'d': null}), isNull);
      });

      test('ISO string input', () {
        expect(eval.evaluate(r'${#dates.year(d)}', {'d': '2026-01-15'}), equals(2026));
      });
    });

    group('dayOfWeek', () {
      test('Tuesday = 2 (ISO 8601: Monday=1)', () {
        expect(eval.evaluate(r'${#dates.dayOfWeek(d)}', {'d': fixedDate}), equals(2));
      });

      test('null returns null', () {
        expect(eval.evaluate(r'${#dates.dayOfWeek(d)}', {'d': null}), isNull);
      });

      test('Monday = 1', () {
        final monday = DateTime(2026, 3, 16);
        expect(eval.evaluate(r'${#dates.dayOfWeek(d)}', {'d': monday}), equals(1));
      });

      test('Sunday = 7', () {
        final sunday = DateTime(2026, 3, 22);
        expect(eval.evaluate(r'${#dates.dayOfWeek(d)}', {'d': sunday}), equals(7));
      });
    });

    group('isBefore / isAfter', () {
      final earlier = DateTime(2026, 1, 1);
      final later = DateTime(2026, 12, 31);

      test('isBefore: earlier is before later', () {
        expect(eval.evaluate(r'${#dates.isBefore(a, b)}', {'a': earlier, 'b': later}), isTrue);
      });

      test('isBefore: later is not before earlier', () {
        expect(eval.evaluate(r'${#dates.isBefore(a, b)}', {'a': later, 'b': earlier}), isFalse);
      });

      test('isAfter: later is after earlier', () {
        expect(eval.evaluate(r'${#dates.isAfter(a, b)}', {'a': later, 'b': earlier}), isTrue);
      });

      test('isBefore with null a returns false', () {
        expect(eval.evaluate(r'${#dates.isBefore(a, b)}', {'a': null, 'b': later}), isFalse);
      });

      test('isBefore with null b returns false', () {
        expect(eval.evaluate(r'${#dates.isBefore(a, b)}', {'a': earlier, 'b': null}), isFalse);
      });

      test('isAfter with null returns false', () {
        expect(eval.evaluate(r'${#dates.isAfter(a, b)}', {'a': null, 'b': later}), isFalse);
      });
    });

    group('invalid input', () {
      test('non-date, non-string throws', () {
        expect(() => eval.evaluate(r'${#dates.year(d)}', {'d': 42}), throwsA(isA<ExpressionException>()));
      });

      test('error message mentions method name', () {
        expect(
          () => eval.evaluate(r'${#dates.year(d)}', {'d': 42}),
          throwsA(isA<ExpressionException>().having((e) => e.toString(), 'message', contains('#dates.year'))),
        );
      });
    });

    group('error handling', () {
      test('unknown method throws', () {
        expect(() => eval.evaluate(r'${#dates.unknown()}', {}), throwsA(isA<ExpressionException>()));
      });
    });

    group('integration', () {
      test('tl:text with #dates.format', () {
        final result = renderTemplate("<p tl:text=\"\${#dates.format(d, 'yyyy-MM-dd')}\">x</p>", {'d': fixedDate});
        expect(result, contains('<p>2026-03-17</p>'));
      });

      test('tl:if with date comparison', () {
        final result = renderTemplate(r'<span tl:if="${#dates.year(d) == 2026}">yes</span>', {'d': fixedDate});
        expect(result, contains('<span>yes</span>'));
      });
    });
  });
}
