/// Generates example/trellis_site.yaml for theme preview.
String themeExampleConfigTemplate(String themeName) {
  final displayName = themeName.replaceAll('_', ' ').replaceAll('-', ' ');
  return '''
title: $displayName Example
description: Preview site for the $displayName theme.
baseUrl: http://localhost:8080

# To preview: copy theme layouts+static into this site, or use
# trellis theme add ../  from this directory.
''';
}
