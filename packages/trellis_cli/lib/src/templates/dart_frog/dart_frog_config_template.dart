/// Generates the dart_frog.yaml config file content.
String dartFrogConfigTemplate(String projectName) => 'name: $projectName\n';

/// Generates the .gitignore content for a Dart Frog project.
///
/// Includes Dart, Dart Frog, and IDE entries.
String dartFrogGitignoreTemplate() => '''
# Dart
.dart_tool/
.packages
pubspec.lock
build/

# Dart Frog
.dart_frog/

# IDE
.idea/
*.iml
.vscode/
''';
