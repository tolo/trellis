/// CLI tool for the Trellis template engine.
///
/// Provides project scaffolding and developer utilities for building
/// Trellis-powered web applications.
library;

export 'src/cli_runner.dart' show TrellisCli;
export 'src/generator/blog_project_generator.dart' show BlogProjectGenerator;
export 'src/generator/dart_frog_project_generator.dart' show DartFrogProjectGenerator;
export 'src/generator/file_writer.dart' show FileWriter, DiskFileWriter, InMemoryFileWriter;
export 'src/generator/project_generator.dart' show ProjectGenerator;
export 'src/generator/relic_project_generator.dart' show RelicProjectGenerator;
export 'src/validators.dart' show validateProjectName;
export 'src/version.dart' show cliVersion;
