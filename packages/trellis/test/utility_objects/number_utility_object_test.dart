import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

String renderTemplate(String html, Map<String, dynamic> context) =>
    Trellis(loader: MapLoader({}), cache: false).render(html, context);

void main() {
  late ExpressionEvaluator eval;

  setUp(() {
    eval = ExpressionEvaluator();
    ExpressionEvaluator.formattingDelegate = null;
  });

  tearDown(() {
    ExpressionEvaluator.formattingDelegate = null;
  });

  group('#numbers', () {
    group('format', () {
      test('no pattern returns toString', () {
        expect(eval.evaluate(r'${#numbers.format(v)}', {'v': 42}), equals('42'));
      });

      test('no pattern for double returns toString', () {
        expect(eval.evaluate(r'${#numbers.format(v)}', {'v': 3.14}), equals('3.14'));
      });

      test('null returns null', () {
        expect(eval.evaluate(r'${#numbers.format(v)}', {'v': null}), isNull);
      });

      test("pattern '0.00' formats to 2 decimals", () {
        expect(eval.evaluate(r"${#numbers.format(v, '0.00')}", {'v': 3.1}), equals('3.10'));
      });

      test("pattern '0.00' with integer", () {
        expect(eval.evaluate(r"${#numbers.format(v, '0.00')}", {'v': 42}), equals('42.00'));
      });

      test("pattern '#,###' adds thousand separators", () {
        expect(eval.evaluate(r"${#numbers.format(v, '#,###')}", {'v': 1234567}), equals('1,234,567'));
      });

      test("pattern '#,###' for small number", () {
        expect(eval.evaluate(r"${#numbers.format(v, '#,###')}", {'v': 999}), equals('999'));
      });

      test("pattern '#,##0.00' adds grouping and decimals", () {
        expect(eval.evaluate(r"${#numbers.format(v, '#,##0.00')}", {'v': 1234.5}), equals('1,234.50'));
      });

      test('non-number string that parses as number', () {
        expect(eval.evaluate(r"${#numbers.format(v, '0.00')}", {'v': '3.1'}), equals('3.10'));
      });

      test('non-number string that fails throws', () {
        expect(
          () => eval.evaluate(r"${#numbers.format(v, '0.00')}", {'v': 'abc'}),
          throwsA(isA<ExpressionException>()),
        );
      });
    });

    group('formatPercent', () {
      test('0% with 0 decimals', () {
        expect(eval.evaluate(r'${#numbers.formatPercent(v)}', {'v': 0}), equals('0%'));
      });

      test('100% with 0 decimals', () {
        expect(eval.evaluate(r'${#numbers.formatPercent(v)}', {'v': 1}), equals('100%'));
      });

      test('50% with 0 decimals', () {
        expect(eval.evaluate(r'${#numbers.formatPercent(v)}', {'v': 0.5}), equals('50%'));
      });

      test('with custom decimal places', () {
        expect(eval.evaluate(r'${#numbers.formatPercent(v, 2)}', {'v': 0.1234}), equals('12.34%'));
      });

      test('null returns null', () {
        expect(eval.evaluate(r'${#numbers.formatPercent(v)}', {'v': null}), isNull);
      });
    });

    group('formatCurrency', () {
      test('default currency code is USD', () {
        expect(eval.evaluate(r'${#numbers.formatCurrency(v)}', {'v': 42.5}), equals('USD 42.50'));
      });

      test('custom currency code', () {
        expect(eval.evaluate(r"${#numbers.formatCurrency(v, 'EUR')}", {'v': 9.99}), equals('EUR 9.99'));
      });

      test('null returns null', () {
        expect(eval.evaluate(r'${#numbers.formatCurrency(v)}', {'v': null}), isNull);
      });
    });

    group('abs', () {
      test('negative int', () {
        expect(eval.evaluate(r'${#numbers.abs(v)}', {'v': -5}), equals(5));
      });

      test('negative double', () {
        expect(eval.evaluate(r'${#numbers.abs(v)}', {'v': -3.14}), equals(3.14));
      });

      test('positive unchanged', () {
        expect(eval.evaluate(r'${#numbers.abs(v)}', {'v': 5}), equals(5));
      });

      test('null returns null', () {
        expect(eval.evaluate(r'${#numbers.abs(v)}', {'v': null}), isNull);
      });
    });

    group('ceil', () {
      test('rounds up', () {
        expect(eval.evaluate(r'${#numbers.ceil(v)}', {'v': 3.2}), equals(4));
      });

      test('integer unchanged', () {
        expect(eval.evaluate(r'${#numbers.ceil(v)}', {'v': 4}), equals(4));
      });

      test('null returns null', () {
        expect(eval.evaluate(r'${#numbers.ceil(v)}', {'v': null}), isNull);
      });
    });

    group('floor', () {
      test('rounds down', () {
        expect(eval.evaluate(r'${#numbers.floor(v)}', {'v': 3.9}), equals(3));
      });

      test('negative rounds down', () {
        expect(eval.evaluate(r'${#numbers.floor(v)}', {'v': -3.1}), equals(-4));
      });

      test('null returns null', () {
        expect(eval.evaluate(r'${#numbers.floor(v)}', {'v': null}), isNull);
      });
    });

    group('round', () {
      test('rounds to nearest int', () {
        expect(eval.evaluate(r'${#numbers.round(v)}', {'v': 3.5}), equals(4));
      });

      test('rounds down', () {
        expect(eval.evaluate(r'${#numbers.round(v)}', {'v': 3.4}), equals(3));
      });

      test('with 2 decimals', () {
        expect(eval.evaluate(r'${#numbers.round(v, 2)}', {'v': 3.14159}), equals(3.14));
      });

      test('null returns null', () {
        expect(eval.evaluate(r'${#numbers.round(v)}', {'v': null}), isNull);
      });

      test('negative input', () {
        expect(eval.evaluate(r'${#numbers.round(v)}', {'v': -3.5}), equals(-4));
      });
    });

    group('min', () {
      test('returns smaller value', () {
        expect(eval.evaluate(r'${#numbers.min(a, b)}', {'a': 3, 'b': 7}), equals(3));
      });

      test('null a returns null', () {
        expect(eval.evaluate(r'${#numbers.min(a, b)}', {'a': null, 'b': 5}), isNull);
      });

      test('null b returns null', () {
        expect(eval.evaluate(r'${#numbers.min(a, b)}', {'a': 5, 'b': null}), isNull);
      });

      test('equal values', () {
        expect(eval.evaluate(r'${#numbers.min(a, b)}', {'a': 5, 'b': 5}), equals(5));
      });
    });

    group('max', () {
      test('returns larger value', () {
        expect(eval.evaluate(r'${#numbers.max(a, b)}', {'a': 3, 'b': 7}), equals(7));
      });

      test('null a returns null', () {
        expect(eval.evaluate(r'${#numbers.max(a, b)}', {'a': null, 'b': 5}), isNull);
      });

      test('zero vs negative', () {
        expect(eval.evaluate(r'${#numbers.max(a, b)}', {'a': 0, 'b': -5}), equals(0));
      });
    });

    group('clamp', () {
      test('value within range unchanged', () {
        expect(eval.evaluate(r'${#numbers.clamp(v, 0, 10)}', {'v': 5}), equals(5));
      });

      test('value below min clamped to min', () {
        expect(eval.evaluate(r'${#numbers.clamp(v, 0, 10)}', {'v': -5}), equals(0));
      });

      test('value above max clamped to max', () {
        expect(eval.evaluate(r'${#numbers.clamp(v, 0, 10)}', {'v': 15}), equals(10));
      });

      test('null returns null', () {
        expect(eval.evaluate(r'${#numbers.clamp(v, 0, 10)}', {'v': null}), isNull);
      });
    });

    group('error handling', () {
      test('unknown method throws ExpressionException', () {
        expect(() => eval.evaluate(r'${#numbers.unknown()}', {}), throwsA(isA<ExpressionException>()));
      });

      test('wrong arg count throws', () {
        expect(() => eval.evaluate(r'${#numbers.abs()}', {}), throwsA(isA<ExpressionException>()));
      });
    });

    group('integration', () {
      test('tl:text with #numbers.format', () {
        final result = renderTemplate("<p tl:text=\"\${#numbers.format(price, '0.00')}\">x</p>", {'price': 9.5});
        expect(result, contains('<p>9.50</p>'));
      });
    });
  });
}
