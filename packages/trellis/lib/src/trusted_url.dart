/// A URL the application vouches for, written as-is to a URL attribute (ADR-015).
///
/// The engine replaces a dynamic `javascript:`, `vbscript:` or non-image `data:` value in `href`, `src`, `action`,
/// `formaction`, `data` and `xlink:href` with `about:invalid#trellis-unsafe-url`. Wrap a value in `TrustedUrl` in the
/// render context to write it unchanged. Only Dart code can create one, so template text cannot opt out.
///
/// It renders as its URL ([toString]) in text and in any attribute. Operations that build a new value from it
/// (concatenation, `|...|` literals, filters that return a `String`) drop the trust, so their result is checked.
/// Templates see it as a value, not a string: `${url} == '/a'` is false and `${url.value}` is not a member.
final class TrustedUrl {
  /// Wraps [value], which is written verbatim (still HTML-escaped on output, like every attribute value).
  const TrustedUrl(this.value);

  /// The URL as given.
  final String value;

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) => other is TrustedUrl && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
