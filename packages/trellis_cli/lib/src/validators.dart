/// Extracts a theme name from a git URL.
///
/// Strips the `.git` suffix and trailing path segments, then removes the
/// `trellis-theme-` prefix if present.
///
/// Examples:
/// - `https://github.com/user/trellis-theme-verdant.git` -> `verdant`
/// - `https://github.com/user/verdant.git` -> `verdant`
/// - `git@github.com:user/verdant.git` -> `verdant`
String themeNameFromUrl(String url) {
  // Handle SSH URLs (git@github.com:user/repo.git)
  var name = url.contains(':') && !url.startsWith('http') ? url.split(':').last : url;
  name = name.split('/').last;
  if (name.endsWith('.git')) name = name.substring(0, name.length - 4);
  // Strip common trellis-theme- prefix
  if (name.startsWith('trellis-theme-')) name = name.substring('trellis-theme-'.length);
  return name;
}

/// Validates a Dart project name.
///
/// Returns `null` if [name] is valid, or a human-readable error message
/// describing why it is invalid.
///
/// Valid names match Dart package naming rules: lowercase letters, digits,
/// and underscores, starting with a letter.
String? validateProjectName(String name) {
  if (name.isEmpty) {
    return 'Project name cannot be empty.';
  }
  if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
    return 'Project name "$name" is not valid. '
        'Use only lowercase letters, digits, and underscores, '
        'starting with a letter.';
  }
  if (_reservedWords.contains(name)) {
    return '"$name" is a Dart reserved word and cannot be used as a '
        'project name.';
  }
  return null;
}

/// Dart reserved words that cannot be used as package names.
const _reservedWords = <String>{
  'abstract',
  'as',
  'assert',
  'async',
  'await',
  'base',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'covariant',
  'default',
  'deferred',
  'do',
  'dynamic',
  'else',
  'enum',
  'export',
  'extends',
  'extension',
  'external',
  'factory',
  'false',
  'final',
  'finally',
  'for',
  'function',
  'get',
  'hide',
  'if',
  'implements',
  'import',
  'in',
  'interface',
  'is',
  'late',
  'library',
  'mixin',
  'new',
  'null',
  'on',
  'operator',
  'part',
  'required',
  'rethrow',
  'return',
  'sealed',
  'set',
  'show',
  'static',
  'super',
  'switch',
  'sync',
  'this',
  'throw',
  'true',
  'try',
  'typedef',
  'var',
  'void',
  'when',
  'while',
  'with',
  'yield',
};

/// The charset a theme name must match to be usable as a directory segment.
///
/// Mirrors the rule the theme-gallery generator enforces on `theme.yaml`'s
/// `name`, so a name that installs is a name that can be published.
final _themeNamePattern = RegExp(r'^[a-z0-9][a-z0-9_-]*$');

/// Validates a theme name supplied as `--theme <name>`.
///
/// Returns `null` if [name] is valid, or a human-readable error message.
/// Rejecting anything outside the charset is also what keeps a `--theme`
/// value from being a path traversal (`../..`) or an absolute path.
String? validateThemeName(String name) {
  if (name.isEmpty) {
    return 'Theme name cannot be empty.';
  }
  if (!_themeNamePattern.hasMatch(name)) {
    return 'Theme name "$name" is not valid. Use lowercase letters, digits, '
        'hyphens, and underscores, starting with a letter or digit.';
  }
  return null;
}
