/// Generates the analysis_options.yaml content.
String analysisOptionsTemplate() => '''
include: package:lints/recommended.yaml

formatter:
  page_width: 120

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true

linter:
  rules:
    - prefer_single_quotes
    - require_trailing_commas
    - unawaited_futures
    - always_declare_return_types
''';
