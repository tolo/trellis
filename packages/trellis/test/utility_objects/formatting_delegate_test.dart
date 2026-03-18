import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

/// Mock FormattingDelegate for testing.
class _MockFormattingDelegate extends FormattingDelegate {
  final List<({num value, String pattern})> numberCalls = [];
  final List<({DateTime date, String pattern})> dateCalls = [];
  String? numberResult;
  String? dateResult;

  @override
  String? formatNumber(num value, String pattern, {String? locale}) {
    numberCalls.add((value: value, pattern: pattern));
    return numberResult;
  }

  @override
  String? formatDate(DateTime date, String pattern, {String? locale}) {
    dateCalls.add((date: date, pattern: pattern));
    return dateResult;
  }
}

void main() {
  late ExpressionEvaluator eval;
  late _MockFormattingDelegate mockDelegate;

  setUp(() {
    eval = ExpressionEvaluator();
    mockDelegate = _MockFormattingDelegate();
    ExpressionEvaluator.formattingDelegate = null;
  });

  tearDown(() {
    ExpressionEvaluator.formattingDelegate = null;
  });

  group('FormattingDelegate', () {
    group('when null (default)', () {
      test('#numbers.format uses built-in formatting', () {
        expect(eval.evaluate(r"${#numbers.format(v, '0.00')}", {'v': 3.1}), equals('3.10'));
      });

      test('#dates.format uses built-in formatting', () {
        final date = DateTime(2026, 3, 17);
        expect(eval.evaluate(r"${#dates.format(d, 'yyyy-MM-dd')}", {'d': date}), equals('2026-03-17'));
      });
    });

    group('when set', () {
      test('#numbers.format delegates to it', () {
        mockDelegate.numberResult = 'MOCK_NUMBER';
        ExpressionEvaluator.formattingDelegate = mockDelegate;

        final result = eval.evaluate(r"${#numbers.format(v, '0.00')}", {'v': 42.5});
        expect(result, equals('MOCK_NUMBER'));
        expect(mockDelegate.numberCalls.length, equals(1));
        expect(mockDelegate.numberCalls[0].value, equals(42.5));
        expect(mockDelegate.numberCalls[0].pattern, equals('0.00'));
      });

      test('#dates.format delegates to it', () {
        final date = DateTime(2026, 3, 17);
        mockDelegate.dateResult = 'MOCK_DATE';
        ExpressionEvaluator.formattingDelegate = mockDelegate;

        final result = eval.evaluate(r"${#dates.format(d, 'yyyy-MM-dd')}", {'d': date});
        expect(result, equals('MOCK_DATE'));
        expect(mockDelegate.dateCalls.length, equals(1));
        expect(mockDelegate.dateCalls[0].date, equals(date));
        expect(mockDelegate.dateCalls[0].pattern, equals('yyyy-MM-dd'));
      });

      test('when delegate returns null, falls back to built-in', () {
        mockDelegate.numberResult = null; // delegate returns null → use built-in
        ExpressionEvaluator.formattingDelegate = mockDelegate;

        final result = eval.evaluate(r"${#numbers.format(v, '0.00')}", {'v': 3.1});
        expect(result, equals('3.10'));
      });

      test('when date delegate returns null, falls back to built-in', () {
        final date = DateTime(2026, 3, 17);
        mockDelegate.dateResult = null;
        ExpressionEvaluator.formattingDelegate = mockDelegate;

        final result = eval.evaluate(r"${#dates.format(d, 'yyyy-MM-dd')}", {'d': date});
        expect(result, equals('2026-03-17'));
      });

      test('delegate is shared across evaluator instances', () {
        mockDelegate.numberResult = 'SHARED';
        ExpressionEvaluator.formattingDelegate = mockDelegate;

        final eval2 = ExpressionEvaluator();
        final result = eval2.evaluate(r"${#numbers.format(v, '0.00')}", {'v': 1.0});
        expect(result, equals('SHARED'));
      });

      test('resetting to null reverts to built-in', () {
        mockDelegate.numberResult = 'MOCK';
        ExpressionEvaluator.formattingDelegate = mockDelegate;
        ExpressionEvaluator.formattingDelegate = null;

        final result = eval.evaluate(r"${#numbers.format(v, '0.00')}", {'v': 3.1});
        expect(result, equals('3.10'));
      });
    });

    group('UtilityObject and FormattingDelegate are exported from barrel', () {
      test('UtilityObject type is accessible', () {
        // Just verifying the type is importable and usable
        // (already imported via package:trellis/trellis.dart in the test file)
        expect(FormattingDelegate, isNotNull);
        expect(UtilityObject, isNotNull);
      });
    });
  });
}
