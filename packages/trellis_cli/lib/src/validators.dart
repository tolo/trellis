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
