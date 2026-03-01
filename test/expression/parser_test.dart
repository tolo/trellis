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

      test(r'${obj.gt} — alias word as member name', () {
        final expr = parse(r'${obj.gt}');
        expect(expr, isA<MemberAccessExpr>());
        final member = expr as MemberAccessExpr;
        expect(member.object, isA<VariableExpr>().having((e) => e.name, 'name', 'obj'));
        expect(member.member, 'gt');
      });

      test('alias/keyword words as member names', () {
        for (final word in ['gt', 'lt', 'ge', 'le', 'eq', 'ne', 'and', 'or', 'not', 'true', 'false', 'null']) {
          final expr = parse('\${obj.$word}');
          expect(expr, isA<MemberAccessExpr>(), reason: 'obj.$word should parse');
          expect((expr as MemberAccessExpr).member, word, reason: 'member name should be "$word"');
        }
      });

      test(r'${obj.+} — invalid member name throws', () {
        expect(() => parse(r'${obj.+}'), throwsA(isA<ExpressionException>()));
      });

      test(r'${obj.} — missing member name throws', () {
        expect(() => parse(r'${obj.}'), throwsA(isA<ExpressionException>()));
      });

      test(r'${a.not.gt} — chained keyword members', () {
        final expr = parse(r'${a.not.gt}');
        expect(expr, isA<MemberAccessExpr>());
        final outer = expr as MemberAccessExpr;
        expect(outer.member, 'gt');
        expect(outer.object, isA<MemberAccessExpr>());
        final inner = outer.object as MemberAccessExpr;
        expect(inner.member, 'not');
        expect(inner.object, isA<VariableExpr>().having((e) => e.name, 'name', 'a'));
      });

      test(r'${items[0]} — index access', () {
        final expr = parse(r'${items[0]}');
        expect(expr, isA<IndexAccessExpr>());
        final idx = expr as IndexAccessExpr;
        expect(idx.object, isA<VariableExpr>().having((e) => e.name, 'name', 'items'));
        expect(idx.index, isA<LiteralExpr>().having((e) => e.value, 'value', 0));
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

    group('arithmetic expressions', () {
      test(r'${a + b}', () {
        final expr = parse(r'${a + b}');
        expect(expr, isA<BinaryExpr>().having((e) => e.op, 'op', BinaryOp.plus));
      });

      test(r'${a - b}', () {
        final expr = parse(r'${a - b}');
        expect(expr, isA<BinaryExpr>().having((e) => e.op, 'op', BinaryOp.minus));
      });

      test(r'${a * b}', () {
        final expr = parse(r'${a * b}');
        expect(expr, isA<BinaryExpr>().having((e) => e.op, 'op', BinaryOp.star));
      });

      test(r'${a / b}', () {
        final expr = parse(r'${a / b}');
        expect(expr, isA<BinaryExpr>().having((e) => e.op, 'op', BinaryOp.slash));
      });

      test(r'${a % b}', () {
        final expr = parse(r'${a % b}');
        expect(expr, isA<BinaryExpr>().having((e) => e.op, 'op', BinaryOp.percent));
      });

      test(r'${2 + 3 * 4} — * binds tighter than +', () {
        final expr = parse(r'${2 + 3 * 4}');
        expect(expr, isA<BinaryExpr>());
        final bin = expr as BinaryExpr;
        expect(bin.op, BinaryOp.plus);
        expect(bin.left, isA<LiteralExpr>().having((e) => e.value, 'value', 2));
        expect(bin.right, isA<BinaryExpr>().having((e) => e.op, 'op', BinaryOp.star));
      });

      test(r'${2 * 3 + 4} — * binds tighter (left)', () {
        final expr = parse(r'${2 * 3 + 4}');
        expect(expr, isA<BinaryExpr>());
        final bin = expr as BinaryExpr;
        expect(bin.op, BinaryOp.plus);
        expect(bin.left, isA<BinaryExpr>().having((e) => e.op, 'op', BinaryOp.star));
        expect(bin.right, isA<LiteralExpr>().having((e) => e.value, 'value', 4));
      });

      test(r'${(2 + 3) * 4} — grouping overrides precedence', () {
        final expr = parse(r'${(2 + 3) * 4}');
        expect(expr, isA<BinaryExpr>());
        final bin = expr as BinaryExpr;
        expect(bin.op, BinaryOp.star);
        expect(bin.left, isA<BinaryExpr>().having((e) => e.op, 'op', BinaryOp.plus));
        expect(bin.right, isA<LiteralExpr>().having((e) => e.value, 'value', 4));
      });

      test(r'${-a} — unary minus', () {
        final expr = parse(r'${-a}');
        expect(expr, isA<UnaryExpr>());
        final unary = expr as UnaryExpr;
        expect(unary.op, UnaryOp.minus);
        expect(unary.operand, isA<VariableExpr>().having((e) => e.name, 'name', 'a'));
      });

      test(r'${a - -b} — subtraction with unary minus', () {
        final expr = parse(r'${a - -b}');
        expect(expr, isA<BinaryExpr>());
        final bin = expr as BinaryExpr;
        expect(bin.op, BinaryOp.minus);
        expect(bin.right, isA<UnaryExpr>().having((e) => e.op, 'op', UnaryOp.minus));
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

    group('literal substitution', () {
      test('|Hello| — plain text', () {
        final expr = parse('|Hello|');
        expect(expr, isA<LiteralSubstitutionExpr>());
        final parts = (expr as LiteralSubstitutionExpr).parts;
        expect(parts, hasLength(1));
        expect(parts[0], isA<LiteralExpr>().having((e) => e.value, 'value', 'Hello'));
      });

      test(r'|Hello, ${name}!| — text with expression', () {
        final expr = parse(r'|Hello, ${name}!|');
        expect(expr, isA<LiteralSubstitutionExpr>());
        final parts = (expr as LiteralSubstitutionExpr).parts;
        expect(parts, hasLength(3));
        expect(parts[0], isA<LiteralExpr>().having((e) => e.value, 'value', 'Hello, '));
        expect(parts[1], isA<VariableExpr>().having((e) => e.name, 'name', 'name'));
        expect(parts[2], isA<LiteralExpr>().having((e) => e.value, 'value', '!'));
      });

      test('|| — empty literal sub', () {
        final expr = parse('||');
        expect(expr, isA<LiteralSubstitutionExpr>());
        expect((expr as LiteralSubstitutionExpr).parts, isEmpty);
      });

      test('unterminated literal sub throws', () {
        expect(() => parse('|hello'), throwsA(isA<ExpressionException>()));
      });
    });

    group('dynamic index', () {
      test(r'${list[i]} — variable index', () {
        final expr = parse(r'${list[i]}');
        expect(expr, isA<IndexAccessExpr>());
        final idx = expr as IndexAccessExpr;
        expect(idx.object, isA<VariableExpr>().having((e) => e.name, 'name', 'list'));
        expect(idx.index, isA<VariableExpr>().having((e) => e.name, 'name', 'i'));
      });

      test(r'${list[i + 1]} — expression index', () {
        final expr = parse(r'${list[i + 1]}');
        expect(expr, isA<IndexAccessExpr>());
        final idx = expr as IndexAccessExpr;
        expect(idx.index, isA<BinaryExpr>().having((e) => e.op, 'op', BinaryOp.plus));
      });

      test(r'${matrix[r][c]} — nested index', () {
        final expr = parse(r'${matrix[r][c]}');
        expect(expr, isA<IndexAccessExpr>());
        final outer = expr as IndexAccessExpr;
        expect(outer.index, isA<VariableExpr>().having((e) => e.name, 'name', 'c'));
        expect(outer.object, isA<IndexAccessExpr>());
      });
    });

    group('selection expressions', () {
      test('*{name} — simple selection', () {
        final expr = parse('*{name}');
        expect(expr, isA<SelectionExpr>());
        final sel = expr as SelectionExpr;
        expect(sel.inner, isA<VariableExpr>().having((e) => e.name, 'name', 'name'));
      });

      test('*{user.name} — member access in selection', () {
        final expr = parse('*{user.name}');
        expect(expr, isA<SelectionExpr>());
        final sel = expr as SelectionExpr;
        expect(sel.inner, isA<MemberAccessExpr>());
        final member = sel.inner as MemberAccessExpr;
        expect(member.object, isA<VariableExpr>().having((e) => e.name, 'name', 'user'));
        expect(member.member, 'name');
      });

      test('*{name | upper} — pipe inside selection', () {
        final expr = parse('*{name | upper}');
        expect(expr, isA<SelectionExpr>());
        final sel = expr as SelectionExpr;
        expect(sel.inner, isA<PipeExpr>().having((e) => e.filterName, 'filterName', 'upper'));
      });
    });

    group('dynamic index', () {
      test('rejects nested \${} inside bracket index', () {
        // F03: ${items[${i}]} is invalid; use ${items[i]} instead
        expect(() => parse(r'${items[${i}]}'), throwsA(isA<ExpressionException>()));
      });

      test('rejects nested \${} deeper in bracket expression', () {
        expect(() => parse(r'${a[b + ${c}]}'), throwsA(isA<ExpressionException>()));
      });

      test('bare identifier index is valid', () {
        expect(() => parse(r'${items[i]}'), returnsNormally);
      });

      test('arithmetic index is valid', () {
        expect(() => parse(r'${items[offset + 1]}'), returnsNormally);
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
