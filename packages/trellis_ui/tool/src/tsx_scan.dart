// Minimal TSX scanner for shadcn base components: finds class-string literals that carry a `cn-*`
// hook, the structural utilities next to it, group/peer markers, data-slot values and data-* names.
// It is a tokenizer, not a TS parser: only "..." and `...` strings, comments, and parens/braces
// are understood. Single-quoted strings are ignored (shadcn formats with double quotes).

final _hookToken = RegExp(r'^cn-[\w-]+$');
final _marker = RegExp(r'^(group|peer)(/[\w-]+)?$');

class Hook {
  Hook(this.name);
  final String name;

  /// Structural utilities, in source order, unioned over every group whose first `cn-` token is [name].
  final Set<String> structural = {};
  final Set<String> markers = {};
  final Set<String> sources = {};
  int groups = 0;
}

class Orphan {
  Orphan(this.file, this.line, this.slot, this.preview);
  final String file;
  final int line;
  final String? slot;
  final String preview;
}

class ScanResult {
  final Map<String, Hook> hooks = {};
  final Set<String> secondaryHooks = {};
  final Set<String> slots = {};
  final Set<String> dataAttrs = {};
  final List<Orphan> orphans = [];

  Set<String> get allHooks => {...hooks.keys, ...secondaryHooks};
  Set<String> get markers => {for (final h in hooks.values) ...h.markers};
}

class _Lit {
  _Lit(this.value, this.line, this.srcOffset);
  final String value;
  final int line;
  final int srcOffset;
}

class _Frame {
  _Frame(this.ch, this.callee);
  final String ch;
  final String? callee;
  final List<_Lit> lits = [];
}

ScanResult scanTsx(String source, String file, [ScanResult? into]) {
  final result = into ?? ScanResult();
  final stack = <_Frame>[];
  final standalone = <_Lit>[];
  final groups = <List<_Lit>>[];
  var i = 0, line = 1;
  String? lastSlot;
  final n = source.length;
  final slotAt = <_Lit, String?>{};

  bool isIdent(int c) =>
      (c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95 || c == 36 || c == 46;

  while (i < n) {
    final c = source[i];
    if (c == '\n') {
      line++;
      i++;
    } else if (c == '/' && i + 1 < n && source[i + 1] == '/') {
      while (i < n && source[i] != '\n') {
        i++;
      }
    } else if (c == '/' && i + 1 < n && source[i + 1] == '*') {
      final end = source.indexOf('*/', i + 2);
      final stop = end < 0 ? n : end + 2;
      line += '\n'.allMatches(source.substring(i, stop)).length;
      i = stop;
    } else if (c == '"' || c == '`') {
      final start = i;
      i++;
      while (i < n && source[i] != c) {
        if (source[i] == '\\') i++;
        if (i < n && source[i] == '\n') line++;
        i++;
      }
      final value = source.substring(start + 1, i.clamp(0, n));
      i++;
      // data-xxx="value" attribute: record names and slot values; not a class string.
      final before = source.substring((start - 40).clamp(0, n), start);
      final attr = RegExp(r'(data-[a-z][a-z-]*)=$').firstMatch(before);
      if (attr != null) {
        result.dataAttrs.add(attr.group(1)!);
        if (attr.group(1) == 'data-slot') {
          result.slots.add(value);
          lastSlot = value;
        }
        continue;
      }
      var viaBraces = false;
      _Frame? target;
      for (var k = stack.length - 1; k >= 0; k--) {
        final f = stack[k];
        if (f.ch == '(') {
          if (f.callee == 'cn' || f.callee == 'cva') target = f;
          break;
        }
        viaBraces = true;
      }
      final lit = _Lit(value, line, start);
      if (target != null && !(target.callee == 'cva' && viaBraces)) {
        target.lits.add(lit);
      } else {
        standalone.add(lit);
      }
      slotAt[lit] = lastSlot;
    } else if (c == '(') {
      var j = i;
      while (j > 0 && isIdent(source.codeUnitAt(j - 1))) {
        j--;
      }
      stack.add(_Frame('(', source.substring(j, i)));
      i++;
    } else if (c == '{' || c == '[') {
      stack.add(_Frame(c, null));
      i++;
    } else if (c == ')' || c == '}' || c == ']') {
      if (stack.isNotEmpty) {
        final f = stack.removeLast();
        if (f.lits.isNotEmpty) groups.add(f.lits);
      }
      i++;
    } else {
      i++;
    }
  }

  for (final l in standalone) {
    final before = source.substring((l.srcOffset - 40).clamp(0, n), l.srcOffset);
    if (l.value.split(RegExp(r'\s+')).any(_hookToken.hasMatch) || RegExp(r'className\s*=\s*\{?\s*$').hasMatch(before)) {
      groups.add([l]);
    }
  }
  // data-* names written as data-x={...} (dynamic values)
  final stripped = source.replaceAll(RegExp(r'"(?:[^"\\]|\\.)*"'), '""');
  for (final m in RegExp(r'\b(data-[a-z][a-z-]*)=\{').allMatches(stripped)) {
    result.dataAttrs.add(m.group(1)!);
  }

  for (final g in groups) {
    final tokens = [for (final l in g) ...l.value.split(RegExp(r'\s+')).where((t) => t.isNotEmpty)];
    final hooks = tokens.where(_hookToken.hasMatch).toList();
    if (hooks.isEmpty) {
      final first = g.first;
      result.orphans.add(Orphan(file, first.line, slotAt[first], first.value));
      continue;
    }
    final hook = result.hooks.putIfAbsent(hooks.first, () => Hook(hooks.first));
    hook.groups++;
    hook.sources.add(file);
    for (final t in tokens) {
      if (_hookToken.hasMatch(t)) {
        if (t != hooks.first) result.secondaryHooks.add(t);
      } else if (_marker.hasMatch(t)) {
        hook.markers.add(t);
      } else {
        hook.structural.add(t);
      }
    }
  }
  return result;
}
