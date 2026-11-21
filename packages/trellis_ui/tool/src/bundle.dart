import 'dart:convert';
import 'dart:io';

import 'package:sass/sass.dart' as sass;

List<File> sourceFiles(Directory directory, String extension) {
  if (!directory.existsSync()) return [];
  return directory.listSync(followLinks: false).whereType<File>().where((f) => f.path.endsWith(extension)).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

String bundleCss(Directory root) {
  final css = File('${root.path}/generated/trellis.min.css').readAsStringSync();
  final layers = <String, List<String>>{};
  for (final file in sourceFiles(Directory('${root.path}/assets/css/hand'), '.css')) {
    final layer = file.uri.pathSegments.last == '00-base.css' ? 'base' : 'trellis-hand';
    (layers[layer] ??= []).add(file.readAsStringSync());
  }
  final hand = layers.entries.map((layer) => '@layer ${layer.key} {\n${layer.value.join('\n')}\n}').join('\n');
  return '$css\n${_compressCss(hand)}\n';
}

// Hand layers follow a UTF-8 sheet, so a second encoding marker would land in the middle of the response.
String _compressCss(String css) =>
    sass.compileStringToResult(css, syntax: sass.Syntax.css, style: sass.OutputStyle.compressed, charset: false).css;

Map<String, List<int>> bundleAssets(Directory root) => {
  'trellis-ui.css': utf8.encode(bundleCss(root)),
  'trellis-ui.js': utf8.encode(bundleScript(root)),
  'htmx-indicator.css': utf8.encode(
    _compressCss(File('${root.path}/assets/css/htmx-indicator.css').readAsStringSync()),
  ),
};

String bundleScript(Directory root) {
  final scripts = sourceFiles(Directory('${root.path}/assets/js'), '.js');
  final out = StringBuffer('(function () {\n"use strict";\n');
  for (final f in scripts) {
    final source = f.readAsStringSync();
    if (_ScriptScan(source).containsModuleSyntax()) {
      throw FormatException('Classic script contains module syntax: ${f.path}');
    }
    // A leading expression in the next file must not continue this file's last
    // statement when an author relies on JavaScript's automatic semicolon insertion.
    out.writeln(';');
    out.writeln(source);
  }
  out.writeln('})();');
  return out.toString();
}

// Template text is inert, but ${...} is executable code and must be inspected.
// The scan only decides whether module keywords survive outside comments/strings;
// the browser remains the syntax checker for the resulting classic script.
final class _ScriptScan {
  _ScriptScan(this.source);
  final String source;
  var index = 0;

  bool containsModuleSyntax({bool interpolation = false}) {
    var braces = 0;
    while (index < source.length) {
      final c = source[index];
      if (source.startsWith('//', index)) {
        final end = source.indexOf('\n', index + 2);
        index = end < 0 ? source.length : end + 1;
      } else if (source.startsWith('/*', index)) {
        final end = source.indexOf('*/', index + 2);
        index = end < 0 ? source.length : end + 2;
      } else if (c == '"' || c == "'") {
        _skipQuoted(c);
      } else if (c == '`') {
        if (_template()) return true;
      } else if (RegExp(r'[\w$]').hasMatch(c)) {
        final start = index++;
        while (index < source.length && RegExp(r'[\w$]').hasMatch(source[index])) {
          index++;
        }
        final token = source.substring(start, index);
        if (token == 'import' || token == 'export') return true;
      } else {
        index++;
        if (c == '{') braces++;
        if (c == '}') {
          if (interpolation && braces == 0) return false;
          braces--;
        }
      }
    }
    return false;
  }

  void _skipQuoted(String quote) {
    index++;
    while (index < source.length) {
      final c = source[index++];
      if (c == r'\') {
        if (index < source.length) index++;
      } else if (c == quote) {
        break;
      }
    }
  }

  bool _template() {
    index++;
    while (index < source.length) {
      final c = source[index++];
      if (c == r'\') {
        if (index < source.length) index++;
      } else if (c == '`') {
        return false;
      } else if (c == r'$' && index < source.length && source[index] == '{') {
        index++;
        if (containsModuleSyntax(interpolation: true)) return true;
      }
    }
    return false;
  }
}
