/// Generates the trellis_site.yaml content for a new blog project.
String blogSiteConfigTemplate(String projectName) {
  // Convert underscores to spaces for a readable title
  final title = projectName.replaceAll('_', ' ');
  return '''
title: $title
description: A blog built with Trellis.
baseUrl: https://example.com
taxonomies:
  - tags
paginate: 5

params:
  author: Blog Author
''';
}
