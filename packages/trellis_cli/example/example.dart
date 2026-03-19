import 'package:trellis_cli/trellis_cli.dart';

Future<void> main() async {
  final writer = InMemoryFileWriter();
  final generator = ProjectGenerator(projectName: 'demo_app', writer: writer);

  await generator.generate();

  print(writer.files.keys.take(4).join(', '));
}
