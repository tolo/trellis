/// Rewrite self-closing `<prefix:block .../>` tags to explicit open/close pairs.
///
/// HTML5 treats unknown elements as non-void, so `/>` is ignored by the parser.
/// This normalization keeps block semantics stable for both rendering and validation.
String fixSelfClosingBlocks(String source, {required String prefix, required String separator}) {
  final tag = '$prefix${separator}block';
  final tagLower = tag.toLowerCase();
  final tagLen = tag.length;
  final buf = StringBuffer();
  var i = 0;
  while (i < source.length) {
    if (source.codeUnitAt(i) != 0x3C) {
      buf.writeCharCode(source.codeUnitAt(i));
      i++;
      continue;
    }

    final remaining = source.length - i;
    if (remaining < tagLen + 2 || source.substring(i + 1, i + 1 + tagLen).toLowerCase() != tagLower) {
      buf.writeCharCode(source.codeUnitAt(i));
      i++;
      continue;
    }

    final afterTag = source.codeUnitAt(i + 1 + tagLen);
    if (afterTag != 0x20 &&
        afterTag != 0x09 &&
        afterTag != 0x0A &&
        afterTag != 0x0D &&
        afterTag != 0x2F &&
        afterTag != 0x3E) {
      buf.writeCharCode(source.codeUnitAt(i));
      i++;
      continue;
    }

    final tagStart = i;
    i += 1 + tagLen;
    int? quoteChar;
    while (i < source.length) {
      final c = source.codeUnitAt(i);
      if (quoteChar != null) {
        if (c == quoteChar) {
          quoteChar = null;
        }
        i++;
      } else if (c == 0x22 || c == 0x27) {
        quoteChar = c;
        i++;
      } else if (c == 0x2F && i + 1 < source.length && source.codeUnitAt(i + 1) == 0x3E) {
        final attrs = source.substring(tagStart + 1 + tagLen, i);
        final tagName = source.substring(tagStart + 1, tagStart + 1 + tagLen);
        buf.write('<$tagName$attrs></$tagName>');
        i += 2;
        break;
      } else if (c == 0x3E) {
        buf.write(source.substring(tagStart, i + 1));
        i++;
        break;
      } else {
        i++;
      }
    }

    if (i >= source.length && (quoteChar != null || tagStart + 1 + tagLen >= source.length)) {
      buf.write(source.substring(tagStart));
    }
  }
  return buf.toString();
}
