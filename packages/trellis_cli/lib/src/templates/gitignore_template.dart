/// Generates the .gitignore content.
String gitignoreTemplate() => '''
# Dart
.dart_tool/
.packages
pubspec.lock
build/

# IDE
.idea/
*.iml
.vscode/
''';
