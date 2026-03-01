import '../exceptions.dart';

/// Find the index of the first top-level occurrence of [delimiter] in [input],
/// respecting nested `'...'`, `${...}`, `@{...}`, and `(...)` delimiters.
/// Returns -1 if not found.
int findTopLevelDelimiter(String input, String delimiter) {
  assert(delimiter.length == 1, 'delimiter must be a single character');
  var inSingleQuote = false;
  var braceDepth = 0;
  var parenDepth = 0;

  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    if (inSingleQuote) {
      if (char == r'\' && i + 1 < input.length && input[i + 1] == "'") {
        i++;
      } else if (char == "'") {
        inSingleQuote = false;
      }
      continue;
    }

    if (char == "'") {
      inSingleQuote = true;
    } else if (char == '{') {
      braceDepth++;
    } else if (char == '}') {
      braceDepth--;
    } else if (char == '(') {
      parenDepth++;
    } else if (char == ')') {
      parenDepth--;
    } else if (char == delimiter && braceDepth == 0 && parenDepth == 0) {
      return i;
    }
  }

  return -1;
}

/// Split [input] on top-level commas, respecting nested `'...'`, `${...}`,
/// `@{...}`, and `(...)` delimiters.
List<String> splitTopLevel(String input) {
  final segments = <String>[];
  var remaining = input;
  while (true) {
    final idx = findTopLevelDelimiter(remaining, ',');
    if (idx == -1) {
      segments.add(remaining.trim());
      break;
    }
    segments.add(remaining.substring(0, idx).trim());
    remaining = remaining.substring(idx + 1);
  }
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
