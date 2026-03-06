import 'package:html/dom.dart';

import '../evaluator.dart';
import '../exceptions.dart';
import '../processor_api.dart';

void _processInlineImpl(Element element, String modeAttr, ExpressionEvaluator evaluator, Map<String, dynamic> context) {
  final mode = modeAttr.trim().toLowerCase();
  if (mode == 'none') return;
  if (mode != 'text' && mode != 'javascript' && mode != 'css') {
    throw TemplateException('Invalid tl:inline mode: "$mode"');
  }

  for (final node in List<Node>.from(element.nodes)) {
    if (node is! Text) continue;
    final text = node.data;
    if (!text.contains('[[') && !text.contains('[(')) continue;
    node.data = _processInlineText(text, mode, evaluator, context);
  }
}

String _processInlineText(String text, String mode, ExpressionEvaluator evaluator, Map<String, dynamic> context) {
  final output = StringBuffer();
  var i = 0;
  while (i < text.length) {
    if (i + 1 < text.length && text[i] == '[') {
      // Escaped inline: [[...]]
      if (text[i + 1] == '[') {
        final end = _findClosing(text, i + 2, ']]');
        if (end != -1) {
          final expr = text.substring(i + 2, end);
          final value = evaluator.evaluate(expr, context);
          final str = value?.toString() ?? '';
          output.write(_escape(str, mode));
          i = end + 2;
          continue;
        }
      }
      // Unescaped inline: [(...)]]
      if (text[i + 1] == '(') {
        final end = _findClosing(text, i + 2, ')]');
        if (end != -1) {
          final expr = text.substring(i + 2, end);
          final value = evaluator.evaluate(expr, context);
          output.write(value?.toString() ?? '');
          i = end + 2;
          continue;
        }
      }
    }
    output.write(text[i]);
    i++;
  }
  return output.toString();
}

/// Find position of [closing] in [text] from [start], respecting nested braces and strings.
int _findClosing(String text, int start, String closing) {
  var braceDepth = 0;
  String? inString; // tracks quote character: ' or "
  var i = start;
  while (i < text.length) {
    final char = text[i];
    if (inString != null) {
      if (char == r'\' && i + 1 < text.length) {
        i += 2;
        continue;
      }
      if (char == inString) inString = null;
      i++;
      continue;
    }
    if (char == "'" || char == '"') {
      inString = char;
      i++;
      continue;
    }
    if (char == '{') braceDepth++;
    if (char == '}') braceDepth--;
    if (braceDepth == 0 && i + closing.length <= text.length && text.substring(i, i + closing.length) == closing) {
      return i;
    }
    i++;
  }
  return -1;
}

String _escape(String input, String mode) => switch (mode) {
  'text' => input, // Text node serializer handles HTML escaping
  'javascript' => _escapeJs(input),
  'css' => _escapeCss(input),
  _ => throw StateError('unreachable: mode already validated'),
};

final _reCloseScript = RegExp(r'</script', caseSensitive: false);
final _reCloseStyle = RegExp(r'</style', caseSensitive: false);

String _escapeJs(String input) {
  return input
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r')
      .replaceAll('\t', r'\t')
      .replaceAll(_reCloseScript, r'<\/script');
}

String _escapeCss(String input) {
  return input
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll("'", r"\'")
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r')
      .replaceAll(_reCloseStyle, r'\3c /style');
}

/// Processor class for `tl:inline` — inline expression processing.
class InlineProcessor extends Processor {
  @override
  String get attribute => 'inline';

  @override
  ProcessorPriority get priority => ProcessorPriority.afterInclusion;

  @override
  bool process(Element element, String value, ProcessorContext context) {
    _processInlineImpl(element, value, context.evaluator, context.variables);
    return true;
  }
}
