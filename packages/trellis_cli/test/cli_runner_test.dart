import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:trellis_cli/trellis_cli.dart';

void main() {
  group('TrellisCli', () {
    late TrellisCli cli;

    setUp(() {
      cli = TrellisCli();
    });

    test('--version prints version and returns 0', () async {
      final result = await cli.run(['--version']);
      expect(result, 0);
    });

    test('--help does not throw', () async {
      // CommandRunner prints help and returns null (mapped to 0).
      final result = await cli.run(['--help']);
      expect(result, 0);
    });

    test('no args prints usage', () async {
      // With no args, CommandRunner prints usage and returns null.
      final result = await cli.run([]);
      expect(result, 0);
    });

    test('unknown command throws UsageException', () {
      expect(() => cli.run(['unknown']), throwsA(isA<UsageException>()));
    });

    // T16: trellis build --help via runner
    test('T16: build --help exits 0', () async {
      final result = await cli.run(['build', '--help']);
      expect(result, 0);
    });

    // T17: trellis serve --help via runner
    test('T17: serve --help exits 0', () async {
      final result = await cli.run(['serve', '--help']);
      expect(result, 0);
    });

    // T18: TrellisCli has build and serve in its command list
    test('T18: has build and serve commands registered', () {
      expect(cli.commands.containsKey('build'), isTrue);
      expect(cli.commands.containsKey('serve'), isTrue);
    });
  });
}
