import '../exceptions.dart';

/// Split [input] on top-level commas, respecting nested `'...'`, `${...}`,
/// `@{...}`, and `(...)` delimiters.
List<String> splitTopLevel(String input) {
  final segments = <String>[];
  final buffer = StringBuffer();
  var inSingleQuote = false;
  var braceDepth = 0;
  var parenDepth = 0;

  for (var i = 0; i < input.length; i++) {
    final char = input[i];

    if (inSingleQuote) {
      buffer.write(char);
      if (char == r'\' && i + 1 < input.length && input[i + 1] == "'") {
        buffer.write(input[++i]); // consume escaped quote
      } else if (char == "'") {
        inSingleQuote = false;
      }
      continue;
    }

    if (char == "'") {
      inSingleQuote = true;
      buffer.write(char);
    } else if (char == '{') {
      braceDepth++;
      buffer.write(char);
    } else if (char == '}') {
      braceDepth--;
      buffer.write(char);
    } else if (char == '(') {
      parenDepth++;
      buffer.write(char);
    } else if (char == ')') {
      parenDepth--;
      buffer.write(char);
    } else if (char == ',' && braceDepth == 0 && parenDepth == 0) {
      segments.add(buffer.toString().trim());
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }

  segments.add(buffer.toString().trim());
  return segments;
}

/// Parse `tl:with` binding string into name-expression pairs.
///
/// Format: `"varName=${expr}, varName2=${expr2}"`
/// Splits on first `=` per binding.
List<(String name, String expression)> parseBindings(String input) {
  final segments = splitTopLevel(input);
  final bindings = <(String, String)>[];

  for (final segment in segments) {
    final eqIndex = segment.indexOf('=');
    if (eqIndex < 0) {
      throw TemplateException('Malformed binding: missing "=" in "$segment"');
    }
    final name = segment.substring(0, eqIndex).trim();
    final expression = segment.substring(eqIndex + 1).trim();
    if (name.isEmpty) {
      throw TemplateException('Malformed binding: empty variable name in "$segment"');
    }
    bindings.add((name, expression));
  }

  return bindings;
}
