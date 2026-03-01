import 'package:test/test.dart';
import 'package:trellis/trellis.dart';

void main() {
  group('Switch/Case processor', () {
    late Trellis engine;

    setUp(() {
      engine = Trellis(loader: MapLoader({}), cache: false);
    });

    String render(String template, Map<String, dynamic> context) => engine.render(template, context);

    group('basic matching', () {
      test('first matching case renders, others removed', () {
        final result = render(
          '<div tl:switch="\${role}">'
          '<p tl:case="admin">Admin</p>'
          '<p tl:case="user">User</p>'
          '<p tl:case="guest">Guest</p>'
          '</div>',
          {'role': 'user'},
        );
        expect(result, contains('User'));
        expect(result, isNot(contains('Admin')));
        expect(result, isNot(contains('Guest')));
      });

      test('first match wins with duplicates', () {
        final result = render(
          '<div tl:switch="\${role}">'
          '<p tl:case="admin">First</p>'
          '<p tl:case="admin">Second</p>'
          '</div>',
          {'role': 'admin'},
        );
        expect(result, contains('First'));
        expect(result, isNot(contains('Second')));
      });
    });

    group('default/wildcard', () {
      test('tl:case="*" renders when no match', () {
        final result = render(
          '<div tl:switch="\${role}">'
          '<p tl:case="admin">Admin</p>'
          '<p tl:case="*">Default</p>'
          '</div>',
          {'role': 'unknown'},
        );
        expect(result, contains('Default'));
        expect(result, isNot(contains('Admin')));
      });

      test('default removed when explicit match exists', () {
        final result = render(
          '<div tl:switch="\${role}">'
          '<p tl:case="admin">Admin</p>'
          '<p tl:case="*">Default</p>'
          '</div>',
          {'role': 'admin'},
        );
        expect(result, contains('Admin'));
        expect(result, isNot(contains('Default')));
      });

      test('no match and no default — all case children removed, parent preserved', () {
        final result = render(
          '<div tl:switch="\${role}">'
          '<p tl:case="admin">Admin</p>'
          '<p tl:case="user">User</p>'
          '</div>',
          {'role': 'unknown'},
        );
        expect(result, contains('<div>'));
        expect(result, isNot(contains('Admin')));
        expect(result, isNot(contains('User')));
      });
    });

    group('non-case children', () {
      test('non-case children preserved', () {
        final result = render(
          '<div tl:switch="\${role}">'
          '<h1>Header</h1>'
          '<p tl:case="admin">Admin</p>'
          '<p tl:case="user">User</p>'
          '</div>',
          {'role': 'admin'},
        );
        expect(result, contains('Header'));
        expect(result, contains('Admin'));
        expect(result, isNot(contains('User')));
      });
    });

    group('type coercion', () {
      test('numeric switch value matches string case', () {
        final result = render(
          '<div tl:switch="\${status}">'
          '<p tl:case="200">OK</p>'
          '<p tl:case="404">Not Found</p>'
          '</div>',
          {'status': 200},
        );
        expect(result, contains('OK'));
        expect(result, isNot(contains('Not Found')));
      });

      test('null switch value matches "null" case', () {
        final result = render(
          '<div tl:switch="\${val}">'
          '<p tl:case="null">Null</p>'
          '<p tl:case="*">Other</p>'
          '</div>',
          {'val': null},
        );
        expect(result, contains('Null'));
        expect(result, isNot(contains('Other')));
      });

      test('boolean switch value matches string case', () {
        final result = render(
          '<div tl:switch="\${flag}">'
          '<p tl:case="true">Yes</p>'
          '<p tl:case="false">No</p>'
          '</div>',
          {'flag': true},
        );
        expect(result, contains('Yes'));
        expect(result, isNot(contains('No')));
      });
    });

    group('orphan detection', () {
      test('tl:case outside tl:switch throws TemplateException', () {
        expect(
          () => render('<p tl:case="admin">Admin</p>', {}),
          throwsA(isA<TemplateException>().having((e) => e.message, 'message', contains('outside tl:switch'))),
        );
      });
    });

    group('attribute cleanup', () {
      test('tl:switch removed from output', () {
        final result = render('<div tl:switch="\${role}"><p tl:case="admin">Admin</p></div>', {'role': 'admin'});
        expect(result, isNot(contains('tl:switch')));
      });

      test('tl:case removed from matched child', () {
        final result = render('<div tl:switch="\${role}"><p tl:case="admin">Admin</p></div>', {'role': 'admin'});
        expect(result, isNot(contains('tl:case')));
      });

      test('tl:case removed from default child', () {
        final result = render('<div tl:switch="\${role}"><p tl:case="*">Default</p></div>', {'role': 'unknown'});
        expect(result, isNot(contains('tl:case')));
      });
    });

    group('integration with other directives', () {
      test('tl:if=false on switch parent removes everything', () {
        final result = render('<div tl:if="false" tl:switch="\${role}"><p tl:case="admin">Admin</p></div>', {
          'role': 'admin',
        });
        expect(result, isNot(contains('Admin')));
        expect(result, isNot(contains('div')));
      });

      test('switch inside tl:each evaluates per iteration', () {
        final result = render(
          r'<div tl:each="item : ${items}">'
          r'<span tl:switch="${item}">'
          '<p tl:case="a">A</p>'
          '<p tl:case="b">B</p>'
          '</span>'
          '</div>',
          {
            'items': ['a', 'b'],
          },
        );
        expect(result, contains('A'));
        expect(result, contains('B'));
      });
    });
  });
}
