import 'package:test/test.dart';
import 'package:trellis/src/expression/ast.dart';
import 'package:trellis/src/expression/parser.dart';
import 'package:trellis/trellis.dart';

void main() {
  group('Parser', () {
    Expr parse(String source) => Parser(source).parse();

    group('literals', () {
      test('string literal', () {
        final expr = parse("'hello'");
        expect(expr, isA<LiteralExpr>().having((e) => e.value, 'value', 'hello'));
      });

      test('integer literal', () {
        final expr = parse('42');
        expect(expr, isA<LiteralExpr>().having((e) => e.value, 'value', 42));
      });

      test('double literal', () {
        final expr = parse('3.14');
        expect(expr, isA<LiteralExpr>().having((e) => e.value, 'value', 3.14));
      });

      test('boolean true', () {
        final expr = parse('true');
        expect(expr, isA<LiteralExpr>().having((e) => e.value, 'value', true));
      });

      test('boolean false', () {
        final expr = parse('false');
        expect(expr, isA<LiteralExpr>().having((e) => e.value, 'value', false));
      });

      test('null', () {
        final expr = parse('null');
        expect(expr, isA<LiteralExpr>().having((e) => e.value, 'value', isNull));
      });
    });

    group('variable expressions', () {
      test(r'${name}', () {
        final expr = parse(r'${name}');
        expect(expr, isA<VariableExpr>().having((e) => e.name, 'name', 'name'));
      });

      test(r'${user.name} — member access', () {
        final expr = parse(r'${user.name}');
        expect(expr, isA<MemberAccessExpr>());
        final member = expr as MemberAccessExpr;
        expect(member.object, isA<VariableExpr>().having((e) => e.name, 'name', 'user'));
        expect(member.member, 'name');
      });

      test(r'${a.b.c} — nested member access', () {
        final expr = parse(r'${a.b.c}');
        expect(expr, isA<MemberAccessExpr>());
        final outer = expr as MemberAccessExpr;
        expect(outer.member, 'c');
        expect(outer.object, isA<MemberAccessExpr>());
        final inner = outer.object as MemberAccessExpr;
        expect(inner.member, 'b');
        expect(inner.object, isA<VariableExpr>().having((e) => e.name, 'name', 'a'));
      });

      test(r'${items[0]} — index access', () {
        final expr = parse(r'${items[0]}');
        expect(expr, isA<IndexAccessExpr>());
        final idx = expr as IndexAccessExpr;
        expect(idx.object, isA<VariableExpr>().having((e) => e.name, 'name', 'items'));
        expect(idx.index, 0);
      });
    });

    group('comparisons', () {
      test(r'${age >= 18} parses as comparison expression', () {
        final expr = parse(r'${age >= 18}');
        expect(expr, isA<BinaryExpr>());
        final bin = expr as BinaryExpr;
        expect(bin.op, BinaryOp.gte);
      });

      test(r'${a} == ${b}', () {
        final expr = parse(r'${a} == ${b}');
        expect(expr, isA<BinaryExpr>());
        final bin = expr as BinaryExpr;
        expect(bin.op, BinaryOp.eq);
        expect(bin.left, isA<VariableExpr>());
        expect(bin.right, isA<VariableExpr>());
      });

      test(r'${x} > ${y}', () {
        final expr = parse(r'${x} > ${y}');
        expect(expr, isA<BinaryExpr>().having((e) => e.op, 'op', BinaryOp.gt));
      });
    });

    group('boolean ops', () {
      test(r'${a} and ${b}', () {
        final expr = parse(r'${a} and ${b}');
        expect(expr, isA<BinaryExpr>().having((e) => e.op, 'op', BinaryOp.and_));
      });

      test(r'${a} or ${b}', () {
        final expr = parse(r'${a} or ${b}');
        expect(expr, isA<BinaryExpr>().having((e) => e.op, 'op', BinaryOp.or_));
      });

      test(r'not ${a}', () {
        final expr = parse(r'not ${a}');
        expect(expr, isA<UnaryExpr>().having((e) => e.op, 'op', UnaryOp.not_));
      });
    });

    group('string concat', () {
      test(r'${a} + ${b}', () {
        final expr = parse(r'${a} + ${b}');
        expect(expr, isA<BinaryExpr>().having((e) => e.op, 'op', BinaryOp.plus));
      });
    });

    group('ternary', () {
      test(r"${cond} ? 'yes' : 'no'", () {
        final expr = parse(r"${cond} ? 'yes' : 'no'");
        expect(expr, isA<TernaryExpr>());
        final tern = expr as TernaryExpr;
        expect(tern.condition, isA<VariableExpr>());
        expect(tern.ifTrue, isA<LiteralExpr>().having((e) => e.value, 'value', 'yes'));
        expect(tern.ifFalse, isA<LiteralExpr>().having((e) => e.value, 'value', 'no'));
      });
    });

    group('elvis', () {
      test(r"${val} ?: 'default'", () {
        final expr = parse(r"${val} ?: 'default'");
        expect(expr, isA<ElvisExpr>());
        final elvis = expr as ElvisExpr;
        expect(elvis.left, isA<VariableExpr>());
        expect(elvis.right, isA<LiteralExpr>().having((e) => e.value, 'value', 'default'));
      });
    });

    group('URL expressions', () {
      test(r'@{/path(key=${val})}', () {
        final expr = parse(r'@{/path(key=${val})}');
        expect(expr, isA<UrlExpr>());
        final url = expr as UrlExpr;
        expect(url.path, '/path');
        expect(url.params, hasLength(1));
        expect(url.params[0].$1, 'key');
        expect(url.params[0].$2, isA<VariableExpr>());
      });

      test('@{/simple} — no params', () {
        final expr = parse('@{/simple}');
        expect(expr, isA<UrlExpr>());
        final url = expr as UrlExpr;
        expect(url.path, '/simple');
        expect(url.params, isEmpty);
      });
    });

    group('precedence', () {
      test(r'${a} or ${b} and ${c} — and binds tighter', () {
        final expr = parse(r'${a} or ${b} and ${c}');
        expect(expr, isA<BinaryExpr>());
        final or_ = expr as BinaryExpr;
        expect(or_.op, BinaryOp.or_);
        expect(or_.right, isA<BinaryExpr>().having((e) => e.op, 'op', BinaryOp.and_));
      });
    });

    group('grouping', () {
      test(r'(${a} or ${b}) and ${c}', () {
        final expr = parse(r'(${a} or ${b}) and ${c}');
        expect(expr, isA<BinaryExpr>());
        final and_ = expr as BinaryExpr;
        expect(and_.op, BinaryOp.and_);
        expect(and_.left, isA<BinaryExpr>().having((e) => e.op, 'op', BinaryOp.or_));
      });
    });

    group('errors', () {
      test('malformed expression throws ExpressionException', () {
        expect(() => parse(r'${'), throwsA(isA<ExpressionException>()));
      });

      test('unexpected token throws', () {
        expect(() => parse('=='), throwsA(isA<ExpressionException>()));
      });
    });

    group('pipe expressions', () {
      test('simple pipe produces PipeExpr', () {
        final expr = parse(r'${name | upper}');
        expect(
          expr,
          isA<PipeExpr>()
              .having((e) => e.target, 'target', isA<VariableExpr>().having((v) => v.name, 'name', 'name'))
              .having((e) => e.filterName, 'filterName', 'upper'),
        );
      });

      test('chained pipe is left-associative', () {
        final expr = parse(r'${a | trim | upper}');
        expect(expr, isA<PipeExpr>().having((e) => e.filterName, 'filterName', 'upper'));
        final inner = (expr as PipeExpr).target;
        expect(inner, isA<PipeExpr>().having((e) => e.filterName, 'filterName', 'trim'));
        expect((inner as PipeExpr).target, isA<VariableExpr>().having((v) => v.name, 'name', 'a'));
      });

      test('pipe is lowest precedence (below or)', () {
        final expr = parse(r'${a or b | upper}');
        expect(expr, isA<PipeExpr>().having((e) => e.filterName, 'filterName', 'upper'));
        expect((expr as PipeExpr).target, isA<BinaryExpr>().having((e) => e.op, 'op', BinaryOp.or_));
      });
    });
  });
}
