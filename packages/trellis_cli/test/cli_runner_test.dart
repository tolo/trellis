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
  });
}
