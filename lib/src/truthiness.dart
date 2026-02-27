/// Evaluate truthiness per Thymeleaf semantics (PRD F02).
///
/// Falsy: `null`, `false`, `0`, `0.0`, `"false"`, `"off"`, `"no"`.
/// Truthy: everything else (including `""`, `[]`, `{}`).
bool isTruthy(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    return value != 'false' && value != 'off' && value != 'no';
  }
  return true;
}
