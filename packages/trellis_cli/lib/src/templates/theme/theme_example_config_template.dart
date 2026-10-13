/// Generates example/trellis_site.yaml for theme preview.
String themeExampleConfigTemplate(String themeName) {
  final displayName = themeName.replaceAll('_', ' ').replaceAll('-', ' ');
  return '''
title: $displayName Example
description: Preview site for the $displayName theme.
baseUrl: http://localhost:8080

# The theme under development is the parent directory. `trellis create` links it
# in as themes/$themeName (`../..` from the link), and the build resolves `theme:`
# as themes/<name>.
theme: $themeName
''';
}
