/// AST node hierarchy for trellis expressions.
sealed class Expr {}

/// A literal value: string, int, double, bool, or null.
final class LiteralExpr extends Expr {
  final dynamic value;
  LiteralExpr(this.value);
}

/// A variable reference: `name` resolved from context.
final class VariableExpr extends Expr {
  final String name;
  VariableExpr(this.name);
}

/// Dot member access: `object.member`.
final class MemberAccessExpr extends Expr {
  final Expr object;
  final String member;
  MemberAccessExpr(this.object, this.member);
}

/// Bracket index access: `object[index]` where index is a sub-expression.
final class IndexAccessExpr extends Expr {
  final Expr object;
  final Expr index;
  IndexAccessExpr(this.object, this.index);
}

/// Pipe-delimited literal substitution: `|text ${expr} more|`.
final class LiteralSubstitutionExpr extends Expr {
  final List<Expr> parts;
  LiteralSubstitutionExpr(this.parts);
}

/// Unary operator applied to an operand.
final class UnaryExpr extends Expr {
  final UnaryOp op;
  final Expr operand;
  UnaryExpr(this.op, this.operand);
}

/// Binary operator applied to two operands.
final class BinaryExpr extends Expr {
  final Expr left;
  final BinaryOp op;
  final Expr right;
  BinaryExpr(this.left, this.op, this.right);
}

/// Ternary conditional: `condition ? ifTrue : ifFalse`.
final class TernaryExpr extends Expr {
  final Expr condition;
  final Expr ifTrue;
  final Expr ifFalse;
  TernaryExpr(this.condition, this.ifTrue, this.ifFalse);
}

/// Elvis null-coalescing: `left ?: right`. Triggers on null only.
final class ElvisExpr extends Expr {
  final Expr left;
  final Expr right;
  ElvisExpr(this.left, this.right);
}

/// Pipe filter: `target | filterName` or `target | filterName:arg1:arg2`.
/// Chains left-to-right. Args are empty when no arguments provided.
final class PipeExpr extends Expr {
  final Expr target;
  final String filterName;
  final List<Expr> args;
  PipeExpr(this.target, this.filterName, [this.args = const []]);
}

/// URL expression: `@{/path(key=value, ...)}`.
final class UrlExpr extends Expr {
  final String path;
  final List<(String key, Expr value)> params;
  UrlExpr(this.path, this.params);
}

/// Binary operators.
enum BinaryOp { eq, notEq, lt, gt, lte, gte, and_, or_, plus, minus, star, slash, percent }

/// Selection expression: `*{field}` resolved against the tl:object scope.
final class SelectionExpr extends Expr {
  final Expr inner;
  SelectionExpr(this.inner);
}

/// Message expression: `#{key}` or `#{key(arg1, arg2)}`.
/// Resolves internationalized message from MessageSource [D08].
final class MessageExpr extends Expr {
  /// The message key (flat string, dots are part of the key name).
  final String key;

  /// Arguments for parameterized messages, evaluated before resolution.
  final List<Expr> args;
  MessageExpr(this.key, [this.args = const []]);
}

/// Unary operators.
enum UnaryOp { not_, minus }
